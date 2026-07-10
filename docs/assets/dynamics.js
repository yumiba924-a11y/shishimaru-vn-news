/* 動きの層（共有）― マークアップを書き換えず、JSで data-dyn を付与してスクロール表示＋パララックス */
(function(){
  var d=document, w=window;
  if(!('IntersectionObserver' in w)) return;                 // 非対応＝完全静的
  if(w.matchMedia && w.matchMedia('(prefers-reduced-motion: reduce)').matches) return;

  /* 1) スクロール表示（reveal）: 主要ブロックにフェードアップ */
  var SEL = '.eyebrow,.s-title,.lead,.body,.src,.note,.hc-note,.bcard,.mtable,.crow,'
          + '.bigstat,figure,.compic,.wk-kpi,.ddiv,.cat-list,.disc,.warn,'
          + '.dcard,.week-hero,.issue,.acc,.cornernav,.sec-head,.formula,.stats .n,'
          + '.hero-body,.hero-lead,.hero-kpis,.btile,img';
  var els = [].slice.call(d.querySelectorAll(SEL)).filter(function(el){
    if(el.closest('[data-dyn]')) return false;               // 二重付与を避ける
    var cs=getComputedStyle(el);
    if(cs.position==='fixed') return false;
    return true;
  });
  els.forEach(function(el){
    el.setAttribute('data-dyn','');
    // 同じ親のきょうだいで時差（スタッガー）を付ける
    var sibs=[].slice.call(el.parentElement.children).filter(function(c){return c.hasAttribute('data-dyn');});
    var idx=sibs.indexOf(el);
    if(idx>0) el.style.transitionDelay=Math.min(idx*70,350)+'ms';
  });
  var io=new IntersectionObserver(function(es){
    es.forEach(function(e){ if(e.isIntersecting){ e.target.classList.add('dyn-in'); io.unobserve(e.target); } });
  },{threshold:0.05, rootMargin:'0px 0px -14% 0px'});
  els.forEach(function(el){ io.observe(el); });
  // 初期表示は"画面の上半分"だけ即出す→下半分はスクロールで明確に立ち上がる
  requestAnimationFrame(function(){
    var vh=w.innerHeight;
    els.forEach(function(el){ var r=el.getBoundingClientRect(); if(r.top<vh*0.55) el.classList.add('dyn-in'); });
  });

  /* 2) パララックス（ヒーロー全面画像・分解チャート帯など） */
  var pxs=[].slice.call(d.querySelectorAll('.hero-img,.px-bg,[data-px]'));
  function px(){
    var vh=w.innerHeight;
    for(var i=0;i<pxs.length;i++){
      var bg=pxs[i], sec=bg.parentElement, r=sec.getBoundingClientRect();
      if(r.bottom<-120||r.top>vh+120) continue;
      var speed=parseFloat(bg.getAttribute('data-speed')|| (bg.classList.contains('hero-img')?'0.14':'0.22'));
      var off=(r.top+r.height/2)-(vh/2);
      bg.style.transform='translate3d(0,'+(-off*speed).toFixed(1)+'px,0)';
    }
  }
  var ticking=false;
  w.addEventListener('scroll',function(){ if(!ticking){ requestAnimationFrame(function(){ px(); ticking=false; }); ticking=true; } },{passive:true});
  w.addEventListener('resize',px); px();
})();
