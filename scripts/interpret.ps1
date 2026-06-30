<#
  interpret.ps1  ―  VN30 図解新聞 / 解釈層 [3]（v2: 寄与度ドリブン）
  --------------------------------------------------------------------
  役割:  fetch_vn30.ps1 の outputs\vn30_<asof>.json を読み、
         ④寄与度（誰が指数を何pt動かしたか＝綱引きの収支）を計算し、
         ②大見出し(全角15字以内)＋内容(全角60字以内) を寄与度から自動生成、
         ⑥急変カード（|騰落率|≧閾値の銘柄。理由は半自動=人が後で1-2行）を抽出。
         outputs\vn30_<asof>.interpreted.json に interpretation を足して書き出す。

  寄与度の定義:  contrib_i(％pt) = weight_i × pct_i
    weight_i = close_i×発行済株式数 / VN30合計（単純時価総額・概算）。
    ★正式VN30ウェイト(浮動株調整後)とはズレる → 新聞に「概算寄与度」と明記。
    構造（誰が押し下げ/押し上げたか）は概算でも十分正しく出る。

  どんな日でも破綻しない設計（弓場さん留意点）は v1 同様に維持。
  依存: なし（PowerShell 7 標準のみ）
#>
[CmdletBinding()]
param([string]$InputPath, [string]$OutDir = (Join-Path $PSScriptRoot "..\outputs"))
$ErrorActionPreference = 'Stop'

if (-not $InputPath) {
  $InputPath = Get-ChildItem $OutDir -Filter "vn30_*.json" |
    Where-Object { $_.Name -notlike "*.interpreted.json" -and $_.Name -notlike "*.news.json" } |
    Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $InputPath -or -not (Test-Path $InputPath)) { throw "入力JSONが見つかりません。先に fetch_vn30.ps1 を実行してください。" }
$p = Get-Content $InputPath -Raw -Encoding UTF8 | ConvertFrom-Json

# --- 整形ヘルパ --------------------------------------------------------------
function Pt([double]$v)  { ('{0:+0.0;-0.0;0.0}' -f $v) + 'pt' }
function PtA([double]$v) { ('{0:0.0}' -f [math]::Abs($v)) + 'pt' }
function Pct([double]$v) { ('{0:+0.0;-0.0;0.0}' -f $v) + '%' }
function Len([string]$s) { if ($null -eq $s) { 0 } else { $s.Length } }

# --- 素材 --------------------------------------------------------------------
$idxSym = if ($p.contribution_index) { [string]$p.contribution_index } else { 'VN30' }
$idx = if ($p.indices.$idxSym) { $p.indices.$idxSym } elseif ($p.indices.VNINDEX) { $p.indices.VNINDEX } else { $p.indices.VN30 }
$actualPct = [double]$idx.pct
$br = $p.breadth
$up = [int]$br.up; $down = [int]$br.down; $flat = [int]$br.flat

# --- ④ 寄与度（綱引きの収支）------------------------------------------------
$hasWeight = @($p.stocks | Where-Object { $null -ne $_.weight }).Count -gt 0
$contribs = @()
foreach ($s in $p.stocks) {
  $w = if ($null -ne $s.weight) { [double]$s.weight } else { 0 }
  $contribs += [pscustomobject]@{
    code = $s.code; sector = $s.sector; pct = [double]$s.pct
    weight = [math]::Round($w, 5); contrib = [math]::Round($w * [double]$s.pct, 3)
  }
}
$pushUp   = [math]::Round((($contribs | Where-Object { $_.contrib -gt 0 }).contrib | Measure-Object -Sum).Sum, 2)
$pushDown = [math]::Round((($contribs | Where-Object { $_.contrib -lt 0 }).contrib | Measure-Object -Sum).Sum, 2)
$net      = [math]::Round($pushUp + $pushDown, 2)
$topUp    = @($contribs | Where-Object { $_.contrib -gt 0 } | Sort-Object contrib -Descending | Select-Object -First 5)
$topDown  = @($contribs | Where-Object { $_.contrib -lt 0 } | Sort-Object contrib | Select-Object -First 5)
$secContrib = @($contribs | Group-Object sector | ForEach-Object {
    [pscustomobject]@{ sector = $_.Name; contrib = [math]::Round((($_.Group.contrib | Measure-Object -Sum).Sum), 2); count = $_.Count }
  } | Sort-Object contrib -Descending)
$secUp   = $secContrib | Select-Object -First 1      # 最も押し上げたセクター
$secDown = $secContrib | Select-Object -Last 1       # 最も押し下げたセクター
$mover   = $contribs | Sort-Object { [math]::Abs($_.contrib) } -Descending | Select-Object -First 1   # 最大の動かし手

