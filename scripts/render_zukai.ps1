<#
  render_zukai.ps1  ―  VN30 図解新聞 / 出力層 [4]（v3: ぶたまる型・日次）
  --------------------------------------------------------------------
  日次の主役は「今日のひとこと＋ニュースカード」。寄与度・セクター分解は週次へ移管
  （interpreted.json には寄与度を保持＝週次素材として蓄積。ここでは描画しない）。

  v3レイアウト（上から）:
    ①マストヘッド（CQC深緑＋金）DAILY QUEST / デイリークエスト｜VN30分解新聞
    ②指数バー（VN-Index/VN30 終値・騰落率＋騰落数）
    ③ステージ：VN30ヒートマップ（時価総額で大小）を上部に大きく敷き、
       その上に「今日のひとこと（大見出し15字＋内容60字）＋ししまる」を重ねる
    ④きょうのポイント：ニュースカード4〜5枚（半自動。outputs\vn30_<日付>.news.json から）
    ⑤マクロ帯：状態ラベル付き（ライブ値＋手動バッジ＋出所）

  半自動: ニュースカード本文は CafeF 等の要約を人が記入（記事転載不可）。
          news.json が無ければ interpret が±3%急変から雛形を作る（このスクリプトは読むだけ）。
  堅牢性: 画像・news.json・マクロ欠落でも本体は止めない。
  依存: なし（PowerShell 7 標準のみ）。assets\shishimaru.png を相対参照。
#>
[CmdletBinding()]
param([string]$InputPath, [string]$OutDir = (Join-Path $PSScriptRoot "..\outputs"))
$ErrorActionPreference = 'Stop'
$AssetsRel = "../assets/shishimaru.png"

if (-not $InputPath) {
  $InputPath = Get-ChildItem $OutDir -Filter "vn30_*.interpreted.json" -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
  if (-not $InputPath) {
    $InputPath = Get-ChildItem $OutDir -Filter "vn30_*.json" | Where-Object { $_.Name -notlike "*.interpreted.json" -and $_.Name -notlike "*.news.json" } |
      Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
  }
}
if (-not $InputPath -or -not (Test-Path $InputPath)) { throw "入力JSONが見つかりません。先に fetch/interpret を実行してください。" }
$p = Get-Content $InputPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $p.interpretation) {
  $ip0 = if ($p.indices.VNINDEX) { [double]$p.indices.VNINDEX.pct } else { [double]$p.indices.VN30.pct }
  $p | Add-Member interpretation ([ordered]@{ headline = if ($ip0 -gt 0) { '買い優勢' } elseif ($ip0 -lt 0) { '売り優勢' } else { '小動き' }; summary = ''; tone = 'flat' }) -Force
}
$it = $p.interpretation
$asof = [string]$p.as_of

# --- news.json（人が編集する半自動カード）読み込み --------------------------
$newsFile = Join-Path $OutDir ("vn30_{0}.news.json" -f $asof)
$news = $null
if (Test-Path $newsFile) { try { $news = Get-Content $newsFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Write-Warning "news.json 読込失敗（カードは雛形/空で継続）" } }

