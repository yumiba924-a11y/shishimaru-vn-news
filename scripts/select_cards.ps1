<#
  select_cards.ps1  ―  候補から選んだカードで news.json を確定
  --------------------------------------------------------------------
  例: ./scripts/select_cards.ps1 -Pick "2,3,4,6,1"   # その順で掲載
      -Headline "…" / -Render を付けると見出し上書き / そのまま新聞生成まで
  依存: なし（PowerShell 7 標準）
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Pick,    # "2,3,4,6,1"
  [string]$AsOf,
  [string]$Headline,
  [switch]$Render,
  [string]$OutDir = (Join-Path $PSScriptRoot "..\outputs")
)
$ErrorActionPreference = 'Stop'
if (-not $AsOf) {
  $cf = Get-ChildItem $OutDir -Filter "vn30_*.candidates.json" | Sort-Object Name -Descending | Select-Object -First 1
  $AsOf = ($cf.BaseName -replace 'vn30_','' -replace '\.candidates','')
}
$candFile = Join-Path $OutDir ("vn30_{0}.candidates.json" -f $AsOf)
$c = Get-Content $candFile -Raw -Encoding UTF8 | ConvertFrom-Json
$byId = @{}; foreach ($x in $c.candidates) { $byId[[int]$x.id] = $x }

$ids = $Pick -split '[,\s]+' | Where-Object { $_ } | ForEach-Object { [int]$_ }
$cards = @()
foreach ($id in $ids) {
  if (-not $byId.ContainsKey($id)) { Write-Warning "id $id は候補に無い（スキップ）"; continue }
  $x = $byId[$id]
  $cards += [ordered]@{ tag = $x.tag; color = $x.color; icon = $x.icon; text = $x.text }
}
if ($cards.Count -eq 0) { throw "選択が空。-Pick に候補idを指定してください。" }

$news = [ordered]@{
  _note = "候補から選定して確定（select_cards.ps1）。元: candidates.json。"
  generated_by = "selected: pick=$Pick"
  headline = if ($Headline) { $Headline } else { $c.headline }
  lead = @($c.lead)
  cards = @($cards)
}
$newsFile = Join-Path $OutDir ("vn30_{0}.news.json" -f $AsOf)
$news | ConvertTo-Json -Depth 6 | Set-Content -Path $newsFile -Encoding UTF8
Write-Host ("[select_cards] {0}本を確定（順: {1}）→ {2}" -f $cards.Count, ($ids -join ','), $newsFile) -ForegroundColor Green
$cards | ForEach-Object { Write-Host ("   ・{0}" -f $_.tag) }

if ($Render) {
  $interp = Join-Path $OutDir ("vn30_{0}.interpreted.json" -f $AsOf)
  & (Join-Path $PSScriptRoot 'render_zukai.ps1') -InputPath $interp | Out-Null
  Write-Host "  → 新聞を再生成しました（docs/index.html）" -ForegroundColor DarkGray
}
