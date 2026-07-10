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
  els.forEach(function(el){ el.setAttribute('data-dyn',''); });
  var io=new IntersectionObserver(function(es){
    es.forEach(function(e){ if(e.isIntersecting){ e.target.classList.add('dyn-in'); io.unobserve(e.target); } });
  },{threshold:0.06, rootMargin:'0px 0px -6% 0px'});
  els.forEach(function(el){ io.observe(el); });
  // 初期ビューポート内は即表示（読み込み直後の空白を防ぐ）
  requestAnimationFrame(function(){
    var vh=w.innerHeight;
    els.forEach(function(el){ var r=el.getBoundingClientRect(); if(r.top<vh*0.92) el.classList.add('dyn-in'); });
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
