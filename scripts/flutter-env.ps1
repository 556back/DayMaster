$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path $PSScriptRoot -Parent
$taskLocalFlutter = Join-Path $taskRoot '.tooling/flutter/bin/flutter.bat'
if (Test-Path -LiteralPath $taskLocalFlutter) {
    $taskFlutter = $taskLocalFlutter
} else {
    $taskFlutter = (Get-Command flutter -ErrorAction Stop).Source
}

# Optional local SDK/cache; a normal Flutter installation works without .tooling.
foreach ($taskEntry in @{
    PUB_CACHE = '.tooling/pub-cache'
    APPDATA = '.tooling/appdata'
    ANDROID_HOME = '.tooling/android-sdk'
    ANDROID_USER_HOME = '.tooling/android-user'
    GRADLE_USER_HOME = '.tooling/gradle'
}.GetEnumerator()) {
    $taskLocalPath = Join-Path $taskRoot $taskEntry.Value
    if (Test-Path -LiteralPath $taskLocalPath) {
        [Environment]::SetEnvironmentVariable($taskEntry.Key, $taskLocalPath, 'Process')
    }
}
if ($env:ANDROID_HOME) { $env:ANDROID_SDK_ROOT = $env:ANDROID_HOME }
