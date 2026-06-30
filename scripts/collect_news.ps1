<#
  collect_news.ps1  ―  ニュース収集＋無料翻訳＋日本語の要点リスト化（APIキー不要・無料）
  --------------------------------------------------------------------
  前営業日〜当日朝刊の記事を各ソースから取得し、無料の翻訳（キー不要のGoogle gtx）で
  日本語に変換、見出し/要点を [マクロ]/[ミクロ] タグ付きの箇条書きにして news_raw に並べる。
  これが「人が読む日本語の下書き」。弓場さん/Claude はこの要点から4-5本を選びカード化する。

  ※Claude API は使わない。コストゼロ。翻訳が落ちても収集の原文は残す（縮退）。
  出力: outputs/vn30_<asof>.news_raw.txt（日本語の要点リスト・ソースURL付き）
  依存: なし（PowerShell 7 標準）
#>
[CmdletBinding()]
param([string]$AsOf, [string]$OutDir = (Join-Path $PSScriptRoot "..\outputs"), [int]$LinesPerSource = 10)
$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
$UA = @{ "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36" }

if (-not $AsOf) {
  $f = Get-ChildItem $OutDir -Filter "vn30_*.interpreted.json" -EA SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
  if ($f) { $AsOf = ($f.BaseName -replace 'vn30_','' -replace '\.interpreted','') }
}

function Html2Text([string]$html) {
  if (-not $html) { return "" }
  $t = $html
  $t = [regex]::Replace($t, '(?is)<script.*?</script>', ' ')
  $t = [regex]::Replace($t, '(?is)<style.*?</style>', ' ')
  $t = [regex]::Replace($t, '(?is)<!--.*?-->', ' ')
  $t = [regex]::Replace($t, '(?is)</(p|div|li|h[1-6]|tr|br|a)>', "`n")
  $t = [regex]::Replace($t, '(?s)<[^>]+>', ' ')
  $t = [System.Net.WebUtility]::HtmlDecode($t)
  $t = [regex]::Replace($t, '[ \t]+', ' ')
  $t = [regex]::Replace($t, '(\s*\n\s*){2,}', "`n")
  return $t.Trim()
}

# 無料・キー不要の翻訳（Google gtx）。失敗時は空。
function Translate-Ja([string]$text) {
  if ([string]::IsNullOrWhiteSpace($text)) { return "" }
  if ($text.Length -gt 1800) { $text = $text.Substring(0, 1800) }
  for ($i = 0; $i -lt 2; $i++) {
    try {
      $enc = [uri]::EscapeDataString($text)
      $r = Invoke-RestMethod "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=ja&dt=t&q=$enc" -Headers $UA -TimeoutSec 25
      return (($r[0] | ForEach-Object { $_[0] }) -join '')
    } catch { Start-Sleep -Milliseconds 600 }
  }
  return ""
}

# 日本語の文をマクロ/ミクロに簡易タグ付け
$tickerRe = '\b(ACB|BCM|BID|CTG|DGC|FPT|GAS|GVR|HDB|HPG|MBB|MSN|MWG|PLX|POW|SAB|SHB|SSB|SSI|STB|TCB|TPB|VCB|VHM|VIB|VIC|VJC|VNM|VPB|VRE|PVD|PVS|LPB)\b'
function TagOf([string]$ja, [string]$src) {
  $macro = '金利|政策|中央銀行|国立銀行|ドン|為替|インフレ|物価|外国人|売り越し|買い越し|純|FTSE|格上げ|GDP|ETF|信用取引|マージン|margin|規制|債券|利回り|金（|原油'
  $micro = '銀行|証券|不動産|鉄鋼|株|セクター|決算|配当|権利落ち|急騰|急落'
  if ($ja -match $macro) { return 'マクロ' }
  if ($ja -match $tickerRe -or $src -match $tickerRe -or $ja -match $micro) { return 'ミクロ' }
  return 'その他'
}

$sources = @(
  @{ name = 'VnExpress International'; url = 'https://e.vnexpress.net/news/business' }
  @{ name = 'CafeF（証券）';            url = 'https://cafef.vn/thi-truong-chung-khoan.chn' }
  @{ name = 'The Investor';            url = 'https://theinvestor.vn/markets/' }
  @{ name = 'Vietstock English';       url = 'https://en.vietstock.vn/' }
)
$keyRe = 'VN-?Index|VN30|HOSE|HNX|ngân hàng|bank|Vingroup|VIC|VHM|cổ phiếu|khối ngoại|foreign|ròng|net|tỷ đồng|trillion|billion|tăng|giảm|%|điểm|point|GDP|lãi suất|rate|FTSE|tỷ giá|margin|ETF|stock|share|securities|chứng khoán'

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("# ししまるベトナム新聞 ― ニュース要点（日本語・自動翻訳の下書き）")
[void]$sb.AppendLine("# 基準日 $AsOf  取得 $((Get-Date).ToString('s'))  ※無料翻訳(Google)・粗訳。カード化の際に数値はinterpreted.jsonの正値を使う。")
$total = 0
foreach ($s in $sources) {
  try {
    $resp = Invoke-WebRequest -Uri $s.url -Headers $UA -TimeoutSec 30 -MaximumRedirection 3
    $txt = Html2Text $resp.Content
    # 見出し的な行を抽出（市場語を含む・適度な長さ・重複排除）
    $lines = $txt -split "`n" | ForEach-Object { $_.Trim() } |
      Where-Object { $_.Length -ge 16 -and $_.Length -le 160 -and $_ -match $keyRe } |
      Select-Object -Unique | Select-Object -First $LinesPerSource
    if (-not $lines) { continue }
    [void]$sb.AppendLine("`n## $($s.name)  （出典: $($s.url) ）")
    foreach ($ln in $lines) {
      $ja = Translate-Ja $ln
      if (-not $ja) { $ja = $ln }              # 翻訳失敗時は原文
      $tag = TagOf $ja $ln
      [void]$sb.AppendLine("- [$tag] $ja")
      $total++
      Start-Sleep -Milliseconds 200             # gtxへの配慮
    }
    Write-Host ("  {0}: {1}件 翻訳" -f $s.name, $lines.Count) -ForegroundColor DarkGray
  } catch {
    Write-Host ("  取得失敗: {0} ({1})" -f $s.name, $_.Exception.Message) -ForegroundColor DarkYellow
  }
}

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
$out = Join-Path $OutDir ("vn30_{0}.news_raw.txt" -f $AsOf)
$sb.ToString() | Set-Content -Path $out -Encoding UTF8
Write-Host ("[collect_news] 日本語要点 {0}件 → {1}" -f $total, $out) -ForegroundColor Green
$out
