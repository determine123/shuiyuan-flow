# 本次工作目录专用工具链，不修改系统 PATH 或注册表。
$toolchainRoot = 'D:\Projects\shuiyuan-toolchain'
$env:PATH = "$toolchainRoot\flutter\bin;$toolchainRoot\android\platform-tools;" + $env:PATH
$env:JAVA_HOME = (Get-ChildItem "$toolchainRoot\java" -Directory | Select-Object -First 1).FullName
$env:ANDROID_HOME = "$toolchainRoot\android"
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$env:ANDROID_USER_HOME = "$toolchainRoot\android-user"
$env:ANDROID_AVD_HOME = "$env:ANDROID_USER_HOME\avd"
$env:PUB_CACHE = "$toolchainRoot\pub-cache"
$env:GRADLE_USER_HOME = "$toolchainRoot\gradle"
