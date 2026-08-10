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
      vol: 6,
      week: "2026.8.3–8.7週",
      published: "2026年8月10日（月）発行",
      title: "鉄は、国家をつくる ― ホアファット（HPG）",
      hero: "weekly_assets/hpg_hero.png",
      url: "weekly06.html",
      summary: "中古機械の商人が興した貿易会社が、粗鋼で東南アジア最大の製鉄所を築いた。鉄が9割、そして卵。次の一手は南北高速鉄道レールの国産化——市況株の枠を、超えられるか。相場面は先週の入替発効・外国人の買い越し転換を分解。"
    },
    {
      vol: 5,
      week: "2026.7.27–7.31週",
      published: "2026年8月3日（月）発行",
      title: "NVIDIAと組む、ベトナム最大のIT ― FPT",
      hero: "weekly_assets/FPT-tower-3.webp",
      url: "weekly05.html",
      summary: "食品会社として登記された会社が、いま世界のAIインフラを回す。日本を最大市場に育てたFPT——業績は堅調なのに株価は半減、外国人保有49%→27.6%。「優等生は、なぜ売られるのか」。"
    },
    {
      vol: 4,
      week: "2026.7.20–7.24週",
      published: "2026年7月27日（月）発行",
      title: "食卓の帝国 ― マサン（MSN）",
      hero: "weekly_assets/vol04_hero_v2.png",
      url: "weekly04.html",
      summary: "マサンは食品会社ではない。調味料から小売、カフェ、銀行までを一本の生活動線に束ねた消費インフラ——最大の稼ぎ頭WinCommerceは非上場という「見えない帝国」を解剖する。"
    },
    {
      vol: 3,
      week: "2026.7.13–7.17週",
      published: "2026年7月21日（火）発行",
      title: "空飛ぶ財閥 ― ソビコ（VJC・HDB）",
      hero: "weekly_assets/vol03_iceberg.jpg",
      url: "weekly03.html",
      summary: "ベトジェットの背後にある非上場コングロマリット、ソビコ。航空が現金を生み、不動産に化け、銀行が回す——夫婦が築いた「回路」を氷山モデルで解剖する。"
    },
    {
      vol: 2,
      week: "2026.7.6–7.10週",
      published: "2026年7月13日（月）発行",
      title: "静かなる支配者 ― ベトナムを動かす14の銀行",
      hero: "weekly_assets/bank_treemap.png",
      url: "weekly02.html",
      summary: "銀行49行を27行、そして14行へ数えなおす。国有と民間の二面性、同じ銀行でも91pt開くリターン格差——市場の約3割を占める最大勢力の解剖。"
    },
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
    { id:"earnings", icon:"📊", name:"決算ウォッチ", url:"earnings.html",
      desc:"VN主要企業の四半期決算を、出た順に整理。数字は自動集計・円換算つき、背景は会社開示から。", status:"live" },
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
    { t:"VCB", n:"ベトコムバンク",      s:"銀行",       st:"done",    vol:2 },
    { t:"BID", n:"ベトナム投資開発銀行", s:"銀行",      st:"done",    vol:2 },
    { t:"CTG", n:"ベトナム工商銀行",    s:"銀行",       st:"done",    vol:2 },
    { t:"TCB", n:"テクコムバンク",      s:"銀行",       st:"done",    vol:2 },
    { t:"VPB", n:"VPバンク",            s:"銀行",       st:"done",    vol:2 },
    { t:"MBB", n:"MBバンク",            s:"銀行",       st:"done",    vol:2 },
    { t:"ACB", n:"アジア商業銀行",      s:"銀行",       st:"done",    vol:2 },
    { t:"HDB", n:"HDバンク",            s:"銀行",       st:"done",    vol:2 },
    { t:"STB", n:"サコムバンク",        s:"銀行",       st:"done",    vol:2 },
    { t:"SHB", n:"サイゴンハノイ銀行",  s:"銀行",       st:"done",    vol:2 },
    { t:"LPB", n:"LPバンク",            s:"銀行",       st:"done",    vol:2 },
    { t:"VIB", n:"ベトナム国際銀行",    s:"銀行",       st:"done",    vol:2 },
    { t:"SSB", n:"SeAバンク",           s:"銀行",       st:"done",    vol:2 },
    { t:"VJC", n:"ベトジェット",        s:"運輸",       st:"done",    vol:3 },
    { t:"MSN", n:"マサングループ",      s:"消費財",     st:"done",    vol:4 },
    { t:"FPT", n:"FPT",                 s:"IT",         st:"done",    vol:5 },
    { t:"HPG", n:"ホアファット",        s:"素材",       st:"done",    vol:6 },
    { t:"MCH", n:"マサンコンシューマー", s:"消費財",     st:"done",    vol:4 },
    { t:"SSI", n:"SSI証券",             s:"証券",       st:"next",    vol:7 },
    { t:"GAS", n:"ペトロベトナムガス",  s:"エネルギー", st:"open" },
    { t:"BSR", n:"ビンソン石油精製",    s:"エネルギー", st:"open" },
    { t:"SAB", n:"サベコ",              s:"消費財",     st:"open" },
    { t:"VNM", n:"ビナミルク",          s:"消費財",     st:"open" },
    { t:"MWG", n:"モバイルワールド",    s:"小売",       st:"open" },
    { t:"GVR", n:"ベトナムゴム",        s:"素材",       st:"open" },
    { t:"TCX", n:"テクコム証券",        s:"証券",       st:"open" }
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
      name:"ソビコ", status:"done", vol:3, url:"weekly03.html",
      img:"weekly_assets/vol03_iceberg.jpg",
      tickers:["VJC","HDB","Phú Long","Furama","Galaxy"],
      founder:"グエン・タイン・フン ＆ グエン・ティ・フオン・タオ", east:"ハリコフ工科大 → モスクワ（旧ソ連で創業）",
      oneliner:"航空が運び、銀行が貸す。夫婦で築いたベトナム初の女性ビリオネアの帝国。上場2社は氷山の一角。"
    },
    {
      name:"マサン", status:"done", vol:4, url:"weekly04.html",
      img:"weekly_assets/vol04_hero_v2.png",
      tickers:["MSN","MCH","MML","MSR","WinCommerce","Techcombank"],
      founder:"グエン・ダン・クアン", east:"ロシア／ベラルーシ（即席麺）",
      oneliner:"食品会社ではなく、生活インフラ。最大の稼ぎ頭WinCommerce（約4,592店）は非上場という「見えない帝国」。"
    },
    {
      name:"ホアファット", status:"done", vol:6, url:"weekly06.html",
      img:"weekly_assets/hpg_hero.png",
      tickers:["HPG"],
      founder:"チャン・ディン・ロン", east:null,
      oneliner:"鉄が9割、そして卵。中古機械の商人が興した貿易会社が、粗鋼で東南アジア最大の製鉄所を築いた。次は高速鉄道レールの国産化。"
    },
    {
      name:"ビエットテル系", status:"planned", vol:null, date:"今後の号で予定",
      tickers:["MBB","VGI","VTP","CTR"],
      founder:"（軍隊系グループ）", east:null,
      oneliner:"軍が営む通信帝国。銀行・物流・建設まで広がる国防省の経済圏。"
    },
    {
      name:"FPT", status:"done", vol:5, url:"weekly05.html",
      img:"weekly_assets/FPT-tower-3.webp",
      tickers:["FPT","FRT","FTS"],
      founder:"チュオン・ザー・ビン", east:"モスクワ大学",
      oneliner:"食品会社として登記され、いまNVIDIAと組む。日本を最大市場に育てた優等生が、なぜ外国人に売られるのか。"
    }
  ],

  // ---- 決算通信簿（verdict: null=検証待ち / "◯"/"△"/"✕"） ----
  scorecard: [
    {
      vol:6, made:"2026/8/10",
      claim:"ホアファットは「シクリカル（市況株）」の枠を超えられるか——鍵は増産（Dung Quat 2フル稼働で粗鋼能力が東南アジア最大からさらに上へ）と高付加価値化（汎用鉄筋→HRC→高速鉄道レール）。国内シェアNo.1の安定と、南北高速鉄道という巨大需要が背中を押す。PER7.9倍・PBR1.30倍・ROE約16%（2026/8/3）は割安圏だが、鉄鋼市況・原材料・中国の過剰生産に業績は左右される",
      test:"粗鋼生産・HRC/レールの高付加価値比率とDung Quat 2の稼働、Q3以降の業績、鉄鋼市況（価格・鉄鉱石/原料炭コスト・中国輸出）とレール初出荷（2027目標）の進捗を確認", verdict:null
    },
    {
      vol:5, made:"2026/8/3",
      claim:"FPTの需給反転——外国人保有が49%（2023末）→約27.6%（2026/7）まで低下し、業績堅調(上期PBT+18.1%)でも株価は年初来ほぼ半減。9/21のFTSE発効と外国人アクティブ資金の回帰で、株価が業績に追いつくか。7/27–31週にFPTは+6.68%・外国人買い越し+308十億ドンと、最初のカウンターが出た",
      test:"FPTの外国人フロー（買い越しの持続）とFTSE組入れ後の株価、およびQ3業績を確認", verdict:null
    },
    {
      vol:4, made:"2026/7/27",
      claim:"マサンの「持株会社ディスカウント」——上場子会社MCH一社の時価総額（約1兆1,200億円）が親会社MSN（約5,900億円）を上回る逆転——は、MCHのHOSE移管や『見えない本体』（WinCommerce等）の再評価で解消に向かうか",
      test:"MSNの株価とNAVディスカウント、およびQ2以降のWinCommerce/MEATLifeの黒字持続を確認", verdict:null
    },
    {
      vol:3, made:"2026/7/21",
      claim:"ソビコの二面性——攻めのベトジェット（VJC・PER41倍＝期待先行）と守りのHDBank（ROE25%＝実績）——が、Q2決算で「期待と実績」の色分け通りに出るか",
      test:"VJC・HDBのQ2決算（増益率・ROE）とバリュエーションの推移を確認", verdict:null
    },
    {
      vol:2, made:"2026/7/13",
      claim:"預金金利の上昇（実質8.5〜9%・与信+6.38% vs 預金+4.3%）が銀行の利ざや（NIM）を圧迫する懸念——調達コスト上昇は決算に現れる",
      test:"Q2銀行決算（7月下旬〜8月）で預金コストとNIMの変化を確認", verdict:null
    },
    {
      vol:2, made:"2026/7/13",
      claim:"LPBの「特別扱い」（PBR3.94倍＝VN30銀行唯一の3倍台・銀行安の週も逆行高）は業績が正当化できるか",
      test:"LPBのQ2決算（ROE・増益率）とPBRの推移を確認", verdict:null
    },
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
