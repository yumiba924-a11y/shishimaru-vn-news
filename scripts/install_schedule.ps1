<#
  install_schedule.ps1  ―  毎営業日の自動実行を登録（Step 5 / 運用化）
  --------------------------------------------------------------------
  Windowsタスクスケジューラに「平日 18:00(JST)」のタスクを登録する。
    ・18:00 JST = ベトナム16:00（引け15:00の後）。確定値が取れる時間帯。
    ・PCが落ちていて実行できなかった場合は、次回起動時に追いかけ実行（StartWhenAvailable）。
    ・run_daily.ps1 -Log で logs\ に実行記録を残す（無人運用の事後確認用）。
  解除は uninstall_schedule.ps1。管理者権限は不要（現在ユーザーのタスクとして登録）。
#>
$ErrorActionPreference = 'Stop'
$root   = Split-Path $PSScriptRoot -Parent
$script = Join-Path $PSScriptRoot 'run_daily.ps1'
$pwsh   = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwsh) { $pwsh = (Get-Command powershell).Source }
$taskName = 'VN30_ZukaiShimbun'

$action  = New-ScheduledTaskAction -Execute $pwsh -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$script`" -Log" -WorkingDirectory $root
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday -At 6:00PM
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 15) -MultipleInstances IgnoreNew

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings `
  -Description 'VN30 図解新聞を平日18:00(JST)に自動生成（取得→解釈→図解→PNG/PDF）。半自動：生成物は目視1回で確定。' -Force | Out-Null

$t = Get-ScheduledTask -TaskName $taskName
Write-Host "登録完了: $taskName" -ForegroundColor Green
Write-Host ("  トリガー: 平日 18:00 / 状態: {0}" -f $t.State)
Write-Host ("  実行: {0} -NoProfile -ExecutionPolicy Bypass -File `"{1}`" -Log" -f $pwsh, $script)
Write-Host "  ※PCが起動している必要あり。落ちていた場合は次回起動時に追いかけ実行。"
Write-Host "  解除: pwsh -File scripts\uninstall_schedule.ps1"
