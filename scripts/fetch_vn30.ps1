<#
  fetch_vn30.ps1  ―  VN30 図解新聞 / 取得層（Step 2 / リリース版）
  --------------------------------------------------------------------
  役割:  VNDirect の無料JSON APIから
           ・VN30 構成30銘柄（終値・前日比・騰落率・出来高）= finfo
           ・VN-Index / VN30 指数（終値・前日比・出来高＋直近トレンド）= dchart
         を取得し整形。さらにリリース運用向けに
           ・マクロ帯（為替・金・原油）をライブ取得（per-item で手動フォールバック）
           ・鮮度ガード／VN30入替ガード（休場続き・年2回の銘柄入替に注意喚起）
         を行い outputs\vn30_<asof>.json に書き出す。

  設計上の約束:
    ・取得層は独立。ソースが壊れたらこのファイルだけ差し替える。
    ・銘柄リストは config\vn30_universe.json に分離（年2回の入替を手で対応）。
    ・前日比の基準は ref(=close-change) と prev_date を明示記録。
    ・★マクロ/トレンドの取得失敗は「新聞本体を止めない」。該当ブロックだけ
      手動値/非表示に縮退する（弓場さん指示）。コア(30銘柄＋指数)のみ必須。

  使い方:   pwsh -File scripts\fetch_vn30.ps1
  依存:     なし（PowerShell 7 標準のみ）
