<#
  email_png.ps1 ― メール全体（警告ボックス〜新聞〜免責）を縦1枚のPNGに書き出す
  --------------------------------------------------------------------------
  docs/email.html を Edge で撮影し、下の白余白を自動トリムして
  outputs/email_<pub>.full.png に保存する。
  コピペでリンク・体裁が崩れるのを避け、画像1枚で貼れるようにするためのもの。
  使い方:  pwsh -File scripts\email_png.ps1
  依存:    Edge(Windows) + System.Drawing。※GitHub Actions(Linux)では別途ImageMagick等が必要。
#>
param(
  [string]$HtmlPath = (Join-Path $PSScriptRoot "..\docs\email.html"),
  [string]$OutPath  = $null
)
$ErrorActionPreference = 'Stop'
if (-not $OutPath) {
  # 件名txtの発行日を拾えれば使う。なければ今日。
  $subj = Get-ChildItem (Join-Path $PSScriptRoot "..\outputs") -Filter "email_*.subject.txt" -ErrorAction SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
  $tag  = if ($subj) { ($subj.BaseName -replace '^email_','' -replace '\.subject$','') } else { (Get-Date).ToString('yyyy-MM-dd') }
  $OutPath = Join-Path $PSScriptRoot ("..\outputs\email_{0}.full.png" -f $tag)
}
$edge = @(
  "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
  "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $edge) { throw "Edgeが見つかりません。" }

$raw = Join-Path $env:TEMP ("email_full_raw_{0}.png" -f (Get-Random))
$uri = "file:///" + ((Resolve-Path $HtmlPath).Path -replace '\\','/')
$ud  = Join-Path $env:TEMP ("vn30_edge_{0}" -f (Get-Random))
& $edge "--headless=new" "--disable-gpu" "--no-sandbox" "--user-data-dir=$ud" "--hide-scrollbars" "--force-device-scale-factor=2" "--window-size=720,3200" "--screenshot=$raw" $uri 2>$null | Out-Null
Start-Sleep -Milliseconds 700
if (-not (Test-Path $raw)) { throw "撮影に失敗しました。" }

Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap($raw)
$w = $bmp.Width; $h = $bmp.Height
$rect = New-Object System.Drawing.Rectangle(0,0,$w,$h)
$d = $bmp.LockBits($rect,[System.Drawing.Imaging.ImageLockMode]::ReadOnly,[System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$stride = $d.Stride
$bytes = New-Object byte[] ($stride*$h)
[System.Runtime.InteropServices.Marshal]::Copy($d.Scan0,$bytes,0,$bytes.Length)
$bmp.UnlockBits($d)
$lastContent = 0
for ($y=$h-1; $y -ge 0; $y--) {
  $rowOff = $y*$stride; $nonwhite = $false
  for ($x=0; $x -lt $w; $x+=4) {
    $o = $rowOff + $x*4
    if ($bytes[$o] -lt 244 -or $bytes[$o+1] -lt 244 -or $bytes[$o+2] -lt 244) { $nonwhite=$true; break }
  }
  if ($nonwhite) { $lastContent=$y; break }
}
$cropH = [Math]::Min($h, $lastContent + 40)
$crop = New-Object System.Drawing.Bitmap($w,$cropH)
$g = [System.Drawing.Graphics]::FromImage($crop)
$g.DrawImage($bmp, (New-Object System.Drawing.Rectangle(0,0,$w,$cropH)), (New-Object System.Drawing.Rectangle(0,0,$w,$cropH)), [System.Drawing.GraphicsUnit]::Pixel)
$crop.Save($OutPath,[System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $crop.Dispose(); $bmp.Dispose()
Remove-Item $raw -ErrorAction SilentlyContinue
Write-Host ("メール全体PNG: {0}  ({1}x{2}px)" -f $OutPath,$w,$cropH)