# --- ②結果語 ----------------------------------------------------------------
$absP = [math]::Abs($actualPct)
$resultWord =
  if ($actualPct -gt 0) { if ($absP -lt 0.3) { '小幅高' } elseif ($absP -lt 1.5) { '上昇' } else { '大幅高' } }
  elseif ($actualPct -lt 0) { if ($absP -lt 0.3) { '小幅安' } elseif ($absP -lt 1.5) { '下落' } else { '大幅安' } }
  else { '横ばい' }
$tone = if ($actualPct -gt 0) { 'up' } elseif ($actualPct -lt 0) { 'down' } else { 'flat' }

# --- ②大見出し（全角15字以内）---------------------------------------------
function FitHeadline([string[]]$cands, [string]$fallback) {
  foreach ($c in $cands) { if ((Len $c) -le 15) { return $c } }
  return $fallback
}
if (-not $hasWeight) {
  # ウェイト無し（株数未設定など）→ v1相当の素直な見出しに縮退
  $headline = FitHeadline @("指数は$resultWord、$($secUp.sector)が支え", "指数は$resultWord") "指数は$resultWord"
}
elseif ($mover.contrib -lt 0) {
  # 下げの主役が引っ張った日（典型）
  $headline = FitHeadline @(
    "$($mover.code)急落、$($secUp.sector)も支えきれず",
    "$($mover.code)安が指数を圧迫",
    "$($mover.code)が指数押し下げ"
  ) "指数$resultWord、$($mover.code)主導"
}
elseif ($mover.contrib -gt 0) {
  # 上げの主役が引っ張った日
  $headline = FitHeadline @(
    "$($mover.code)主導で指数$resultWord",
    "$($secUp.sector)高、$($mover.code)が牽引",
    "$($mover.code)が指数を押し上げ"
  ) "指数$resultWord、$($mover.code)主導"
}
else {
  $headline = FitHeadline @("綱引き拮抗で$resultWord", "材料難で小動き") "小動き"
}

# --- ②内容（全角60字以内）--------------------------------------------------
# 押し下げ主役 vs 押し上げ側、の物語を寄与度の数字で。長すぎたら末尾節を落とす。
$lines = @()   # v1互換のフォールバック行も残す
$lines += "上昇 $up／下落 $down／変わらず $flat（30銘柄）。"

if ($hasWeight -and $mover.contrib -lt 0) {
  $rot = if ($mover.sector -ne $secUp.sector) { "物色は$($mover.sector)から$($secUp.sector)へ。" } else { "" }
  $s1 = "$($mover.code)だけで指数を約$(PtA $mover.contrib)押し下げ。$($secUp.sector)$($secUp.count)社の上昇($(Pt $secUp.contrib))も及ばず$resultWord。$rot"
  $s2 = "$($mover.code)だけで指数を約$(PtA $mover.contrib)押し下げ。$($secUp.sector)の上昇も及ばず$resultWord。"
  $summary = if ((Len $s1) -le 60) { $s1 } elseif ((Len $s2) -le 60) { $s2 } else { "$($mover.code)中心に売られ$resultWord。" }
}
elseif ($hasWeight -and $mover.contrib -gt 0) {
  $s1 = "$($mover.code)が指数を約$(PtA $mover.contrib)押し上げ、$($secUp.sector)主導で$resultWord。押し下げは$($secDown.sector)($(Pt $secDown.contrib))どまり。"
  $s2 = "$($mover.code)が指数を約$(PtA $mover.contrib)押し上げ、$($secUp.sector)主導で$resultWord。"
  $summary = if ((Len $s1) -le 60) { $s1 } elseif ((Len $s2) -le 60) { $s2 } else { "$($mover.code)主導で$resultWord。" }
}
else {
  $summary = "押し上げ$(Pt $pushUp)と押し下げ$(Pt $pushDown)が拮抗し$resultWord。上昇$up・下落$down。"
  if ((Len $summary) -gt 60) { $summary = "強弱拮抗で$resultWord。上昇$up・下落$down。" }
}

# --- ⑥急変カード（|騰落率|≧閾値。理由は空＝人が後で1-2行）-------------------
$thr = if ($p.card_threshold_pct) { [double]$p.card_threshold_pct } else { 3.0 }
$allCards = @()
foreach ($s in ($p.stocks | Where-Object { [math]::Abs([double]$_.pct) -ge $thr } | Sort-Object { [math]::Abs([double]$_.pct) } -Descending)) {
  $cc = ($contribs | Where-Object { $_.code -eq $s.code }).contrib
  $allCards += [ordered]@{ code = $s.code; sector = $s.sector; pct = [double]$s.pct; contrib = $cc; dir = $(if ($s.pct -ge 0) { 'up' } else { 'down' }); reason = "" }
}
# 反復・冗長回避: カードは大きく動いた上位6本まで。残りは件数だけ添える。
$cards = @($allCards | Select-Object -First 6)
$cardsMore = $allCards.Count - $cards.Count

