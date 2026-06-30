<#
  weekly.ps1  ―  ししまるVN30分解新聞 / 週次レンダラ（寄与度ドリブン）
  --------------------------------------------------------------------
  日次で蓄積した outputs/vn30_<日>.interpreted.json（寄与度入り）の直近N営業日分を束ね、
  「今週 誰が指数を動かしたか」を寄与度で分解した週次新聞を生成する。

  構成（言葉で分解 → 図解で裏付け → 言葉で深掘り）:
    ①マストヘッド WEEKLY QUEST / ししまるVN30分解新聞 / 週範囲
    ②週サマリ（VN-Index 週間騰落・対象日数）
    ③今週のひとこと（言葉で分解：誰が動かしたか）
    ④寄与度の綱引き（★主役・図解）：押し上げ合計 ←→ 押し下げ合計、上位の押上/押下銘柄
    ⑤セクター別 週間寄与度（★主役・図解）：中央軸の横棒
    ⑥深掘り本文（言葉）
    ⑦フッター

  週間寄与度: Σ_days (weight_day × pct_day)（概算・各日の寄与を週で合算）。「概算」明記。
  出力: docs/weekly.html（Pages公開）＋ outputs/weekly_<週末>.html（アーカイブ）。
  依存: なし（PowerShell 7 標準）
