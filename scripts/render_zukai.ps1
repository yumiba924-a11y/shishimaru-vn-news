<#
  render_zukai.ps1  ―  ししまるベトナム新聞 / 日次レンダラ（本番版）
  --------------------------------------------------------------------
  base/docs の「ししまるベトナム新聞」レイアウトを、データから生成する。
    数値（指数・VN30騰落・ヒートマップ）= interpreted.json から
    今日のひとこと・ニュースカード        = news.json（半自動・人編集。無ければ自動で埋める）
    日本語社名                            = config の name_ja
  タイトル「ししまるベトナム新聞」。寄与度は日次に出さない（週次の主役）。

  出力:
    docs/index.html              … GitHub Pages公開用（assets/ 参照）
    outputs/vn30_<asof>.html     … 日付別アーカイブ（../docs/assets/ 参照）

  堅牢性: どんなレジーム（全面高/安/小動き）でも、データ欠落（news無し等）でも崩れない。
  依存: なし（PowerShell 7 標準のみ）
#>
[CmdletBinding()]
param([string]$InputPath, [string]$OutDir = (Join-Path $PSScriptRoot "..\outputs"),
      [string]$DocsDir = (Join-Path $PSScriptRoot "..\docs"),
      [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config\vn30_universe.json"))
$ErrorActionPreference = 'Stop'

# --- 入力 --------------------------------------------------------------------
if (-not $InputPath) {
  $InputPath = Get-ChildItem $OutDir -Filter "vn30_*.interpreted.json" -ErrorAction SilentlyContinue |
    Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $InputPath -or -not (Test-Path $InputPath)) { throw "interpreted.json が見つかりません。先に fetch/interpret を実行してください。" }
$p   = Get-Content $InputPath -Raw -Encoding UTF8 | ConvertFrom-Json
$cfg = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$nameOf = @{}; foreach ($c in $cfg.constituents) { $nameOf[$c.code] = $c.name_ja }
$asof = [string]$p.as_of

# news.json（半自動・人編集枠）
$newsFile = Join-Path $OutDir ("vn30_{0}.news.json" -f $asof)
$news = $null
if (Test-Path $newsFile) { try { $news = Get-Content $newsFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Write-Warning "news.json 読込失敗（自動内容で継続）" } }

# --- ヘルパ ------------------------------------------------------------------
function Esc([string]$s) { if ($null -eq $s) { return "" } $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;') }
function N2([double]$v)  { '{0:N2}' -f $v }
function Pct2([double]$v){ '{0:+0.00;-0.00;0.00}' -f $v }      # -0.90
function Pct1([double]$v){ '{0:+0.0;-0.0;0.0}' -f $v }          # +2.5 / 0.0
# 発行日 = 相場日の翌営業日（土日スキップ）
function Next-BizDay([datetime]$d) { $n = $d.AddDays(1); while ($n.DayOfWeek -in 'Saturday','Sunday') { $n = $n.AddDays(1) }; $n }
$wdJ = @('日','月','火','水','木','金','土')
# ヒートマップのタイル色（緑=上昇/赤=下落/灰=変わらず）
function TileBg([double]$pct) {
  if ($pct -eq 0) { return @{ bg = '#E6E1D5'; fg = '#6b7670' } }
  $a = [math]::Round([math]::Min([math]::Max(0.25 + [math]::Abs($pct) * 0.23, 0.25), 0.88), 2)
  if ($pct -gt 0) { @{ bg = "rgba(0,73,44,$a)";   fg = $(if ($a -ge 0.42) { '#fff' } else { '#00492C' }) } }
  else            { @{ bg = "rgba(139,26,26,$a)"; fg = $(if ($a -ge 0.42) { '#fff' } else { '#8B1A1A' }) } }
}
# ニュース本文の簡易マークアップ: **赤太字** [[緑強調]]
function NewsHtml([string]$t) {
  if ([string]::IsNullOrWhiteSpace($t)) { return '<span style="color:#a8a294;font-style:italic;">（CafeF等の要約を1–2行で：記入待ち）</span>' }
  $s = Esc $t
  $s = [regex]::Replace($s, '\*\*(.+?)\*\*', '<b style="color:#8B1A1A;font-weight:900;font-size:21px;">$1</b>')
  $s = [regex]::Replace($s, '\[\[(.+?)\]\]', '<em style="color:#00492C;font-style:normal;font-weight:900;font-size:21px;">$1</em>')
  return $s
}
$accent = @{ green = '#00492C'; red = '#8B1A1A'; gold = '#B8922A'; teal = '#013820' }

# --- 日付 --------------------------------------------------------------------
$dt = [datetime]::ParseExact($asof, 'yyyy-MM-dd', $null)
$pub = Next-BizDay $dt
$dateLabel = "{0}.{1}.{2} （{3}）" -f $pub.Year, $pub.Month, $pub.Day, $wdJ[[int]$pub.DayOfWeek]

# --- 指数バー（VN-Index）-----------------------------------------------------
$vi = $p.indices.VNINDEX
$viPct = [double]$vi.pct
$viArrow = if ($viPct -gt 0) { '▲' } elseif ($viPct -lt 0) { '▼' } else { '―' }
$viBg = if ($viPct -gt 0) { '#1F7A4D' } elseif ($viPct -lt 0) { '#8B1A1A' } else { '#6b7670' }

# --- 騰落（HOSE全体。取得失敗時はVN30で代用・ラベル切替）---------------------
$br = if ($p.hose_breadth) { $p.hose_breadth } else { $p.breadth }
$brLabel = if ($p.hose_breadth) { 'HOSE 騰落（上昇 / 変わらず / 下落）' } else { 'VN30 騰落（上昇 / 変わらず / 下落）' }
$bUp = [int]$br.up; $bFl = [int]$br.flat; $bDn = [int]$br.down; $bT = [double]($bUp + $bFl + $bDn); if ($bT -le 0) { $bT = 1 }
$wUp = [math]::Round($bUp / $bT * 100, 1); $wFl = [math]::Round($bFl / $bT * 100, 1); $wDn = [math]::Round($bDn / $bT * 100, 1)

# --- 今日のひとこと（news優先→interpret）------------------------------------
$headline = if ($news -and $news.headline) { [string]$news.headline } else { [string]$p.interpretation.headline }
# 今日のひとこと本文: news優先。自動補完は breadth/セクター文(interpretation.lines)を使い、
# 寄与度pt(summary)は日次に出さない（寄与度は週次の主役）。
$leadLines = if ($news -and @($news.lead).Count -gt 0) { @($news.lead) }
             elseif (@($p.interpretation.lines).Count -gt 0) { @($p.interpretation.lines) }
             else { @([string]$p.interpretation.summary) }
$leadHtml = ($leadLines | ForEach-Object { "<div>$(Esc $_)</div>" }) -join "`n        "

# --- ヒートマップ（pct降順・社名つき）---------------------------------------
$tilesHtml = foreach ($s in $p.stocks) {
  $c = TileBg([double]$s.pct)
  @"
        <div style="border-radius:2px;padding:8px 2px;text-align:center;min-height:52px;display:flex;flex-direction:column;justify-content:center;gap:2px;background:$($c.bg);color:$($c.fg)">
          <div style="font-weight:800;font-size:18px;letter-spacing:.02em;">$(Esc $s.code)</div>
          <div style="font-size:11px;font-weight:600;opacity:.85;line-height:1.15;white-space:nowrap;">$(Esc $nameOf[$s.code])</div>
          <div style="font-size:18px;font-weight:700;opacity:.92;">$(Pct1 ([double]$s.pct))</div>
        </div>
"@
}
$tilesHtml = $tilesHtml -join "`n"

# --- きょうのポイント（news.cards。無ければ±3%急変を雛形表示）---------------
$cards = @()
if ($news -and $news.cards) { $cards = @($news.cards) }
elseif ($p.interpretation.cards) {
  $cards = @($p.interpretation.cards | ForEach-Object {
      [pscustomobject]@{ tag = "$($_.code) $(Pct1 ([double]$_.pct))"; color = $(if ($_.dir -eq 'up') { 'green' } else { 'red' }); icon = $(if ($_.dir -eq 'up') { 'graph-up-arrow' } else { 'graph-down-arrow' }); text = $_.reason } })
}
$nLast = $cards.Count - 1; $ci = -1
$cardsHtml = ($cards | ForEach-Object {
    $ci++
    $ac = $accent[[string]$_.color]; if (-not $ac) { $ac = '#00492C' }
    $ic = if ($_.icon) { [string]$_.icon } else { 'newspaper' }
    $mb = if ($ci -eq $nLast) { '24px 0 14px' } else { '24px 0 0' }
    @"
      <div style="position:relative;display:flex;gap:18px;align-items:center;background:#FBFAF5;border:1px solid #E8E4DC;border-top:3px solid $ac;border-radius:2px;padding:30px 22px 20px;margin:$mb;">
        <div style="flex-shrink:0;width:74px;height:74px;border-radius:2px;display:flex;align-items:center;justify-content:center;font-size:42px;background:#F0EADE;color:$ac;border:1px solid #E8E4DC;"><i class="bi bi-$ic" aria-hidden="true"></i></div>
        <div style="flex:1;">
          <span style="position:absolute;top:-16px;left:14px;display:inline-flex;align-items:center;font-size:18px;font-weight:800;color:#fff;border-radius:2px;padding:7px 15px;letter-spacing:.04em;background:$ac;box-shadow:0 3px 8px rgba(0,73,44,.22);">$(Esc $_.tag)</span>
          <div style="margin-top:0;"><div style="font-size:17px;line-height:1.7;color:#2A2A2A;font-weight:500;">$(NewsHtml ([string]$_.text))</div></div>
        </div>
      </div>
"@
  }) -join "`n"
if (-not $cardsHtml) { $cardsHtml = '      <div style="padding:20px;color:#a8a294;font-style:italic;">この日のニュースカードは未記入（outputs\vn30_' + $asof + '.news.json を編集）。</div>' }

# --- HTML本体（{ASSET} はあとで差し替え）------------------------------------
$html = @"
<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>ししまるベトナム新聞</title>
<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.css">
<style>
  body{margin:0;background:#E9E5DA;font-family:'Hiragino Sans','Yu Gothic Medium',YuGothic,'Yu Gothic',Meiryo,'Noto Sans JP',system-ui,sans-serif;color:#1A1A1A;-webkit-font-smoothing:antialiased;}
</style>
</head>
<body>
<div style="background:#E9E5DA;padding:28px 16px;display:flex;justify-content:center;">
<div style="width:1080px;max-width:100%;background:#FFFFFF;border-radius:2px;overflow:hidden;box-shadow:0 18px 50px rgba(0,73,44,.14);">

  <!-- MASTHEAD -->
  <div style="position:relative;background:linear-gradient(135deg,#00492C 0%,#013820 58%,#011D12 100%);color:#fff;padding:22px 32px 20px;display:flex;align-items:center;gap:18px;">
    <img src="{ASSET}/shishi1.png" alt="ししまる" style="height:74px;width:auto;flex-shrink:0;filter:drop-shadow(0 3px 6px rgba(0,0,0,.25));">
    <div style="flex:1;text-align:left;">
      <div style="font-size:18px;font-weight:700;letter-spacing:.32em;color:#D8B95A;">DAILY QUEST</div>
      <div style="font-size:39px;font-weight:900;letter-spacing:.01em;line-height:1.08;margin-top:3px;">ししまる<span style="color:#D8B95A;">ベトナム</span>新聞</div>
      <div style="font-size:18px;opacity:.82;margin-top:5px;">ベトナム市場のいまを、ししまるがお届け</div>
    </div>
    <div style="text-align:right;flex-shrink:0;align-self:flex-start;">
      <div style="font-size:23px;font-weight:800;font-variant-numeric:tabular-nums;">$dateLabel</div>
    </div>
  </div>

  <!-- 指数バー -->
  <div style="display:flex;align-items:stretch;gap:10px;padding:14px 32px;background:#FBFAF5;border-bottom:1px solid #E8E4DC;">
    <span style="display:flex;align-items:center;font-size:18px;font-weight:800;letter-spacing:.16em;color:#00492C;padding-right:6px;border-right:1px solid #E8E4DC;">指数</span>
      <div style="display:flex;flex-direction:row;align-items:center;gap:14px;flex:1;padding:12px 18px;border-radius:2px;color:#fff;background:$viBg;">
        <div style="font-size:18px;opacity:.85;font-weight:600;white-space:nowrap;">VN-Index</div>
        <div style="font-size:31px;font-weight:800;font-variant-numeric:tabular-nums;line-height:1.05;white-space:nowrap;">$(N2 ([double]$vi.close))</div>
        <div style="font-size:20px;font-weight:700;opacity:.95;white-space:nowrap;"><span>$viArrow</span> $(Pct2 ([double]$vi.change)) ／ $(Pct2 $viPct)%</div>
      </div>
    <div style="flex:1;display:flex;flex-direction:column;justify-content:center;align-items:center;gap:8px;">
      <div style="font-size:18px;color:#555;font-weight:600;">$brLabel</div>
      <div style="display:flex;width:100%;height:11px;border-radius:2px;overflow:hidden;background:#E6E1D5;">
        <span style="width:$wUp%;background:#1F7A4D;height:100%;"></span><span style="width:$wFl%;background:#CFC9BB;height:100%;"></span><span style="width:$wDn%;background:#8B1A1A;height:100%;"></span>
      </div>
      <div style="font-size:27px;font-weight:800;display:flex;gap:16px;font-variant-numeric:tabular-nums;"><span style="color:#1F7A4D;">▲ $bUp</span><span style="color:#CFC9BB;">|</span><span style="color:#888;">― $bFl</span><span style="color:#CFC9BB;">|</span><span style="color:#8B1A1A;">▼ $bDn</span></div>
    </div>
  </div>

  <!-- 今日のひとこと -->
  <div style="position:relative;display:grid;grid-template-columns:1fr 318px;gap:0;align-items:center;padding:24px 32px 16px;background:linear-gradient(180deg,#FFFFFF,#FBFAF5);">
    <div style="position:relative;background:#FFFFFF;border:2px solid #00492C;border-radius:2px;padding:22px 28px;box-shadow:0 6px 24px rgba(0,73,44,.10);z-index:2;">
      <div style="width:48px;height:2px;background:#B8922A;margin-bottom:11px;"></div>
      <div style="font-size:18px;font-weight:700;letter-spacing:.18em;color:#555;">今日のひとこと</div>
      <div style="font-size:39px;font-weight:900;color:#8B1A1A;line-height:1.22;margin:7px 0 11px;letter-spacing:-.01em;">$(Esc $headline)</div>
      <div style="font-size:23px;line-height:1.95;color:#2A2A2A;font-weight:500;text-align:justify;text-align-last:justify;">
        $leadHtml
      </div>
      <div style="position:absolute;right:-10px;top:52px;width:18px;height:18px;background:#fff;border-right:2px solid #00492C;border-top:2px solid #00492C;transform:rotate(45deg);"></div>
    </div>
    <div style="justify-self:end;align-self:end;">
      <img src="{ASSET}/shishi2.png" alt="ししまる" style="height:262px;width:auto;display:block;filter:drop-shadow(0 6px 12px rgba(0,73,44,.18));">
    </div>
  </div>

  <!-- VN30 ヒートマップ -->
  <div style="padding:6px 32px 20px;background:#FBFAF5;border-bottom:1px solid #E8E4DC;">
    <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:11px;">
      <span style="font-size:18px;font-weight:800;letter-spacing:.16em;color:#00492C;">VN30 ヒートマップ　<span style="font-weight:600;color:#777;letter-spacing:.04em;">騰落率順・緑=上昇／赤=下落</span></span>
    </div>
    <div style="display:grid;grid-template-columns:repeat(6,1fr);gap:5px;">
$tilesHtml
    </div>
  </div>

  <!-- きょうのポイント -->
  <div style="padding:20px 32px 10px;">
    <div style="display:flex;align-items:center;gap:10px;margin-bottom:14px;">
      <span style="width:48px;height:2px;background:#B8922A;"></span>
      <span style="font-size:18px;font-weight:800;letter-spacing:.14em;color:#00492C;">きょうのポイント</span>
    </div>
$cardsHtml
  </div>

  <!-- フッター -->
  <div style="display:flex;align-items:center;padding:14px 32px 18px;background:#FBFAF5;">
    <img src="{ASSET}/shishi3.png" alt="ししまる" style="height:90px;width:auto;flex-shrink:0;">
    <p style="font-size:13px;line-height:1.7;color:#777;margin:0;flex:1;text-align:center;">出典: VNDirect／市況コメントはベトナム現地報道（CafeF・Thời báo Tài chính 等）を要約／基準日 $asof　投資判断は自己責任で</p>
    <div style="width:90px;flex-shrink:0;" aria-hidden="true"></div>
  </div>

</div>
</div>
</body>
</html>
"@

# --- 書き出し（docs=assets/ ・ outputs=../docs/assets/）----------------------
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
$docsFile = Join-Path $DocsDir 'index.html'
$outFile  = Join-Path $OutDir ("vn30_{0}.html" -f $asof)
($html.Replace('{ASSET}', 'assets')) | Set-Content -Path $docsFile -Encoding UTF8
($html.Replace('{ASSET}', '../docs/assets')) | Set-Content -Path $outFile -Encoding UTF8

Write-Host ("[render/ししまるベトナム新聞] 生成") -ForegroundColor Green
Write-Host ("  Pages公開: {0}" -f $docsFile)
Write-Host ("  アーカイブ: {0}" -f $outFile)
Write-Host ("  見出し: {0}" -f $headline) -ForegroundColor Cyan
$outFile