# --- interpretation を組み立て ----------------------------------------------
$interp = [ordered]@{
  headline = $headline                 # ②大見出し（15字以内）
  summary  = $summary                  # ②内容（60字以内）
  tone     = $tone
  result   = $resultWord
  contribution = [ordered]@{
    index     = $idxSym
    note      = "概算寄与度（単純時価総額ウェイト。正式VN30ウェイトとはズレる）"
    push_up   = $pushUp
    push_down = $pushDown
    net       = $net
    top_up    = @($topUp   | ForEach-Object { [ordered]@{ code = $_.code; sector = $_.sector; pct = $_.pct; contrib = $_.contrib } })
    top_down  = @($topDown | ForEach-Object { [ordered]@{ code = $_.code; sector = $_.sector; pct = $_.pct; contrib = $_.contrib } })
    by_sector = @($secContrib | ForEach-Object { [ordered]@{ sector = $_.sector; contrib = $_.contrib; count = $_.count } })
  }
  cards    = $cards
  cards_more = $cardsMore
  lines    = @($lines | Select-Object -First 3)
  top_gainer = [ordered]@{ code = ($p.stocks | Sort-Object pct -Descending | Select-Object -First 1).code; pct = ($p.stocks | Sort-Object pct -Descending | Select-Object -First 1).pct }
  top_loser  = [ordered]@{ code = ($p.stocks | Sort-Object pct | Select-Object -First 1).code; pct = ($p.stocks | Sort-Object pct | Select-Object -First 1).pct }
}
$p | Add-Member -NotePropertyName interpretation -NotePropertyValue $interp -Force

$outFile = Join-Path $OutDir ("vn30_{0}.interpreted.json" -f $p.as_of)
$p | ConvertTo-Json -Depth 8 | Set-Content -Path $outFile -Encoding UTF8

# --- ニュースカード雛形(news.json)を半自動生成（既存は絶対に上書きしない）-----
# 人がCafeF等の要約を text に書く。±3%急変があればその銘柄をカード化して優先。
$newsFile = Join-Path $OutDir ("vn30_{0}.news.json" -f $p.as_of)
if (-not (Test-Path $newsFile)) {
  $seed = @()
  foreach ($c in $cards) {
    $arrow = if ($c.dir -eq 'up') { '🔺' } else { '🔻' }
    $seed += [ordered]@{ tag = "$($c.code) $(Pct $c.pct)"; icon = $arrow; dir = $c.dir; text = "" }
  }
  while ($seed.Count -lt 3) { $seed += [ordered]@{ tag = ""; icon = "📰"; dir = ""; text = "" } }
  $starter = [ordered]@{
    _note = "ニュースカードは人が編集（CafeF等の事実を自分の言葉で1-2行・転載不可）。text内は **赤太字** と [[緑]] で強調可。±3%急変は雛形を自動生成済み。macro_labels は上昇/低下/横ばい等を手で（空なら前日比から自動判定）。"
    cards = @($seed)
    macro_labels = [ordered]@{ vnd_jpy = ""; usd_vnd = ""; gold = ""; oil = "" }
  }
  $starter | ConvertTo-Json -Depth 6 | Set-Content -Path $newsFile -Encoding UTF8
  Write-Host ("  news.json 雛形を生成（要記入）: {0}" -f $newsFile) -ForegroundColor DarkYellow
}

# --- コンソール ---------------------------------------------------------------
Write-Host ("[interpret/v2] 大見出し({0}字): {1}" -f (Len $headline), $headline) -ForegroundColor Cyan
Write-Host ("  内容({0}字): {1}" -f (Len $summary), $summary)
Write-Host ("  綱引き: 押上 {0} / 押下 {1} / ネット {2}（{3}・概算）" -f (Pt $pushUp), (Pt $pushDown), (Pt $net), $idxSym) -ForegroundColor DarkGray
Write-Host ("   押下トップ: " + (($topDown | Select-Object -First 3 | ForEach-Object { "$($_.code) $(Pt $_.contrib)" }) -join " / "))
Write-Host ("   押上トップ: " + (($topUp   | Select-Object -First 3 | ForEach-Object { "$($_.code) $(Pt $_.contrib)" }) -join " / "))
if ($cards.Count) { Write-Host ("  急変カード(±$thr%超): " + (($cards | ForEach-Object { "$($_.code)($(Pct $_.pct))" }) -join " ")) -ForegroundColor DarkYellow }
Write-Host ("→ 出力: {0}" -f $outFile) -ForegroundColor Green
