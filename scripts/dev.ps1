param([int]$Port = 5173)
. (Join-Path $PSScriptRoot 'flutter-env.ps1')
Push-Location $taskRoot
try {
    & $taskFlutter --no-version-check run -d web-server --web-hostname 127.0.0.1 --web-port $Port
    if ($LASTEXITCODE -ne 0) { throw 'Web preview failed' }
} finally {
    Pop-Location
}
