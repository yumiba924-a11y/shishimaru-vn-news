<#
  run_daily.ps1  ―  VN30 図解新聞 / 運用ランナー（Step 5 / リリース版）
  --------------------------------------------------------------------
  毎営業日これ1本。 取得[1][2] → 解釈[3] → 図解[4] → 静止版書き出し(PNG/PDF)。
    pwsh -File scripts\run_daily.ps1            # 生成して結果表示
    pwsh -File scripts\run_daily.ps1 -Open       # 生成後ブラウザで開く
    pwsh -File scripts\run_daily.ps1 -Log        # logs\ に実行ログを残す（スケジュール用）

  各段は独立スクリプト。どこで壊れたか切り分けられるよう段ごとに進捗を出す。
  PNG/PDF はEdgeヘッドレスで出力。Edgeが無くても新聞HTMLは出るので止めない。
#>
[CmdletBinding()]
param([switch]$Open, [switch]$Log)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$root = Split-Path $here -Parent

if ($Log) {
  $logDir = Join-Path $root 'logs'; if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
  $logFile = Join-Path $logDir ("run_{0}.log" -f (Get-Date).ToString('yyyyMMdd_HHmmss'))
  Start-Transcript -Path $logFile -Append | Out-Null
}

try {
  Write-Host "===== VN30 図解新聞 日次ビルド ($(Get-Date -Format 'yyyy-MM-dd HH:mm')) =====" -ForegroundColor Cyan

  Write-Host "`n[1/4] 取得・整形 (fetch_vn30.ps1)" -ForegroundColor Yellow
  & (Join-Path $here 'fetch_vn30.ps1')

  Write-Host "`n[2/4] 解釈・今日の一言 (interpret.ps1)" -ForegroundColor Yellow
  & (Join-Path $here 'interpret.ps1')

  Write-Host "`n[3/4] 図解HTML生成 (render_zukai.ps1)" -ForegroundColor Yellow
  $htmlPath = & (Join-Path $here 'render_zukai.ps1') | Select-Object -Last 1

  Write-Host "`n[4/4] 静止版 書き出し (PNG / PDF)" -ForegroundColor Yellow
  $png = [IO.Path]::ChangeExtension($htmlPath, '.png')
  $pdf = [IO.Path]::ChangeExtension($htmlPath, '.pdf')
  $edge = @(
    "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
  ) | Where-Object { Test-Path $_ } | Select-Object -First 1
  if ($edge) {
    $uri = "file:///" + ($htmlPath -replace '\\', '/')
    $ud  = Join-Path $env:TEMP 'vn30_edge_profile'
    $common = @("--headless=new","--disable-gpu","--no-sandbox","--user-data-dir=$ud","--hide-scrollbars","--force-device-scale-factor=2","--virtual-time-budget=3000")
    try {
      & $edge @common "--window-size=1000,1520" "--screenshot=$png" $uri 2>$null | Out-Null
      & $edge @common "--no-pdf-header-footer" "--print-to-pdf=$pdf" $uri 2>$null | Out-Null
      $okPng = Test-Path $png; $okPdf = Test-Path $pdf
      Write-Host ("  PNG: {0}  /  PDF: {1}" -f $(if ($okPng) { 'OK' } else { '失敗' }), $(if ($okPdf) { 'OK' } else { '失敗' }))
    } catch { Write-Warning "  画像/PDF書き出しでエラー（HTMLは生成済みなので継続）: $($_.Exception.Message)" }
  } else {
    Write-Warning "  Edgeが見つからずPNG/PDFはスキップ（HTMLは生成済み）。"
  }

  Write-Host "`n===== 完了 =====" -ForegroundColor Green
  Write-Host "図解HTML: $htmlPath"
  if (Test-Path $png) { Write-Host "  PNG : $png" }
  if (Test-Path $pdf) { Write-Host "  PDF : $pdf" }
  Write-Host "目視チェック → OKなら完了（半自動／弓場さんの判断を1回通す）。" -ForegroundColor DarkGray

  if ($Open -and $htmlPath -and (Test-Path $htmlPath)) { Invoke-Item $htmlPath }
}
finally {
  if ($Log) { Stop-Transcript | Out-Null }
}
