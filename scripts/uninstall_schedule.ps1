<#
  uninstall_schedule.ps1  ―  自動実行タスクの解除
#>
$ErrorActionPreference = 'Stop'
$taskName = 'VN30_ZukaiShimbun'
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
  Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
  Write-Host "解除しました: $taskName" -ForegroundColor Green
} else {
  Write-Host "タスクは登録されていません: $taskName" -ForegroundColor DarkGray
}