#>
[CmdletBinding()]
param([int]$Days = 5,
      [string]$OutDir = (Join-Path $PSScriptRoot "..\outputs"),
      [string]$DocsDir = (Join-Path $PSScriptRoot "..\docs"),
      [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config\vn30_universe.json"))
$ErrorActionPreference = 'Stop'
$cfg = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$nameOf = @{}; foreach ($c in $cfg.constituents) { $nameOf[$c.code] = $c.name_ja }

# --- 直近N営業日の interpreted.json を集める --------------------------------
$files = Get-ChildItem $OutDir -Filter "vn30_*.interpreted.json" |
  Sort-Object Name -Descending | Select-Object -First $Days | Sort-Object Name
if ($files.Count -lt 1) { throw "interpreted.json が無い。先に日次を回して蓄積してください。" }
$daysData = $files | ForEach-Object { Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json }
$weekStart = $daysData[0].as_of; $weekEnd = $daysData[-1].as_of

# --- 週間寄与度を集計（Σ weight×pct）----------------------------------------
$contribByCode = @{}; $pctByCode = @{}; $sectorOf = @{}
foreach ($d in $daysData) {
  foreach ($s in $d.stocks) {
    $w = if ($null -ne $s.weight) { [double]$s.weight } else { 0 }
    if (-not $contribByCode.ContainsKey($s.code)) { $contribByCode[$s.code] = 0.0; $pctByCode[$s.code] = 0.0 }
    $contribByCode[$s.code] += $w * [double]$s.pct
    $pctByCode[$s.code]     += [double]$s.pct
    $sectorOf[$s.code] = $s.sector
  }
}
$rows = $contribByCode.Keys | ForEach-Object {
  [pscustomobject]@{ code = $_; sector = $sectorOf[$_]; contrib = [math]::Round($contribByCode[$_], 3); wpct = [math]::Round($pctByCode[$_], 2) }
}
$pushUp   = [math]::Round((($rows | Where-Object { $_.contrib -gt 0 }).contrib | Measure-Object -Sum).Sum, 2)
$pushDown = [math]::Round((($rows | Where-Object { $_.contrib -lt 0 }).contrib | Measure-Object -Sum).Sum, 2)
$net = [math]::Round($pushUp + $pushDown, 2)
$topUp   = @($rows | Where-Object { $_.contrib -gt 0 } | Sort-Object contrib -Descending | Select-Object -First 6)
$topDown = @($rows | Where-Object { $_.contrib -lt 0 } | Sort-Object contrib | Select-Object -First 6)
$secRows = @($rows | Group-Object sector | ForEach-Object {
    [pscustomobject]@{ sector = $_.Name; contrib = [math]::Round((($_.Group.contrib | Measure-Object -Sum).Sum), 2); count = $_.Count }
  } | Sort-Object contrib -Descending)
$mover = $rows | Sort-Object { [math]::Abs($_.contrib) } -Descending | Select-Object -First 1
$secLead = $secRows | Select-Object -First 1; $secLag = $secRows | Select-Object -Last 1

# --- VN-Index 週間騰落（最初の日の前日終値→最終日終値）-----------------------
$viFirst = $daysData[0].indices.VNINDEX; $viLast = $daysData[-1].indices.VNINDEX
$viPrev0 = [double]$viFirst.close - [double]$viFirst.change
$wIdxChg = [math]::Round([double]$viLast.close - $viPrev0, 2)
$wIdxPct = if ($viPrev0 -ne 0) { [math]::Round($wIdxChg / $viPrev0 * 100, 2) } else { 0 }
$wTone = if ($wIdxPct -gt 0) { 'up' } elseif ($wIdxPct -lt 0) { 'down' } else { 'flat' }

# --- 言葉で分解（見出し・深掘り）--------------------------------------------
$moverDir = if ($mover.contrib -lt 0) { '押し下げ' } else { '押し上げ' }
$resWord = if ($wIdxPct -gt 0) { if ($wIdxPct -ge 1.5) { '大幅高' } else { '上昇' } } elseif ($wIdxPct -lt 0) { if ($wIdxPct -le -1.5) { '大幅安' } else { '下落' } } else { '横ばい' }
# 見出しはデータ駆動で変化させる（毎週同じ「○○が動かした」を避ける＝反復ヘッジ）
$totAbs = (($rows | ForEach-Object { [math]::Abs($_.contrib) }) | Measure-Object -Sum).Sum; if ($totAbs -le 0) { $totAbs = 1 }
$dom = [math]::Abs($mover.contrib) / $totAbs
$secSpread = [double]$secLead.contrib - [double]$secLag.contrib
$headline = if ($dom -ge 0.45) { "今週は$($mover.code)が指数を独りで動かした" }
            elseif ($secSpread -ge 1.0) { "今週は$($secLead.sector)高・$($secLag.sector)安に二極化" }
            elseif ([math]::Abs($wIdxPct) -lt 0.3) { "今週は綱引き拮抗、方向感に乏しい" }
            elseif ($wTone -eq 'up') { "今週は$($secLead.sector)主導で買い優勢" }
            else { "今週は$($secLag.sector)が重し、売り優勢" }
$leadLines = @(
  "${weekStart}〜${weekEnd}、VN-Indexは週間 $(('{0:+0.0;-0.0;0.0}' -f $wIdxPct))%。",
  "$($mover.sector)の$($mover.code)が概算で約$([math]::Abs($mover.contrib).ToString('0.0'))pt、指数を$moverDir。",
  "$($secLead.sector)が押し上げ、$($secLag.sector)が押し下げの構図。"
)
$deep = "今週の指数を分解すると、押し上げ合計 $(('{0:+0.0;-0.0;0.0}' -f $pushUp))pt に対し押し下げ合計 $(('{0:+0.0;-0.0;0.0}' -f $pushDown))pt、ネット $(('{0:+0.0;-0.0;0.0}' -f $net))pt（概算）。最大の動かし手は$($mover.code)（$($mover.sector)）で、週間騰落 $(('{0:+0.0;-0.0;0.0}' -f $mover.wpct))%。セクターでは$($secLead.sector)が支え、$($secLag.sector)が重しとなった。寄与度は単純時価総額ウェイトによる概算で、正式VN30ウェイト（浮動株調整後）とはズレるが、構造の大小を掴むには十分。"

# --- ヘルパ ------------------------------------------------------------------
function Esc([string]$s) { if ($null -eq $s) { return "" } $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;') }
function Pt([double]$v) { ('{0:+0.0;-0.0;0.0}' -f $v) + 'pt' }
function PctW([double]$v){ ('{0:+0.0;-0.0;0.0}' -f $v) + '%' }
$dt = [datetime]::ParseExact($weekEnd, 'yyyy-MM-dd', $null)
$wdJ = @('日','月','火','水','木','金','土')
$pub = $dt.AddDays(1); while ($pub.DayOfWeek -in 'Saturday','Sunday') { $pub = $pub.AddDays(1) }
$dateLabel = "{0}.{1}.{2}〜{3}.{4}" -f ([datetime]::ParseExact($weekStart,'yyyy-MM-dd',$null)).Month, ([datetime]::ParseExact($weekStart,'yyyy-MM-dd',$null)).Day, $dt.Year, $dt.Month, $dt.Day

# --- 綱引きバー --------------------------------------------------------------
$maxAbs = [math]::Max([math]::Abs($pushDown), [math]::Abs($pushUp)); if ($maxAbs -le 0) { $maxAbs = 1 }
$wPd = [math]::Round([math]::Abs($pushDown) / $maxAbs * 50, 1); $wPu = [math]::Round($pushUp / $maxAbs * 50, 1)
function ContribList($arr, $col) {
  if (-not $arr -or @($arr).Count -eq 0) { return '<li style="color:#a8a294;font-style:italic;padding:6px 0;">該当なし</li>' }
  ($arr | ForEach-Object {
      "<li style='display:grid;grid-template-columns:64px 1fr 64px 70px;align-items:center;gap:8px;padding:7px 10px;border-radius:2px;'><span style='font-weight:800;font-size:17px;'>$(Esc $_.code)</span><span style='font-size:11px;color:#777;'>$(Esc $nameOf[$_.code])</span><span style='text-align:right;font-weight:600;font-size:14px;color:$col;'>$(PctW ([double]$_.wpct))</span><span style='text-align:right;font-weight:800;font-size:16px;color:$col;'>$(Pt ([double]$_.contrib))</span></li>"
    }) -join "`n"
}
$upListH   = ContribList $topUp   '#1F7A4D'
$downListH = ContribList $topDown '#8B1A1A'

# --- セクター横棒 ------------------------------------------------------------
$secMax = ($secRows | ForEach-Object { [math]::Abs($_.contrib) } | Measure-Object -Maximum).Maximum; if (-not $secMax -or $secMax -eq 0) { $secMax = 1 }
$secHtml = ($secRows | ForEach-Object {
    $v = [double]$_.contrib; $w = [math]::Round([math]::Abs($v) / $secMax * 50, 1)
    $side = if ($v -ge 0) { "left:50%;background:#1F7A4D" } else { "right:50%;background:#8B1A1A" }
    $vc = if ($v -gt 0) { '#1F7A4D' } elseif ($v -lt 0) { '#8B1A1A' } else { '#888' }
    @"
      <div style="display:grid;grid-template-columns:96px 1fr 62px;align-items:center;gap:10px;margin-bottom:9px;">
        <div style="font-size:14px;font-weight:600;text-align:right;">$(Esc $_.sector)<span style="color:#999;font-weight:400;font-size:11px;margin-left:3px;">($($_.count))</span></div>
        <div style="position:relative;height:20px;background:#EFEBE0;border-radius:2px;">
          <span style="position:absolute;left:50%;top:-2px;bottom:-2px;width:1px;background:#C9C2B2;"></span>
          <span style="position:absolute;top:0;bottom:0;border-radius:2px;width:$w%;$side;"></span>
        </div>
        <div style="font-size:15px;font-weight:800;color:$vc;text-align:left;">$(Pt $v)</div>
      </div>
"@
  }) -join "`n"

$leadHtml = ($leadLines | ForEach-Object { "<div>$(Esc $_)</div>" }) -join "`n        "

# --- HTML --------------------------------------------------------------------
$html = @"
<!DOCTYPE html>
<html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>ししまるVN30分解新聞</title>
<style>body{margin:0;background:#E9E5DA;font-family:'Hiragino Sans','Yu Gothic Medium',YuGothic,'Yu Gothic',Meiryo,'Noto Sans JP',system-ui,sans-serif;color:#1A1A1A;-webkit-font-smoothing:antialiased;}</style>
</head><body>
<div style="background:#E9E5DA;padding:28px 16px;display:flex;justify-content:center;">
<div style="width:1080px;max-width:100%;background:#FFFFFF;border-radius:2px;overflow:hidden;box-shadow:0 18px 50px rgba(0,73,44,.14);">

  <!-- MASTHEAD -->
  <div style="position:relative;background:linear-gradient(135deg,#013820 0%,#00492C 55%,#011D12 100%);color:#fff;padding:22px 32px 20px;display:flex;align-items:center;gap:18px;">
    <img src="{ASSET}/shishi1.png" alt="ししまる" style="height:74px;width:auto;flex-shrink:0;filter:drop-shadow(0 3px 6px rgba(0,0,0,.25));">
    <div style="flex:1;text-align:left;">
      <div style="font-size:18px;font-weight:700;letter-spacing:.32em;color:#D8B95A;">WEEKLY QUEST</div>
      <div style="font-size:39px;font-weight:900;letter-spacing:.01em;line-height:1.08;margin-top:3px;">ししまる<span style="color:#D8B95A;">VN30分解</span>新聞</div>
      <div style="font-size:18px;opacity:.82;margin-top:5px;">今週、誰が指数を動かしたか。寄与度で分解</div>
    </div>
    <div style="text-align:right;flex-shrink:0;align-self:flex-start;">
      <div style="font-size:21px;font-weight:800;font-variant-numeric:tabular-nums;">$dateLabel</div>
      <div style="font-size:12px;opacity:.7;margin-top:3px;">対象 $($files.Count) 営業日</div>
    </div>
  </div>

  <!-- 週サマリ -->
  <div style="display:flex;align-items:center;gap:14px;padding:14px 32px;background:#FBFAF5;border-bottom:1px solid #E8E4DC;">
    <span style="font-size:18px;font-weight:800;letter-spacing:.16em;color:#00492C;padding-right:10px;border-right:1px solid #E8E4DC;">週間</span>
    <div style="display:flex;align-items:center;gap:14px;flex:1;padding:12px 18px;border-radius:2px;color:#fff;background:$(if($wTone -eq 'up'){'#1F7A4D'}elseif($wTone -eq 'down'){'#8B1A1A'}else{'#6b7670'});">
      <div style="font-size:18px;opacity:.85;font-weight:600;">VN-Index 週間</div>
      <div style="font-size:31px;font-weight:800;font-variant-numeric:tabular-nums;">$('{0:N2}' -f [double]$viLast.close)</div>
      <div style="font-size:20px;font-weight:700;">$(if($wTone -eq 'up'){'▲'}elseif($wTone -eq 'down'){'▼'}else{'―'}) $('{0:+0.00;-0.00;0.00}' -f $wIdxChg) ／ $(PctW $wIdxPct)</div>
    </div>
    <div style="font-size:13px;color:#666;text-align:right;min-width:200px;">ネット寄与 <b style="color:$(if($net -gt 0){'#1F7A4D'}elseif($net -lt 0){'#8B1A1A'}else{'#888'});font-size:18px;">$(Pt $net)</b><br><span style="font-size:11px;color:#999;">概算・単純時価総額ウェイト</span></div>
  </div>

  <!-- 今週のひとこと -->
  <div style="padding:22px 32px 8px;background:linear-gradient(180deg,#FFFFFF,#FBFAF5);">
    <div style="width:48px;height:2px;background:#B8922A;margin-bottom:11px;"></div>
    <div style="font-size:18px;font-weight:700;letter-spacing:.18em;color:#555;">今週のひとこと</div>
    <div style="font-size:36px;font-weight:900;color:$(if($wTone -eq 'up'){'#1F7A4D'}else{'#8B1A1A'});line-height:1.25;margin:7px 0 11px;">$(Esc $headline)</div>
    <div style="font-size:20px;line-height:1.9;color:#2A2A2A;font-weight:500;">
        $leadHtml
    </div>
  </div>

  <!-- 寄与度の綱引き（主役）-->
  <div style="padding:18px 32px 6px;">
    <div style="display:flex;align-items:center;gap:10px;margin-bottom:14px;">
      <span style="width:48px;height:2px;background:#B8922A;"></span>
      <span style="font-size:18px;font-weight:800;letter-spacing:.14em;color:#00492C;">寄与度の綱引き　<span style="font-weight:600;color:#777;font-size:13px;letter-spacing:0;">誰が今週の指数を動かしたか（概算）</span></span>
    </div>
    <div style="display:grid;grid-template-columns:150px 1fr 150px;align-items:center;gap:12px;margin-bottom:8px;">
      <div style="text-align:right;font-size:13px;color:#777;">押し下げ<br><b style="font-size:22px;color:#8B1A1A;">$(Pt $pushDown)</b></div>
      <div style="position:relative;height:30px;background:#EFEBE0;border-radius:3px;display:flex;justify-content:center;overflow:hidden;">
        <span style="position:absolute;left:50%;top:0;bottom:0;width:2px;background:#9C9482;z-index:2;"></span>
        <span style="position:absolute;top:0;bottom:0;right:50%;width:$wPd%;background:linear-gradient(90deg,#8B1A1A,#c0504d);"></span>
        <span style="position:absolute;top:0;bottom:0;left:50%;width:$wPu%;background:linear-gradient(90deg,#1F7A4D,#3DA46A);"></span>
      </div>
      <div style="text-align:left;font-size:13px;color:#777;">押し上げ<br><b style="font-size:22px;color:#1F7A4D;">$(Pt $pushUp)</b></div>
    </div>
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:18px;margin-top:14px;">
      <div><div style="font-size:13px;font-weight:800;color:#8B1A1A;margin-bottom:4px;">押し下げた銘柄</div><ul style="list-style:none;margin:0;padding:0;">$downListH</ul></div>
      <div><div style="font-size:13px;font-weight:800;color:#1F7A4D;margin-bottom:4px;">押し上げた銘柄</div><ul style="list-style:none;margin:0;padding:0;">$upListH</ul></div>
    </div>
  </div>

  <!-- セクター別 週間寄与度（主役）-->
  <div style="padding:14px 32px 18px;background:#FBFAF5;border-top:1px solid #E8E4DC;border-bottom:1px solid #E8E4DC;margin-top:14px;">
    <div style="display:flex;align-items:center;gap:10px;margin-bottom:14px;">
      <span style="width:48px;height:2px;background:#B8922A;"></span>
      <span style="font-size:18px;font-weight:800;letter-spacing:.14em;color:#00492C;">セクター別 週間寄与度</span>
    </div>
$secHtml
  </div>

  <!-- 深掘り本文 -->
  <div style="padding:20px 32px 16px;">
    <div style="display:flex;align-items:center;gap:10px;margin-bottom:10px;">
      <span style="width:48px;height:2px;background:#B8922A;"></span>
      <span style="font-size:18px;font-weight:800;letter-spacing:.14em;color:#00492C;">今週の深掘り</span>
    </div>
    <p style="font-size:16px;line-height:1.95;color:#2A2A2A;margin:0;">$(Esc $deep)</p>
  </div>

  <!-- フッター -->
  <div style="display:flex;align-items:center;padding:14px 32px 18px;background:#FBFAF5;border-top:1px solid #E8E4DC;">
    <img src="{ASSET}/shishi3.png" alt="ししまる" style="height:90px;width:auto;flex-shrink:0;">
    <p style="font-size:13px;line-height:1.7;color:#777;margin:0;flex:1;text-align:center;">出典: VNDirect／寄与度は概算（単純時価総額ウェイト・正式VN30ウェイトとはズレる）／対象 $weekStart〜$weekEnd　投資判断は自己責任で</p>
    <div style="width:90px;flex-shrink:0;" aria-hidden="true"></div>
  </div>

</div></div></body></html>
"@

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
$docsFile = Join-Path $DocsDir 'weekly.html'
$outFile  = Join-Path $OutDir ("weekly_{0}.html" -f $weekEnd)
($html.Replace('{ASSET}', 'assets')) | Set-Content -Path $docsFile -Encoding UTF8
($html.Replace('{ASSET}', '../docs/assets')) | Set-Content -Path $outFile -Encoding UTF8

Write-Host ("[weekly/ししまるVN30分解新聞] 生成（対象 {0} 営業日: {1}〜{2}）" -f $files.Count, $weekStart, $weekEnd) -ForegroundColor Green
Write-Host ("  見出し: {0}" -f $headline) -ForegroundColor Cyan
Write-Host ("  綱引き: 押上 {0} / 押下 {1} / ネット {2}" -f (Pt $pushUp), (Pt $pushDown), (Pt $net)) -ForegroundColor DarkGray
Write-Host ("  Pages: {0}" -f $docsFile)
$outFile
