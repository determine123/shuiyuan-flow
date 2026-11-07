param(
  [Parameter(Mandatory=$true)][string]$Adb,
  [Parameter(Mandatory=$true)][string]$Serial,
  [string]$Apk = "$PSScriptRoot\..\build\app\outputs\flutter-apk\app-debug.apk",
  [string]$Output = "$PSScriptRoot\..\artifacts\android"
)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $Output | Out-Null
function Invoke-Adb {
  param([string[]]$Arguments)
  $result = & $Adb -s $Serial @Arguments 2>&1
  if ($LASTEXITCODE -ne 0) { throw "adb failed: $result" }
  return $result
}
$state = Invoke-Adb -Arguments @('get-state')
if ($state -notcontains 'device') { throw "Device unavailable: $state" }
Get-FileHash -LiteralPath $Apk -Algorithm SHA256 | Format-List | Out-File "$Output\sha256.txt" -Encoding utf8
Invoke-Adb -Arguments @('shell','getprop') | Out-File "$Output\device-properties.txt" -Encoding utf8
Invoke-Adb -Arguments @('install','-r',$Apk) | Out-File "$Output\install.txt" -Encoding utf8
Invoke-Adb -Arguments @('logcat','-c') | Out-Null
Invoke-Adb -Arguments @('shell','am','force-stop','io.determine.shuiyuan_flow') | Out-Null
$launch = Invoke-Adb -Arguments @('shell','am','start','-W','-n','io.determine.shuiyuan_flow/.MainActivity')
$launch | Out-File "$Output\launch.txt" -Encoding utf8
if (($launch -join "`n") -notmatch 'Status: ok') { throw 'Activity launch did not report success' }
# 等待首帧与异步启动完成，再确认进程仍存活。
Start-Sleep -Seconds 8
$appPid = Invoke-Adb -Arguments @('shell','pidof','io.determine.shuiyuan_flow')
if (-not ($appPid -join '').Trim()) { throw 'Application process is not alive' }
$appPid | Out-File "$Output\pid.txt" -Encoding utf8
Invoke-Adb -Arguments @('shell','dumpsys','activity','activities') | Out-File "$Output\activities.txt" -Encoding utf8
Invoke-Adb -Arguments @('shell','screencap','-p','/sdcard/shuiyuan-startup.png') | Out-Null
Invoke-Adb -Arguments @('pull','/sdcard/shuiyuan-startup.png',"$Output\startup.png") | Out-Null
$logs = Invoke-Adb -Arguments @('logcat','-d','--pid',($appPid -join '').Trim())
$logs | Out-File "$Output\logcat.txt" -Encoding utf8
if (($logs -join "`n") -match 'FATAL EXCEPTION|Fatal signal|Unhandled Exception') { throw 'Fatal error found in startup log' }
Write-Output 'PASS: installed, launched, process alive; logs and screenshot saved.'

