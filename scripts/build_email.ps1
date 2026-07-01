<#
  build_email.ps1  ―  朝刊メール文面の自動生成（手動配信用）
  --------------------------------------------------------------------
  生成済みの新聞PNGを「インライン埋め込み」したメールHTMLを作る。
  弓場さんは outputs/email_<発行日>.html をブラウザで開き、全選択コピー→メール作成画面に貼付
  （画像も一緒に貼り付く）→ 件名をコピー → 9:00に手動送信、で配れる。

  位置づけ: 「前営業日のベトナム相場をお届けする朝刊」。ししまるの親しみ＋社内向けの品位。
  入力: interpreted.json（日付・見出し）／news.json（要約一文）／PNG（新聞画像）／distribution.json（配信先・URL・免責）
  出力: outputs/email_<発行日>.html
  将来: Actionsからの自動送信に拡張しやすい構造（本文生成と送信を分離）。
  依存: なし（PowerShell 7 標準）
#>
[CmdletBinding()]
param([string]$InputPath, [string]$OutDir = (Join-Path $PSScriptRoot "..\outputs"),
      [string]$DocsDir = (Join-Path $PSScriptRoot "..\docs"),
      [string]$DistPath = (Join-Path $PSScriptRoot "..\config\distribution.json"))
$ErrorActionPreference = 'Stop'

if (-not $InputPath) {
  $InputPath = Get-ChildItem $OutDir -Filter "vn30_*.interpreted.json" | Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
}
$p = Get-Content $InputPath -Raw -Encoding UTF8 | ConvertFrom-Json
$dist = Get-Content $DistPath -Raw -Encoding UTF8 | ConvertFrom-Json
$asof = [string]$p.as_of

# news.json（見出し・要約一文）
$news = $null
$nf = Join-Path $OutDir ("vn30_{0}.news.json" -f $asof)
if (Test-Path $nf) { try { $news = Get-Content $nf -Raw -Encoding UTF8 | ConvertFrom-Json } catch { } }
$headline = if ($news -and $news.headline) { $news.headline } else { $p.interpretation.headline }
$lead1 = if ($news -and @($news.lead).Count) { @($news.lead)[0] } else { '' }

# 日付（発行日=翌営業日 / 相場日=asof）
$dt = [datetime]::ParseExact($asof, 'yyyy-MM-dd', $null)
$wd = @('日','月','火','水','木','金','土')
$pub = $dt.AddDays(1); while ($pub.DayOfWeek -in 'Saturday','Sunday') { $pub = $pub.AddDays(1) }
$pubLabel = "{0}月{1}日（{2}）" -f $pub.Month, $pub.Day, $wd[[int]$pub.DayOfWeek]
$asofLabel = "{0}月{1}日（{2}）" -f $dt.Month, $dt.Day, $wd[[int]$dt.DayOfWeek]

# 配信先（active）
$groups = @($dist.phases | Where-Object { $_.active } | ForEach-Object { $_.groups.label }) -join '・'

# 新聞PNGを base64 で埋め込み（インライン表示）
$png = Join-Path $OutDir ("vn30_{0}.png" -f $asof)
$imgTag = if (Test-Path $png) {
  $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($png))
  "<img src=`"data:image/png;base64,$b64`" alt=`"ししまるベトナム新聞 $asofLabel`" style=`"width:100%;max-width:640px;height:auto;border:1px solid #E0DACB;border-radius:4px;display:block;`">"
} else { '<div style="color:#b00;">※新聞PNGが未生成です（run_daily / Actionsで生成してください）。</div>' }

$subject = "【ししまるベトナム新聞】$pubLabel 朝刊 ― $headline"

$body = @"
<!DOCTYPE html><html lang="ja"><head><meta charset="utf-8"></head>
<body style="margin:0;background:#fff;">
<div style="max-width:680px;margin:0 auto;padding:18px 20px;font-family:'Hiragino Sans','Yu Gothic',Meiryo,sans-serif;color:#1A1A1A;line-height:1.8;font-size:15px;">

  <div style="background:#FBFAF5;border:1px dashed #C9C2B2;border-radius:4px;padding:8px 12px;font-size:12px;color:#777;margin-bottom:16px;">
    ▼ 件名（コピーして貼り付け）<br><b style="color:#00492C;font-size:13px;">$subject</b>
  </div>

  <p>みなさま、おはようございます。🦁</p>
  <p>前営業日（$asofLabel）のベトナム相場をお届けする朝刊、<b style="color:#00492C;">ししまるベトナム新聞</b>です。<br>
  本日の見出しは <b style="color:#8B1A1A;">「$headline」</b>。$lead1。</p>

  <div style="background:#FFF7E6;border:1px solid #E0A800;border-left:5px solid #E0A800;border-radius:4px;padding:12px 14px;font-size:13px;color:#7A5C00;line-height:1.75;margin:16px 0;">
    <b style="color:#B36B00;font-size:14px;">⚠️ ご注意 ― 試作品（プロトタイプ）・社内限定</b><br>
    本紙は <b>Claude（生成AI）が自動作成している試みの段階の試作品</b>です。無料データと機械翻訳をもとにした気軽な試験運用のため、<b>数値・銘柄名・固有名詞などに誤り（誤情報）を含む可能性</b>があります。ご参考程度にご覧ください。<br>
    また試験運用につき、<b>予告なく内容の変更・配信の停止・そのまま終了</b>となる場合があります。<br>
    <b style="color:#B00020;">本紙は社内・グループ内限定です。顧客・社外の方への転送／配布は固くお断りします。</b> 投資勧誘・投資助言ではなく、投資判断はご自身の責任でお願いいたします。
  </div>

  <p style="margin:18px 0;">$imgTag</p>

  <p style="font-size:14px;">
    ▼ ライブ版（最新・拡大してご覧いただけます）<br>
    ・日次 ししまるベトナム新聞：<a href="$($dist.urls.daily)" style="color:#00492C;">$($dist.urls.daily)</a><br>
    ・週次 ししまるVN30分解新聞：<a href="$($dist.urls.weekly)" style="color:#00492C;">$($dist.urls.weekly)</a>
  </p>

  <p style="font-size:14px;">今週も良い一週間になりますように。引き続きよろしくお願いいたします。<br>
  ── ししまる（CQC）</p>

  <hr style="border:none;border-top:1px solid #E8E4DC;margin:18px 0;">
  <p style="font-size:11px;color:#999;line-height:1.7;">$($dist.disclaimer)</p>
</div>
</body></html>
"@

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
$out = Join-Path $OutDir ("email_{0}.html" -f $pub.ToString('yyyy-MM-dd'))   # 日付別アーカイブ
$docsOut = Join-Path $DocsDir 'email.html'                                    # Pages公開（最新・弓場さんが毎朝開く）
$body | Set-Content -Path $out -Encoding UTF8
$body | Set-Content -Path $docsOut -Encoding UTF8
Set-Content -Path (Join-Path $OutDir ("email_{0}.subject.txt" -f $pub.ToString('yyyy-MM-dd'))) -Value $subject -Encoding UTF8

Write-Host ("[build_email] メール文面を生成") -ForegroundColor Green
Write-Host ("  件名: {0}" -f $subject) -ForegroundColor Cyan
Write-Host ("  配信先: {0}" -f $groups)
Write-Host ("  Pages: {0}  （弓場さんが毎朝開く: .../email.html）" -f $docsOut)
$out
