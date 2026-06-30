<#
  summarize_news.ps1  ―  ニュース自動要約（Claude API）→ news.json
  --------------------------------------------------------------------
  data(interpreted.json)＋収集テキスト(news_raw.txt)＋前日news.json を Claude API に渡し、
  「今日のひとこと(15字＋3行)」と「ニュースカード4-5枚」を日本語で自動生成して news.json に書く。
  これで人手ゼロでカードまで埋まる。

  反復ヘッジ（毎日同じにしない）をプロンプトに内蔵:
    ・前日のカード見出しを渡し、同じ銘柄なら違う切り口（値動き/需給・外国人枠/ファンダ/フロー）に
    ・役割枠ローテ（主役セクター/外国人フロー/急変銘柄/マクロ1本/循環・需給）で必ず複数の切り口
    ・外国人フローは定点（毎日入れる）

  数値はdataを正とし、ニュースは背景づけに使う（原文転載不可・事実を自分の言葉で）。
  品質方針: 完璧より「毎日自動で埋まる」優先。

  必要: 環境変数 ANTHROPIC_API_KEY（GitHub Secret）。CLAUDE_MODEL で機種上書き可（既定 sonnet）。
  失敗時: news.json を上書きしない（render は雛形/前回値で継続）= 新聞は必ず出る。
