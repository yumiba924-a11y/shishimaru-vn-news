// ============================================================
// Vietnam Weekly ポータル ― サイト全体の唯一の真実 (single source of truth)
// 月曜の発刊時はこのファイルに追記するだけで、
// index / questmap / zaibatsu / scorecard が同時に更新される。
// 号(weekly<NN>.html)は凍結スナップショット＝発刊後は触らない。
// ============================================================
window.SITE = {

  site: {
    title: "Vietnam Weekly",
    org: "CAPITAL QUEST CORPORATION ｜ 投資調査部",
    tagline: "数字で構造を暴く ― ベトナム株の週次リサーチ"
  },

  // ---- 発刊済みの号（新しい順） ----
  issues: [
    {
      vol: 1,
      week: "2026.6.29–7.3週",
      published: "2026年7月6日（月）発行",
      title: "指数を動かす帝国 ― ビングループ（VIC）",
      hero: "weekly_assets/cover_vingroup.jpg",
      url: "weekly01.html",
      summary: "VN-Index上昇の約7割はビン系が作った。一社で指数の2割を占める帝国の、稼ぐ不動産と現金燃焼のEVという二面性を解く。"
    }
  ],

  // ---- コーナー（live=公開中 / soon=近日） ----
  corners: [
    { id:"questmap",  icon:"🗺", name:"クエスト攻略マップ", url:"questmap.html",
      desc:"VN30の30銘柄をどこまで探索したか。企業クエストの進捗を一望する。", status:"live" },
    { id:"zaibatsu",  icon:"📖", name:"財閥図鑑", url:"zaibatsu.html",
      desc:"ビン、ソビコ、マサン――ベトナム経済を動かす一族を、号を重ねて収集する。", status:"live" },
    { id:"scorecard", icon:"📝", name:"決算通信簿", url:"scorecard.html",
      desc:"本誌が張った主張を、決算で自己検証する。予実を公開する週次リサーチ。", status:"live" },
    { id:"wiring",    icon:"🕸", name:"経済の配線図", url:"wiring.html",
      desc:"財閥×銀行×創業者の資本・人脈ネットワーク。号を重ねるたびに育つ地図。", status:"soon" },
    { id:"room",      icon:"🚪", name:"Foreign Room モニター", url:"room.html",
      desc:"外国人はまだ買えるのか。保有上限までの残り枠を財閥・銘柄別に定点観測。", status:"soon" },
    { id:"exvin",     icon:"📊", name:"財閥指数 vs 非財閥指数", url:"exvin.html",
      desc:"ベトナム株を買うことは、財閥を買うことなのか。指数を二つに割って検証する。", status:"soon" }
  ],

  // ---- VN30 攻略マップ（status: done=クエスト済 / next=次号 / planned=予定 / open=未踏） ----
  // quest.vol は初出の号。日付は予定（変更あり）。
  vn30: [
    { t:"VIC", n:"ビングループ",        s:"不動産",     st:"done",    vol:1 },
    { t:"VHM", n:"ビンホームズ",        s:"不動産",     st:"done",    vol:1 },
    { t:"VRE", n:"ビンコムリテール",    s:"不動産",     st:"done",    vol:1 },
    { t:"VPL", n:"ビンパール",          s:"観光",       st:"done",    vol:1 },
    { t:"VCB", n:"ベトコムバンク",      s:"銀行",       st:"next",    vol:2 },
    { t:"BID", n:"ベトナム投資開発銀行", s:"銀行",      st:"next",    vol:2 },
    { t:"CTG", n:"ベトナム工商銀行",    s:"銀行",       st:"next",    vol:2 },
    { t:"TCB", n:"テクコムバンク",      s:"銀行",       st:"next",    vol:2 },
    { t:"VPB", n:"VPバンク",            s:"銀行",       st:"next",    vol:2 },
    { t:"MBB", n:"MBバンク",            s:"銀行",       st:"next",    vol:2 },
    { t:"ACB", n:"アジア商業銀行",      s:"銀行",       st:"next",    vol:2 },
    { t:"HDB", n:"HDバンク",            s:"銀行",       st:"next",    vol:2 },
    { t:"STB", n:"サコムバンク",        s:"銀行",       st:"next",    vol:2 },
    { t:"SHB", n:"サイゴンハノイ銀行",  s:"銀行",       st:"next",    vol:2 },
    { t:"LPB", n:"LPバンク",            s:"銀行",       st:"next",    vol:2 },
    { t:"VIB", n:"ベトナム国際銀行",    s:"銀行",       st:"next",    vol:2 },
    { t:"TPB", n:"TPバンク",            s:"銀行",       st:"next",    vol:2 },
    { t:"SSB", n:"SeAバンク",           s:"銀行",       st:"next",    vol:2 },
    { t:"VJC", n:"ベトジェット",        s:"運輸",       st:"planned", vol:3 },
    { t:"MSN", n:"マサングループ",      s:"消費財",     st:"planned", vol:4 },
    { t:"HPG", n:"ホアファット",        s:"素材",       st:"planned", vol:5 },
    { t:"SSI", n:"SSI証券",             s:"証券",       st:"planned", vol:6 },
    { t:"FPT", n:"FPT",                 s:"IT",         st:"planned", vol:7 },
    { t:"GAS", n:"ペトロベトナムガス",  s:"エネルギー", st:"open" },
    { t:"BSR", n:"ビンソン石油精製",    s:"エネルギー", st:"open" },
    { t:"PLX", n:"ペトロリメックス",    s:"エネルギー", st:"open" },
    { t:"SAB", n:"サベコ",              s:"消費財",     st:"open" },
    { t:"VNM", n:"ビナミルク",          s:"消費財",     st:"open" },
    { t:"MWG", n:"モバイルワールド",    s:"小売",       st:"open" },
    { t:"GVR", n:"ベトナムゴム",        s:"素材",       st:"open" }
  ],

  // ---- 財閥図鑑（status: done=収載済 / planned=探索予定） ----
  zaibatsu: [
    {
      name:"ビングループ", status:"done", vol:1, url:"weekly01.html",
      img:"weekly_assets/cover_vingroup.jpg",
      tickers:["VIC","VHM","VRE","VPL","VFS(米)","VEF(UPCoM)"],
      founder:"ファム・ニャット・ヴオン", east:"ウクライナ・ハリコフ（乾麺）",
      oneliner:"不動産が稼ぎ、EVが問う。VN-Indexの約28.7%（単純時価総額・2026/7/2概算）を占める最大の一族。"
    },
    {
      name:"ソビコ", status:"planned", vol:3, date:"7/20（月）予定",
      tickers:["VJC","HDB"],
      founder:"グエン・タイン・フン ＆ グエン・ティ・フオン・タオ", east:"ハリコフ大学 → ロシアで創業",
      oneliner:"航空が運び、銀行が貸す。夫婦で築いたベトナム初の女性ビリオネアの帝国。"
    },
    {
      name:"マサン", status:"planned", vol:4, date:"7/27（月）予定",
      tickers:["MSN","MCH","MML","MSR"],
      founder:"グエン・ダン・クアン", east:"ロシア（即席麺）",
      oneliner:"消費財が稼ぎ、小売が広げる。WinMart 5,000店を擁する生活圏の支配者。"
    },
    {
      name:"ホアファット", status:"planned", vol:5, date:"8/3（月）予定",
      tickers:["HPG"],
      founder:"チャン・ディン・ロン", east:null,
      oneliner:"鉄の王。ベトナムの建設ブームを素材で支える最大の民間製造業。"
    },
    {
      name:"ビエットテル系", status:"planned", vol:6, date:"8/10（月）予定",
      tickers:["MBB","VGI","VTP","CTR"],
      founder:"（軍隊系グループ）", east:null,
      oneliner:"軍が営む通信帝国。銀行・物流・建設まで広がる国防省の経済圏。"
    },
    {
      name:"FPT", status:"planned", vol:8, date:"8/24（月）予定",
      tickers:["FPT","FRT","FTS"],
      founder:"チュオン・ザー・ビン", east:"モスクワ大学",
      oneliner:"ベトナムのIT頭脳。外国人が売り続ける優等生の謎を解く。"
    }
  ],

  // ---- 決算通信簿（verdict: null=検証待ち / "◯"/"△"/"✕"） ----
  scorecard: [
    {
      vol:1, made:"2026/7/6",
      claim:"銀行株の上げ（HDB+6.1%等）は株価が業績に先行しており、7月中旬からのQ2決算で裏付けが試される",
      test:"Q2銀行決算（7月下旬〜8月）で純益の伸びを確認", verdict:null
    },
    {
      vol:1, made:"2026/7/6",
      claim:"証券株（SSI等）の先回り買いは、8/21のFTSE最終構成リストが試金石",
      test:"8/21のリスト公表と証券株の値動きを確認", verdict:null
    }
  ]
};