#>
[CmdletBinding()]
param(
  [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config\vn30_universe.json"),
  [string]$OutDir     = (Join-Path $PSScriptRoot "..\outputs")
)

$ErrorActionPreference = 'Stop'
$ProgressPreference     = 'SilentlyContinue'
$UA = @{ "User-Agent" = "Mozilla/5.0" }

function Invoke-Json {
  param([string]$Uri, [int]$Retry = 2)
  for ($i = 0; $i -le $Retry; $i++) {
    try   { return Invoke-RestMethod -Uri $Uri -Headers $UA -TimeoutSec 30 }
    catch { if ($i -eq $Retry) { throw "取得失敗 ($Uri): $($_.Exception.Message)" }; Start-Sleep -Seconds 2 }
  }
}

# 第4月曜（VN30入替日）を返す
function Get-FourthMonday([int]$year, [int]$month) {
  $d = [datetime]::new($year, $month, 1); $mons = @()
  for ($i = 0; $i -lt 31; $i++) { $x = $d.AddDays($i); if ($x.Month -ne $month) { break }; if ($x.DayOfWeek -eq 'Monday') { $mons += $x } }
  return $mons[3]
}

# --- 設定読み込み ------------------------------------------------------------
if (-not (Test-Path $ConfigPath)) { throw "設定ファイルが見つかりません: $ConfigPath" }
$cfg      = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$tickers  = $cfg.constituents.code
$sectorOf = @{}; foreach ($c in $cfg.constituents) { $sectorOf[$c.code] = $c.sector }
Write-Host ("設定読込: {0}銘柄 / 基準 {1}" -f $tickers.Count, $cfg.meta.index_basis) -ForegroundColor DarkGray

# --- 入替ガード（年2回・1月/7月の第4月曜が近いと警告）-----------------------
$today = (Get-Date).Date
foreach ($mo in 1, 7) {
  $fm = Get-FourthMonday $today.Year $mo
  if ([math]::Abs(($fm - $today).Days) -le 7) {
    Write-Warning ("VN30入替が近い（{0}=第4月曜）。config\vn30_universe.json の構成銘柄を確認・更新してください。" -f $fm.ToString('yyyy-MM-dd'))
  }
}

# --- [1] 30銘柄: finfo stock_prices（1コール一括・コア）----------------------
$codeList = $tickers -join ","
$finfoUrl = "https://api-finfo.vndirect.com.vn/v4/stock_prices?sort=date:desc&q=code:$codeList&size=180"
$finfo    = Invoke-Json $finfoUrl
if (-not $finfo.data) { throw "finfo: データ無し（API仕様変更の可能性 → 予備ソースへ）" }

# 当日未確定スタブ（寄り付き前/場中に全銘柄 前日比0 の行が来る）を飛ばし、
# 最初の「実取引日（騰落の合計が非ゼロ）」を基準日 as_of に採用する。
$dates = @($finfo.data.date | Sort-Object -Unique -Descending)
$asof = $null
foreach ($dt in $dates) {
  $absSum = ($finfo.data | Where-Object { $_.date -eq $dt } | ForEach-Object { [math]::Abs([double]$_.pctChange) } | Measure-Object -Sum).Sum
  if ($absSum -gt 0) { $asof = $dt; break }
}
if (-not $asof) { $asof = $dates[0] }
if ($dates[0] -ne $asof) { Write-Host ("  本日分($($dates[0]))は未確定のため、確定済みの $asof を使用します。" ) -ForegroundColor DarkYellow }

$stocks = foreach ($code in $tickers) {
  $rows = $finfo.data | Where-Object { $_.code -eq $code -and $_.date -le $asof } | Sort-Object date -Descending
  if (-not $rows) { Write-Warning "  ${code}: データ取得できず（停止/未上場?）"; continue }
  $r        = $rows[0]
  $prevDate = if ($rows.Count -ge 2) { $rows[1].date } else { $null }
  [pscustomobject]@{
    code = $code; sector = $sectorOf[$code]
    close = [math]::Round([double]$r.close, 2); change = [math]::Round([double]$r.change, 2)
    pct = [math]::Round([double]$r.pctChange, 2); ref = [math]::Round([double]$r.close - [double]$r.change, 2)
    volume = [long]$r.nmVolume; date = $r.date; prev_date = $prevDate
  }
}

# --- 健全性チェック ----------------------------------------------------------
$missing = $tickers | Where-Object { $_ -notin $stocks.code }
if ($missing) { Write-Warning ("欠落銘柄: {0}（30銘柄揃わず）" -f ($missing -join ", ")) }
$stale = $stocks | Where-Object { $_.date -ne $asof }
if ($stale) { Write-Warning ("基準日 $asof と異なる銘柄: {0}（停止/休場の可能性）" -f (($stale | ForEach-Object { "$($_.code)=$($_.date)" }) -join ", ")) }

# --- 鮮度ガード（基準日が古い＝休場続き/取得遅延の疑い）----------------------
$ageDays = ($today - [datetime]::ParseExact($asof, 'yyyy-MM-dd', $null)).Days
if ($ageDays -gt 4) { Write-Warning ("基準日 $asof は $ageDays 日前。休場続き/取得遅延の可能性 → 目視確認を推奨。") }

# --- [2] 指数 + トレンド: dchart history（コア。トレンド配列は best-effort）---
$indices = @{}; $trend = @{}
foreach ($sym in $cfg.indices) {
  $u = "https://dchart-api.vndirect.com.vn/dchart/history?symbol=$sym&resolution=D&from=1717000000&to=1799999999"
  $h = Invoke-Json $u
  if ($h.s -ne 'ok' -or -not $h.c) { Write-Warning "指数 $sym 取得失敗"; continue }
  $n = $h.c.Count
  $close = [double]$h.c[$n-1]; $prev = [double]$h.c[$n-2]
  $indices[$sym] = [pscustomobject]@{
    close = [math]::Round($close, 2); change = [math]::Round($close - $prev, 2)
    pct = [math]::Round(($close - $prev) / $prev * 100, 2); volume = [long]$h.v[$n-1]
    date = ([DateTimeOffset]::FromUnixTimeSeconds([long]$h.t[$n-1])).ToString("yyyy-MM-dd")
  }
  try {
    $tk = [math]::Min(20, $n)
    $trend[$sym] = [pscustomobject]@{
      closes = @($h.c[($n-$tk)..($n-1)] | ForEach-Object { [math]::Round([double]$_, 2) })
      dates  = @($h.t[($n-$tk)..($n-1)] | ForEach-Object { ([DateTimeOffset]::FromUnixTimeSeconds([long]$_)).ToString("MM/dd") })
    }
  } catch { Write-Warning "  $sym トレンド生成スキップ（チャートは非表示で継続）" }
}

# --- [3] 騰落幅・セクター別強弱 ---------------------------------------------
$up   = ($stocks | Where-Object { $_.pct -gt 0 }).Count
$down = ($stocks | Where-Object { $_.pct -lt 0 }).Count
$flat = $stocks.Count - $up - $down
$bySector = $stocks | Group-Object sector | ForEach-Object {
  [pscustomobject]@{ sector = $_.Name; count = $_.Count
    avg_pct = [math]::Round((($_.Group.pct | Measure-Object -Average).Average), 2)
    up = ($_.Group | Where-Object { $_.pct -gt 0 }).Count; down = ($_.Group | Where-Object { $_.pct -lt 0 }).Count }
} | Sort-Object avg_pct -Descending

# --- マクロ帯（ライブ・per-item 縮退。失敗しても新聞は止めない）--------------
function Get-Macro($fb) {
  $usdVnd = $null; $vndJpy = $null; $gold = $null
  try {
    $fx = Invoke-RestMethod "https://open.er-api.com/v6/latest/USD" -Headers $UA -TimeoutSec 20
    if ($fx.result -eq 'success') { $usdVnd = [double]$fx.rates.VND; $vndJpy = [double]$fx.rates.VND / [double]$fx.rates.JPY }
  } catch { }
  try { $g = Invoke-RestMethod "https://api.gold-api.com/price/XAU" -Headers $UA -TimeoutSec 15; $gold = [double]$g.price } catch { }
  $item = { param($v, $live, $src, $fbv) if ($null -ne $v) { [ordered]@{ value = $v; live = $true; src = $src } } else { [ordered]@{ value = $fbv; live = $false; src = '手動' } } }
  [ordered]@{
    usd_vnd = & $item ($(if ($usdVnd) { [math]::Round($usdVnd, 0) })) $true 'open.er-api.com' $fb.usd_vnd
    vnd_jpy = & $item ($(if ($vndJpy) { [math]::Round($vndJpy, 1) })) $true 'open.er-api.com' $fb.vnd_jpy
    gold    = & $item ($(if ($gold)   { [math]::Round($gold, 0) }))   $true 'gold-api.com'    $fb.gold_usd
    oil     = [ordered]@{ value = $fb.oil_usd; live = $false; src = '手動' }   # 無料の安定源が無いため手動
    fetched = (Get-Date).ToString("s")
  }
}
$macro = $null
try { $macro = Get-Macro $cfg.macro_fallback } catch { Write-Warning "マクロ取得をスキップ（手動値で継続）: $($_.Exception.Message)" }
if (-not $macro) {
  $fb = $cfg.macro_fallback
  $macro = [ordered]@{
    usd_vnd = [ordered]@{ value = $fb.usd_vnd; live = $false; src = '手動' }
    vnd_jpy = [ordered]@{ value = $fb.vnd_jpy; live = $false; src = '手動' }
    gold    = [ordered]@{ value = $fb.gold_usd; live = $false; src = '手動' }
    oil     = [ordered]@{ value = $fb.oil_usd; live = $false; src = '手動' }
    fetched = $null
  }
}

# --- ウェイト（寄与度④の素材）: 概算 = close×発行済株式数 / VN30合計 ----------
# ※単純時価総額ウェイト。正式VN30ウェイト(浮動株調整・外国人枠キャップ後)とはズレる→「概算」明記。
$sharesOf = @{}; foreach ($c in $cfg.constituents) { if ($c.shares) { $sharesOf[$c.code] = [double]$c.shares } }
$totMcap = ($stocks | Where-Object { $sharesOf[$_.code] } | ForEach-Object { $_.close * $sharesOf[$_.code] } | Measure-Object -Sum).Sum
foreach ($s in $stocks) {
  $sh = $sharesOf[$s.code]
  if ($sh -and $totMcap -gt 0) {
    $s | Add-Member shares ([long]$sh) -Force
    $s | Add-Member mcap_t ([math]::Round($s.close * $sh / 1e9, 1)) -Force          # 兆ドン（close=千ドン）
    $s | Add-Member weight ([math]::Round($s.close * $sh / $totMcap, 5)) -Force      # 構成比（小数）
  } else {
    $s | Add-Member shares $null -Force; $s | Add-Member mcap_t $null -Force; $s | Add-Member weight $null -Force
  }
}

# --- 出力オブジェクト --------------------------------------------------------
$payload = [ordered]@{
  as_of        = $asof
  generated_at = (Get-Date).ToString("s")
  data_age_days = $ageDays
  source       = "VNDirect (finfo + dchart) ※無料公開API・非公式"
  contribution_index = $cfg.contribution_index
  card_threshold_pct = $cfg.card_threshold_pct
  indices      = $indices
  trend        = $trend
  breadth      = [ordered]@{ up = $up; down = $down; flat = $flat; total = $stocks.Count }
  by_sector    = $bySector
  stocks       = $stocks | Sort-Object pct -Descending
  macro        = $macro
}

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
$outFile = Join-Path $OutDir ("vn30_{0}.json" -f $asof)
$payload | ConvertTo-Json -Depth 8 | Set-Content -Path $outFile -Encoding UTF8

# --- コンソール目視チェック --------------------------------------------------
Write-Host ""
Write-Host ("=== VN30 図解新聞 取得結果  基準日 {0} ===" -f $asof) -ForegroundColor Cyan
foreach ($sym in $cfg.indices) { if ($indices[$sym]) { $x = $indices[$sym]; Write-Host ("  {0,-8} {1,10:N2}  {2,7:+0.00;-0.00} ({3,6:+0.00;-0.00}%)" -f $sym, $x.close, $x.change, $x.pct) } }
Write-Host ("  騰落: 上昇 {0} / 下落 {1} / 変わらず {2}" -f $up, $down, $flat) -ForegroundColor DarkGray
$ml = @(); foreach ($k in 'usd_vnd','vnd_jpy','gold','oil') { $v = $macro[$k]; $ml += ("{0}={1}{2}" -f $k, $v.value, $(if ($v.live) { '' } else { '(手動)' })) }
Write-Host ("  マクロ: " + ($ml -join "  ")) -ForegroundColor DarkGray
Write-Host ("→ 出力: {0}" -f $outFile) -ForegroundColor Green
