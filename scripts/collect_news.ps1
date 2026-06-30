<#
  collect_news.ps1  ―  ニュース自動収集（要約の素材）
  --------------------------------------------------------------------
  前営業日のベトナム市場ニュースを複数ソースから取得し、HTMLから本文テキストを抽出して
  1つのバンドルにまとめる（要約APIに渡す素材）。マクロ＋ミクロの両方を拾えるよう、
  市場概況・個別・外国人フロー系のページを横断する。

  出力: outputs/vn30_<asof>.news_raw.txt（ソース見出し付きの素テキスト・上限あり）
  方針: per-source 縮退（1つ落ちても続行）。本文抽出は荒くてOK（要約側で判断）。
  依存: なし（PowerShell 7 標準）
#>
[CmdletBinding()]
param([string]$AsOf, [string]$OutDir = (Join-Path $PSScriptRoot "..\outputs"), [int]$MaxChars = 18000)
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$UA = @{ "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36" }

if (-not $AsOf) {
  $f = Get-ChildItem $OutDir -Filter "vn30_*.interpreted.json" -EA SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
  if ($f) { $AsOf = ($f.BaseName -replace 'vn30_','' -replace '\.interpreted','') }
}

# HTML→プレーンテキスト（script/style除去・タグ除去・実体参照・空白圧縮）
function Html2Text([string]$html) {
  if (-not $html) { return "" }
  $t = $html
  $t = [regex]::Replace($t, '(?is)<script.*?</script>', ' ')
  $t = [regex]::Replace($t, '(?is)<style.*?</style>', ' ')
  $t = [regex]::Replace($t, '(?is)<!--.*?-->', ' ')
  $t = [regex]::Replace($t, '(?is)</(p|div|li|h[1-6]|tr|br)>', "`n")
  $t = [regex]::Replace($t, '(?s)<[^>]+>', ' ')
  $t = [System.Net.WebUtility]::HtmlDecode($t)
  $t = [regex]::Replace($t, '[ \t]+', ' ')
  $t = [regex]::Replace($t, '(\s*\n\s*){2,}', "`n")
  return $t.Trim()
}

$sources = @(
  @{ name = 'VnExpress International (business)'; url = 'https://e.vnexpress.net/news/business' }
  @{ name = 'CafeF 市場（証券）';                  url = 'https://cafef.vn/thi-truong-chung-khoan.chn' }
  @{ name = 'The Investor (markets)';             url = 'https://theinvestor.vn/markets/' }
  @{ name = 'Vietstock English';                  url = 'https://en.vietstock.vn/' }
)

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("# ベトナム市場ニュース素材  基準日 $AsOf  取得 $((Get-Date).ToString('s'))")
foreach ($s in $sources) {
  try {
    $resp = Invoke-WebRequest -Uri $s.url -Headers $UA -TimeoutSec 30 -MaximumRedirection 3
    $txt = Html2Text $resp.Content
    # 各ソース上限（ノイズ抑制）。市場語を含む行を優先的に残す。
    $lines = $txt -split "`n" | Where-Object { $_.Trim().Length -ge 12 }
    $keyRe = 'VN-?Index|VN30|HOSE|HNX|ngân hàng|bank|Vingroup|VIC|VHM|cổ phiếu|khối ngoại|foreign|ròng|net|tỷ đồng|trillion|billion|tăng|giảm|%|điểm|point|GDP|lãi suất|rate|FTSE|tỷ giá'
    $pick = $lines | Where-Object { $_ -match $keyRe } | Select-Object -First 60
    if (-not $pick) { $pick = $lines | Select-Object -First 30 }
    $chunk = ($pick -join "`n")
    if ($chunk.Length -gt 5000) { $chunk = $chunk.Substring(0, 5000) }
    [void]$sb.AppendLine("`n===== SOURCE: $($s.name) =====")
    [void]$sb.AppendLine("URL: $($s.url)")
    [void]$sb.AppendLine($chunk)
    Write-Host ("  取得OK: {0}  ({1}字)" -f $s.name, $chunk.Length) -ForegroundColor DarkGray
  } catch {
    Write-Host ("  取得失敗: {0}  ({1})" -f $s.name, $_.Exception.Message) -ForegroundColor DarkYellow
  }
}
$bundle = $sb.ToString()
if ($bundle.Length -gt $MaxChars) { $bundle = $bundle.Substring(0, $MaxChars) }

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
$out = Join-Path $OutDir ("vn30_{0}.news_raw.txt" -f $AsOf)
$bundle | Set-Content -Path $out -Encoding UTF8
Write-Host ("[collect_news] {0}字 → {1}" -f $bundle.Length, $out) -ForegroundColor Green
$out