# --- ヘルパ ------------------------------------------------------------------
function Esc([string]$s) { if ($null -eq $s) { return "" } $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;') }
function Pct([double]$v)  { ('{0:+0.00;-0.00;0.00}' -f $v) + '%' }
function PctS([double]$v) { ('{0:+0.0;-0.0;0.0}' -f $v) + '%' }
function Chg([double]$v)  { '{0:+0.00;-0.00;0.00}' -f $v }
function N2([double]$v)   { '{0:N2}' -f $v }
function Money($v, [int]$dec = 0) { if ($null -eq $v) { return '—' } ('{0:N' + $dec + '}') -f [double]$v }
function TileStyle([double]$pct) {
  if ($pct -gt 0)     { $a = [math]::Round([math]::Min($pct / 3.0, 1.0) * 0.80 + 0.12, 2); $fg = if ($a -gt 0.5) { '#fff' } else { '#14532d' }; return "background:rgba(31,157,87,$a);color:$fg" }
  elseif ($pct -lt 0) { $a = [math]::Round([math]::Min([math]::Abs($pct) / 3.0, 1.0) * 0.80 + 0.12, 2); $fg = if ($a -gt 0.5) { '#fff' } else { '#7f1d1d' }; return "background:rgba(214,69,69,$a);color:$fg" }
  else                { return "background:#e5e1d6;color:#6b7670" }
}
# ニュース本文の簡易強調: **赤太字** と [[緑]]
function NewsHtml([string]$t) {
  if ([string]::IsNullOrWhiteSpace($t)) { return "<span class=`"todo`">（CafeF等で確認し、事実を1–2行で：記入待ち）</span>" }
  $s = Esc $t
  $s = [regex]::Replace($s, '\*\*(.+?)\*\*', '<b>$1</b>')
  $s = [regex]::Replace($s, '\[\[(.+?)\]\]', '<span class="g">$1</span>')
  return $s
}

$dt = [datetime]::ParseExact($asof, 'yyyy-MM-dd', $null)
$wd = @('日','月','火','水','木','金','土')[[int]$dt.DayOfWeek]
$dateLabel = "{0}.{1}.{2} （{3}）" -f $dt.Year, $dt.Month, $dt.Day, $wd

# --- ②指数バー --------------------------------------------------------------
$idxHtml = ""
foreach ($sym in @('VNINDEX','VN30')) {
  $x = $p.indices.$sym; if (-not $x) { continue }
  $cls = if ([double]$x.pct -gt 0) { 'up' } elseif ([double]$x.pct -lt 0) { 'down' } else { 'flat' }
  $name = if ($sym -eq 'VNINDEX') { 'VN-Index' } else { 'VN30' }
  $idxHtml += "<div class=`"idx`"><div class=`"lbl`">$name</div><div class=`"val`">$(N2 ([double]$x.close))</div><div class=`"chg $cls`">$(Chg ([double]$x.change)) / $(Pct ([double]$x.pct))</div></div>"
}
$total = [double]$p.breadth.total
$wUp = [math]::Round($p.breadth.up / $total * 100, 1); $wFl = [math]::Round($p.breadth.flat / $total * 100, 1); $wDn = [math]::Round($p.breadth.down / $total * 100, 1)
$breadthHtml = "<div class=`"breadth`"><div class=`"bbar`"><span style=`"width:$wUp%;background:#1f9d57`"></span><span style=`"width:$wFl%;background:#cdc8ba`"></span><span style=`"width:$wDn%;background:#d64545`"></span></div><div class=`"blabel`"><b style=`"color:#1f9d57`">▲$($p.breadth.up)</b>　－$($p.breadth.flat)　<b style=`"color:#d64545`">▼$($p.breadth.down)</b></div></div>"

# --- ③ヒートマップ（時価総額ランクで大小）------------------------------------
$ranked = @($p.stocks | Sort-Object { if ($null -ne $_.mcap_t) { [double]$_.mcap_t } else { 0 } } -Descending)
$rank = 0; $heatHtml = ""
foreach ($s in $ranked) {
  $rank++
  $sz = if ($rank -le 3) { 's4' } elseif ($rank -le 10) { 's3' } elseif ($rank -le 20) { 's2' } else { 's1' }
  $showPct = if ($rank -le 20) { "<div class=`"hpct`">$(PctS ([double]$s.pct))</div>" } else { "" }
  $heatHtml += "<div class=`"htile $sz`" style=`"$(TileStyle ([double]$s.pct))`"><div class=`"hcode`">$(Esc $s.code)</div>$showPct</div>"
}

# --- ④ニュースカード（half-auto）-------------------------------------------
$cardsSrc = @()
if ($news -and $news.cards) { $cardsSrc = @($news.cards) }
elseif ($it.cards) { $cardsSrc = @($it.cards | ForEach-Object { [pscustomobject]@{ tag = "$($_.code) $(PctS ([double]$_.pct))"; icon = $(if ($_.dir -eq 'up') { '🔺' } else { '🔻' }); dir = $_.dir; text = $_.reason } }) }
$ncards = ($cardsSrc | Select-Object -First 5 | ForEach-Object {
    $icon = if ($_.icon) { $_.icon } else { '📰' }
    $dir = if ($_.dir) { $_.dir } else { '' }
    $tag = if ($_.tag) { "<span class=`"ntag $dir`">$(Esc $_.tag)</span>" } else { "" }
    "<div class=`"ncard`"><div class=`"nicon`">$icon</div><div class=`"nbody`">$tag<div class=`"ntext`">$(NewsHtml $_.text)</div></div></div>"
  }) -join "`n"
if (-not $ncards) { $ncards = "<div class=`"ncard`"><div class=`"nicon`">📰</div><div class=`"nbody`"><div class=`"ntext`"><span class=`"todo`">この日のニュースカードは未記入（outputs\vn30_$asof.news.json を編集）。</span></div></div></div>" }

# --- ⑤マクロ帯（状態ラベル付き）--------------------------------------------
# ラベルは news.json の macro_labels を優先、無ければ前営業日の値と比較して自動判定。
$priorMacro = $null
$priorFile = Get-ChildItem $OutDir -Filter "vn30_*.json" -ErrorAction SilentlyContinue |
  Where-Object { $_.Name -notlike "*.interpreted.json" -and $_.Name -notlike "*.news.json" -and (($_.BaseName -replace 'vn30_','') -lt $asof) } |
  Sort-Object Name -Descending | Select-Object -First 1
if ($priorFile) { try { $priorMacro = (Get-Content $priorFile.FullName -Raw -Encoding UTF8 | ConvertFrom-Json).macro } catch { } }
function MLabel($key, $cur) {
  if ($news -and $news.macro_labels -and $news.macro_labels.$key) { return [string]$news.macro_labels.$key }
  if ($priorMacro -and $priorMacro.$key -and $null -ne $priorMacro.$key.value -and $null -ne $cur.value) {
    $pv = [double]$priorMacro.$key.value; $cv = [double]$cur.value
    if ($pv -ne 0) { $d = ($cv - $pv) / $pv * 100; return $(if ([math]::Abs($d) -lt 0.2) { '横ばい' } elseif ($d -gt 0) { '上昇' } else { '低下' }) }
  }
  return ''
}
function MBox($key, $name, $item, [int]$dec) {
  $val = Money $item.value $dec
  $man = if ($item -and -not $item.live) { ' <span class="man">手動</span>' } else { '' }
  $lab = MLabel $key $item
  $labHtml = if ($lab) { "<span class=`"mlabel`">＼$lab／</span>" } else { "" }
  "<div class=`"mbox`">$labHtml<div class=`"mname`"><b>$name</b></div><div class=`"mval`">$val$man</div></div>"
}
$mz = $p.macro
if ($mz) {
  $liveSrc = @(); foreach ($k in 'usd_vnd','vnd_jpy','gold') { if ($mz.$k.live) { $liveSrc += $mz.$k.src } }
  $liveSrc = @($liveSrc | Select-Object -Unique)
  $srcNote = if ($liveSrc.Count) { "為替・金=ライブ（$($liveSrc -join '／')）、原油=手動。基準 $asof。" } else { "全て手動（基準 $asof）。" }
  $macroBoxes = (MBox 'vnd_jpy' 'ドン/円' $mz.vnd_jpy 1) + (MBox 'usd_vnd' 'USD/VND' $mz.usd_vnd 0) + (MBox 'gold' '金 USD/oz' $mz.gold 0) + (MBox 'oil' '原油 USD' $mz.oil 0)
  $macroHtml = "$macroBoxes<span class=`"note`">※$srcNote 対外利用時は使用レート明記。</span>"
} else {
  $macroHtml = "<div class=`"mbox`"><div class=`"mname`"><b>ドン/円</b></div><div class=`"mval`">178 <span class=`"man`">手動</span></div></div><span class=`"note`">※マクロ取得不可。手動値。</span>"
}

# --- HTML --------------------------------------------------------------------
$html = @"
<!doctype html><html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>デイリークエスト｜VN30分解新聞 $asof</title>
<style>
  :root{ --green:#16432f; --green2:#0f2e22; --cream:#f7f4ec; --gold:#d9b44a; --up:#1f9d57; --down:#d64545; --ink:#1a2420; --sub:#6b7670; --line:#e4e0d6; --card:#fffdf8; }
  *{box-sizing:border-box}
  body{margin:0;background:#ece8de;color:var(--ink);font-family:"Yu Gothic UI","Yu Gothic","Hiragino Kaku Gothic ProN",sans-serif;}
  .paper{max-width:980px;margin:24px auto;background:var(--card);border-radius:16px;overflow:hidden;box-shadow:0 12px 40px rgba(15,46,34,.12)}
  .masthead{position:relative;background:linear-gradient(110deg,var(--green2),var(--green));color:#fff;padding:20px 28px 18px}
  .questbadge{font-size:11px;letter-spacing:.28em;color:var(--gold);font-weight:700}
  .title{font-size:30px;font-weight:900;letter-spacing:.02em;margin:2px 0 0;line-height:1.1} .title .vn{color:var(--gold)}
  .subtitle{font-size:12px;opacity:.82;margin-top:4px}
  .mdate{position:absolute;right:28px;top:22px;text-align:right;font-size:12px;opacity:.9} .mdate b{display:block;font-size:18px;font-weight:700}
  .idxstrip{display:flex;gap:30px;align-items:center;padding:12px 28px;border-bottom:1px solid var(--line);background:var(--cream)}
  .idx .lbl{font-size:12px;color:var(--sub)} .idx .val{font-size:24px;font-weight:800} .idx .chg{font-size:13px;font-weight:700}
  .down{color:var(--down)} .up{color:var(--up)} .flat{color:var(--sub)}
  .breadth{margin-left:auto;text-align:right} .bbar{display:flex;width:190px;height:9px;border-radius:5px;overflow:hidden;background:#e7e3d8}
  .bbar span{display:block;height:100%} .blabel{font-size:11px;margin-top:4px;color:var(--sub)}
  /* ③ステージ：ヒートマップ＋オーバーレイ */
  .stage{position:relative;padding:10px 14px 6px;background:var(--cream)}
  .heatmap{display:grid;grid-template-columns:repeat(12,1fr);grid-auto-rows:30px;grid-auto-flow:dense;gap:4px}
  .htile{border-radius:6px;display:flex;flex-direction:column;align-items:center;justify-content:center;overflow:hidden}
  .htile .hcode{font-weight:800;line-height:1} .htile .hpct{font-weight:700;line-height:1;margin-top:2px;opacity:.95}
  .s4{grid-column:span 4;grid-row:span 3} .s4 .hcode{font-size:20px} .s4 .hpct{font-size:13px}
  .s3{grid-column:span 3;grid-row:span 2} .s3 .hcode{font-size:15px} .s3 .hpct{font-size:11px}
  .s2{grid-column:span 2;grid-row:span 2} .s2 .hcode{font-size:13px} .s2 .hpct{font-size:10px}
  .s1{grid-column:span 2;grid-row:span 1} .s1 .hcode{font-size:11px}
  .overlay{position:absolute;inset:10px 14px;display:flex;align-items:center;justify-content:center;gap:8px;pointer-events:none}
  .speech{background:rgba(255,253,248,.97);border:2px solid var(--green);border-radius:16px;padding:16px 22px;max-width:560px;box-shadow:0 8px 24px rgba(15,46,34,.18)}
  .kicker{font-size:11px;letter-spacing:.22em;color:var(--sub)}
  .headline{font-size:32px;font-weight:900;color:var(--down);margin:5px 0 9px;line-height:1.22}
  .headline.up{color:var(--up)} .headline.flat{color:var(--green)}
  .lead{font-size:14.5px;color:#2f3a33;line-height:1.7;margin:0;font-weight:500}
  .shishi-wrap{text-align:center;align-self:flex-end} .shishi{width:148px;height:148px;object-fit:contain;filter:drop-shadow(0 6px 10px rgba(15,46,34,.22))} .shishi-name{font-size:10px;color:var(--green);font-weight:700;margin-top:-6px}
  /* ④ニュースカード（主役・大きく）*/
  .news{padding:18px 28px 8px} .news-h{font-size:13px;color:var(--sub);font-weight:700;margin:0 0 12px;letter-spacing:.06em}
  .ncard{display:flex;gap:15px;align-items:flex-start;background:var(--cream);border:1px solid var(--line);border-radius:13px;padding:15px 18px;margin-bottom:11px}
  .nicon{flex-shrink:0;width:46px;height:46px;border-radius:11px;display:flex;align-items:center;justify-content:center;font-size:24px;background:#fff;border:1px solid var(--line)}
  .nbody{flex:1} .ntag{display:inline-block;font-size:11.5px;font-weight:800;color:#fff;background:var(--green);border-radius:5px;padding:2px 10px;margin-bottom:6px}
  .ntag.down{background:var(--down)} .ntag.up{background:var(--up)} .ntag.fx{background:#b8862f}
  .ntext{font-size:14.5px;line-height:1.7;color:#2f3a33} .ntext b{color:var(--down)} .ntext .g{color:var(--up);font-weight:700} .todo{color:#a8a294;font-style:italic}
  /* ⑤マクロ帯 */
  .macro{display:flex;flex-wrap:wrap;gap:10px;align-items:stretch;padding:14px 28px;background:var(--green2);color:#e8ede9}
  .mbox{background:rgba(255,255,255,.07);border:1px solid rgba(255,255,255,.12);border-radius:9px;padding:7px 14px;text-align:center;min-width:120px}
  .mlabel{display:block;font-size:11px;color:var(--gold);font-weight:700;margin-bottom:1px}
  .mname b{color:#cfe3d6;font-size:12px;font-weight:700} .mval{font-size:17px;font-weight:800;margin-top:1px}
  .macro .man{font-size:9px;background:#3c4f44;border-radius:3px;padding:1px 5px;margin-left:2px;font-weight:400;vertical-align:middle}
  .macro .note{font-size:10px;opacity:.7;margin-left:auto;max-width:34%;text-align:right;align-self:center}
  footer{padding:11px 28px 16px;font-size:10px;color:var(--sub);border-top:1px solid var(--line)}
</style></head>
<body><div class="paper">
  <div class="masthead">
    <div class="questbadge">DAILY QUEST</div>
    <div class="title">デイリークエスト｜<span class="vn">VN30</span>分解新聞</div>
    <div class="subtitle">ベトナム株でいちばん大事な30銘柄を、毎朝ギュッと圧縮</div>
    <div class="mdate">昨日のベトナム相場<b>$dateLabel</b></div>
  </div>
  <div class="idxstrip">$idxHtml $breadthHtml</div>
  <div class="stage">
    <div class="heatmap">$heatHtml</div>
    <div class="overlay">
      <div class="speech">
        <div class="kicker">今日のひとこと</div>
        <div class="headline $($it.tone)">$(Esc $it.headline)</div>
        <p class="lead">$(Esc $it.summary)</p>
      </div>
      <div class="shishi-wrap"><img class="shishi" src="$AssetsRel" alt="ししまる" onerror="this.style.display='none'"><div class="shishi-name">ししまる</div></div>
    </div>
  </div>
  <div class="news">
    <div class="news-h">きょうのポイント ― ベトナム現地報道より（要約）</div>
    $ncards
  </div>
  <div class="macro">$macroHtml</div>
  <footer>出典: VNDirect（無料公開API・非公式）／為替 open.er-api.com・金 gold-api.com ／ ニュースは現地報道(CafeF等)の要約・転載不可 ／ 寄与度は週次へ。基準日 $asof ／ 生成 $($p.generated_at)。投資判断は自己責任で。</footer>
</div></body></html>
"@

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
$outFile = Join-Path $OutDir ("vn30_{0}.html" -f $asof)
$html | Set-Content -Path $outFile -Encoding UTF8
Write-Host ("[render/v3 ぶたまる型] 図解HTMLを生成 → {0}" -f $outFile) -ForegroundColor Green
if (-not (Test-Path $newsFile)) { Write-Host ("  ※ニュースカード未記入。雛形: {0}" -f $newsFile) -ForegroundColor DarkYellow }
$outFile
