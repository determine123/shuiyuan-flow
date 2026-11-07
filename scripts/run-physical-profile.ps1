param(
  [Parameter(Mandatory=$true)][string]$DeviceId,
  [string]$Adb = 'adb',
  [string]$Flutter = 'flutter',
  [string]$Output = "$PSScriptRoot\..\artifacts\physical-profile"
)
$ErrorActionPreference = 'Stop'
function Read-Device {
  param([string[]]$Arguments)
  $result = & $Adb -s $DeviceId @Arguments 2>&1
  if ($LASTEXITCODE -ne 0) { throw "Device command failed: $result" }
  return ($result -join "`n").Trim()
}
if ((Read-Device -Arguments @('get-state')) -ne 'device') { throw '手机未连接或未授权 USB 调试' }
$qemu = Read-Device -Arguments @('shell','getprop','ro.kernel.qemu')
$bootQemu = Read-Device -Arguments @('shell','getprop','ro.boot.qemu')
$hardware = Read-Device -Arguments @('shell','getprop','ro.hardware')
if ($qemu -eq '1' -or $bootQemu -eq '1' -or $hardware -match 'goldfish|ranchu') {
  throw '拒绝模拟器：本脚本只采集安卓真机 Profile，未执行安装或测试。'
}
$installed = Read-Device -Arguments @('shell','pm','list','packages','io.determine.shuiyuan_flow')
if ($installed -match '(?m)^package:io\.determine\.shuiyuan_flow$') {
  throw '该手机已有源流应用。为保护现有数据，脚本拒绝覆盖；请使用未安装源流的专用测试设备。'
}
New-Item -ItemType Directory -Force -Path $Output | Out-Null
$resolvedOutput = (Resolve-Path -LiteralPath $Output).Path
$serialBytes = [Text.Encoding]::UTF8.GetBytes($DeviceId)
$metadata = [ordered]@{
  status = 'ready-to-run'
  serial_sha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($serialBytes)).ToLower()
  model = Read-Device -Arguments @('shell','getprop','ro.product.model')
  android_sdk = Read-Device -Arguments @('shell','getprop','ro.build.version.sdk')
  hardware = $hardware
  display = Read-Device -Arguments @('shell','wm','size')
  density = Read-Device -Arguments @('shell','wm','density')
  mode = 'profile'
  synthetic_data = $true
}
$metadata | ConvertTo-Json -Depth 4 | Set-Content "$resolvedOutput\device.json" -Encoding utf8
Read-Device -Arguments @('shell','dumpsys','battery') | Set-Content "$resolvedOutput\battery-before.txt" -Encoding utf8
$previousOutput = $env:SHUIYUAN_PROFILE_OUTPUT
$env:SHUIYUAN_PROFILE_OUTPUT = $resolvedOutput
Push-Location "$PSScriptRoot\.."
try {
  & $Flutter drive --profile -d $DeviceId --no-pub --driver=test_driver/physical_profile_driver.dart --target=integration_test/physical_profile_test.dart *> "$resolvedOutput\run.txt"
  if ($LASTEXITCODE -ne 0) { throw "Profile 测试失败，查看 $resolvedOutput\run.txt" }
  $metrics = Get-Content "$resolvedOutput\metrics.json" -Raw | ConvertFrom-Json
  if ($metrics.mode -ne 'profile' -or $metrics.android_qemu -ne $false) { throw '未获得符合要求的真机 Profile 指标' }
  $metadata.status = 'completed'
  $metadata | ConvertTo-Json -Depth 4 | Set-Content "$resolvedOutput\device.json" -Encoding utf8
  'Profile 采集完成，需在 DevTools 中分析时间线后再给出性能结论。'
} finally {
  Pop-Location
  $env:SHUIYUAN_PROFILE_OUTPUT = $previousOutput
}