#>
[CmdletBinding()]
param([string]$InputPath, [string]$OutDir = (Join-Path $PSScriptRoot "..\outputs"),
      [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config\vn30_universe.json"))
$ErrorActionPreference = 'Stop'

$apiKey = $env:ANTHROPIC_API_KEY
if (-not $apiKey) { Write-Warning "ANTHROPIC_API_KEY 未設定 → 要約スキップ（news.jsonは雛形のまま、新聞は出る）"; return }
$model = if ($env:CLAUDE_MODEL) { $env:CLAUDE_MODEL } else { 'claude-sonnet-4-6' }

if (-not $InputPath) {
  $InputPath = Get-ChildItem $OutDir -Filter "vn30_*.interpreted.json" | Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName
}
$p = Get-Content $InputPath -Raw -Encoding UTF8 | ConvertFrom-Json
$cfg = Get-Content $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$nameOf = @{}; foreach ($c in $cfg.constituents) { $nameOf[$c.code] = $c.name_ja }
$asof = [string]$p.as_of

# 収集テキスト
$rawFile = Join-Path $OutDir ("vn30_{0}.news_raw.txt" -f $asof)
$raw = if (Test-Path $rawFile) { Get-Content $rawFile -Raw -Encoding UTF8 } else { "(ニュース収集なし)" }

# 前日 news.json（反復ヘッジ用）
$prevNewsFile = Get-ChildItem $OutDir -Filter "vn30_*.news.json" -EA SilentlyContinue |
  Where-Object { ($_.BaseName -replace 'vn30_','' -replace '\.news','') -lt $asof } |
  Sort-Object Name -Descending | Select-Object -First 1
$prevCards = ""
if ($prevNewsFile) {
  try {
    $pn = Get-Content $prevNewsFile.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    $prevCards = ($pn.cards | ForEach-Object { "・$($_.tag): $($_.text)" }) -join "`n"
    $prevHead = $pn.headline
  } catch { }
}

# data要約（数値は正）
$f = '{0:+0.0;-0.0;0.0}'
$mvUp = ($p.stocks | Sort-Object pct -Descending | Select-Object -First 6 | ForEach-Object { "$($_.code)($($nameOf[$_.code])) $($f -f [double]$_.pct)%" }) -join '、'
$mvDn = ($p.stocks | Sort-Object pct | Select-Object -First 6 | ForEach-Object { "$($_.code)($($nameOf[$_.code])) $($f -f [double]$_.pct)%" }) -join '、'
$sec  = ($p.by_sector | ForEach-Object { "$($_.sector) 平均$($f -f [double]$_.avg_pct)%" }) -join '、'
$jump = ($p.stocks | Where-Object { [math]::Abs([double]$_.pct) -ge 3 } | ForEach-Object { "$($_.code) $($f -f [double]$_.pct)%" }) -join '、'
$brd = if ($p.hose_breadth) { "HOSE全体 上昇$($p.hose_breadth.up)/下落$($p.hose_breadth.down)/変わらず$($p.hose_breadth.flat)" } else { "VN30 上昇$($p.breadth.up)/下落$($p.breadth.down)/変わらず$($p.breadth.flat)" }
$dataBlock = @"
基準日(前営業日): $asof
VN-Index: 終値$($p.indices.VNINDEX.close)、前日比$($f -f [double]$p.indices.VNINDEX.pct)%
$brd
値上がり上位: $mvUp
値下がり上位: $mvDn
セクター平均騰落: $sec
±3%超の急変: $(if($jump){$jump}else{'なし'})
"@

$system = @"
あなたはベトナム株のデイリー新聞「ししまるベトナム新聞」の編集者。前営業日の市場を、データと現地報道から日本語で要約する。出力は厳密なJSONのみ。

【絶対ルール】
- 数値はdataブロックを正とする（VN-Index・騰落・個別株%）。ニュースは「なぜ＝背景」に使う。
- 原文転載は不可。事実を自分の言葉で日本語に。専門用語は平易に。
- 嘘・未確認の断定をしない。ニュースに無い因果は書かない（数値の描写に留める）。

【今日のひとこと】headline=全角15字以内の大見出し。lead=3行の配列、各行は短く、市場の要点。
【ニュースカード】4〜5枚。1枚 = tag(見出しラベル5〜10字) + color + icon + text。
- text: 全角40〜70字。「事実→数字→背景」の順。キーワードは **赤太字**、上昇/好材料は [[緑]]。
- color: green(好材料/上昇) red(悪材料/下落) gold(外国人・マクロ) teal(需給・循環)。
- icon: Bootstrap Icon名（bank, graph-down-arrow, graph-up-arrow, globe-asia-australia, arrow-repeat, cash-coin, building, currency-exchange 等から内容に合うもの）。
- マクロ（政策金利・ドン相場・外国人フロー・FTSE・GDP）とミクロ（個別株・セクター・急変）を必ず混ぜる。
- ±3%超の急変銘柄があればその理由カードを優先。

【反復ヘッジ（最重要）】毎日同じ見出し・同じ切り口にしない。
- 役割枠をローテーションし、必ず複数の異なる切り口を入れる: ①主役セクター ②外国人フロー(定点・毎日入れる) ③急変銘柄 ④マクロ1本 ⑤循環・需給 から4〜5個。
- 前日のカード(後述)と同じ銘柄を扱うなら、前日と違う角度にする（値動き→需給/外国人枠→ファンダ→フロー）。
- 前日と同じ見出しパターンを避ける。

【出力】次のJSONのみ（前後に文章やマークダウン記法を付けない）:
{"headline":"...","lead":["...","...","..."],"cards":[{"tag":"...","color":"green|red|gold|teal","icon":"...","text":"..."}]}
"@

$user = @"
# data（数値は正）
$dataBlock

# 前日のカード（反復回避のため・同じにしない）
前日見出し: $prevHead
$prevCards

# 収集したニュース素材（背景づけに使用・転載禁止）
$raw
"@

# --- Claude API 呼び出し -----------------------------------------------------
$body = @{
  model = $model; max_tokens = 1500
  system = $system
  messages = @(@{ role = 'user'; content = $user })
} | ConvertTo-Json -Depth 6
$headers = @{ 'x-api-key' = $apiKey; 'anthropic-version' = '2023-06-01'; 'content-type' = 'application/json' }

try {
  $resp = Invoke-RestMethod -Uri 'https://api.anthropic.com/v1/messages' -Method Post -Headers $headers -Body $body -TimeoutSec 90
  $text = ($resp.content | Where-Object { $_.type -eq 'text' } | Select-Object -First 1).text
  $text = [regex]::Replace($text, '(?s)^.*?(\{)', '$1')           # 前置き除去
  $text = [regex]::Replace($text, '(?s)(\}).*?$', '$1')           # 後置き除去
  $obj = $text | ConvertFrom-Json
  if (-not $obj.cards) { throw "cards が空" }
}
catch { Write-Warning "要約失敗（news.json据え置き・新聞は出る）: $($_.Exception.Message)"; return }

# --- news.json に書き込み（人が後から手直しも可）-----------------------------
$news = [ordered]@{
  _note = "自動要約(Claude $model)で生成。人の手直し可。color=green|red|gold|teal、icon=Bootstrap名、text内 **赤太字** [[緑]]。"
  generated_by = "auto:$model"; generated_at = (Get-Date).ToString('s')
  headline = $obj.headline
  lead = @($obj.lead)
  cards = @($obj.cards | ForEach-Object { [ordered]@{ tag = $_.tag; color = $_.color; icon = $_.icon; text = $_.text } })
}
$newsFile = Join-Path $OutDir ("vn30_{0}.news.json" -f $asof)
$news | ConvertTo-Json -Depth 6 | Set-Content -Path $newsFile -Encoding UTF8
Write-Host ("[summarize_news] 自動要約 {0}枚 → {1}" -f $news.cards.Count, $newsFile) -ForegroundColor Green
Write-Host ("  見出し: {0}" -f $obj.headline) -ForegroundColor Cyan
