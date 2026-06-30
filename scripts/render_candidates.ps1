<#
  render_candidates.ps1  ―  カード候補を「朝サッと選べる一覧」HTMLにする
  --------------------------------------------------------------------
  outputs/vn30_<asof>.candidates.json を docs/candidates.html に整形。
  弓場さんはこれを開いて、載せたい番号を5本前後選ぶ（順番も）→ select_cards.ps1 へ。
  依存: なし（PowerShell 7 標準）
#>
[CmdletBinding()]
param([string]$InputPath, [string]$OutDir = (Join-Path $PSScriptRoot "..\outputs"), [string]$DocsDir = (Join-Path $PSScriptRoot "..\docs"))
$ErrorActionPreference = 'Stop'
if (-not $InputPath) { $InputPath = Get-ChildItem $OutDir -Filter "vn30_*.candidates.json" | Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName }
$c = Get-Content $InputPath -Raw -Encoding UTF8 | ConvertFrom-Json
function Esc([string]$s) { if ($null -eq $s) { return "" } $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;') }
function Mk([string]$t) { $s = Esc $t; $s = [regex]::Replace($s,'\*\*(.+?)\*\*','<b style="color:#8B1A1A;">$1</b>'); $s = [regex]::Replace($s,'\[\[(.+?)\]\]','<b style="color:#1F7A4D;">$1</b>'); $s }
$accent = @{ green='#1F7A4D'; red='#8B1A1A'; gold='#B8922A'; teal='#013820' }
$kindBg = @{ 'マクロ'='#B8922A'; 'ミクロ'='#00492C' }

$rows = ($c.candidates | ForEach-Object {
  $ac = $accent[[string]$_.color]; if (-not $ac) { $ac='#00492C' }
  $kb = $kindBg[[string]$_.kind]; if (-not $kb) { $kb='#777' }
  $len = ($_.text -replace '\*\*|\[\[|\]\]','').Length
  @"
    <div style="display:flex;gap:14px;align-items:flex-start;background:#fff;border:1px solid #E8E4DC;border-left:5px solid $ac;border-radius:4px;padding:12px 14px;margin-bottom:9px;">
      <div style="flex-shrink:0;width:40px;height:40px;border-radius:50%;background:#00492C;color:#fff;display:flex;align-items:center;justify-content:center;font-size:20px;font-weight:900;">$($_.id)</div>
      <div style="flex:1;">
        <div style="margin-bottom:3px;"><span style="font-size:11px;font-weight:800;color:#fff;background:$kb;border-radius:3px;padding:2px 8px;">$($_.kind)</span> <b style="font-size:15px;color:$ac;">$(Esc $_.tag)</b> <span style="font-size:11px;color:#aaa;">($len字)</span></div>
        <div style="font-size:14px;line-height:1.7;color:#2A2A2A;">$(Mk $_.text)</div>
      </div>
    </div>
"@
}) -join "`n"

$html = @"
<!DOCTYPE html><html lang="ja"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>カード候補 ― $($c.as_of)</title>
<style>body{margin:0;background:#ECE8DE;font-family:'Hiragino Sans','Yu Gothic',Meiryo,sans-serif;color:#1A1A1A;}</style></head>
<body><div style="max-width:760px;margin:20px auto;background:#FBFAF5;border-radius:8px;padding:22px 26px;box-shadow:0 8px 30px rgba(0,73,44,.12);">
  <div style="font-size:12px;font-weight:700;letter-spacing:.2em;color:#B8922A;">CARD CANDIDATES</div>
  <div style="font-size:24px;font-weight:900;color:#00492C;margin:2px 0 4px;">きょうのカード候補（$($c.as_of) 基準）</div>
  <div style="font-size:13px;color:#666;margin-bottom:6px;">載せたい <b>5本前後</b> を番号で選んでください（順番も指定可）。今日のひとこと案：<b style="color:#8B1A1A;">「$(Esc $c.headline)」</b></div>
  <div style="font-size:12px;color:#888;background:#fff;border:1px dashed #C9C2B2;border-radius:4px;padding:7px 11px;margin-bottom:14px;">
    選び方の例 → Claudeに「<b>2,3,4,6,1 で確定</b>」と言う（その順で掲載）／ or <code>select_cards.ps1 -Pick "2,3,4,6,1"</code>
  </div>
$rows
</div></body></html>
"@
if (-not (Test-Path $DocsDir)) { New-Item -ItemType Directory -Path $DocsDir -Force | Out-Null }
$out = Join-Path $DocsDir 'candidates.html'
$html | Set-Content -Path $out -Encoding UTF8
Write-Host ("[render_candidates] 候補 {0}本 → {1}" -f $c.candidates.Count, $out) -ForegroundColor Green
Write-Host "  公開: https://yumiba924-a11y.github.io/shishimaru-vn-news/candidates.html"
$out
