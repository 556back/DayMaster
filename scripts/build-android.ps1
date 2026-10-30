param([switch]$Release, [switch]$Universal)
. (Join-Path $PSScriptRoot 'flutter-env.ps1')
if ($Release -and -not (Test-Path -LiteralPath (Join-Path $taskRoot 'android/key.properties'))) {
    throw 'Configure android/key.properties before a release build. See docs/BUILDING.md.'
}
Push-Location $taskRoot
try {
    $taskBuildMode = if ($Release) { '--release' } else { '--debug' }
    $taskBuildArgs = @('build', 'apk', $taskBuildMode)
    if (-not $Universal) { $taskBuildArgs += '--split-per-abi' }
    & $taskFlutter --no-version-check @taskBuildArgs
    if ($LASTEXITCODE -ne 0) { throw 'Android build failed' }
} finally {
    Pop-Location
}
