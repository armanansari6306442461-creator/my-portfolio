$ErrorActionPreference = 'Continue'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$watchedFiles = @('index.html', 'style.css', 'script.js')
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $repoRoot
$watcher.Filter = '*'
$watcher.IncludeSubdirectories = $false
$watcher.NotifyFilter = [System.IO.NotifyFilters]::LastWrite -bor [System.IO.NotifyFilters]::FileName -bor [System.IO.NotifyFilters]::Size
$watcher.EnableRaisingEvents = $true

Write-Output 'Starting portfolio auto-push watcher'
Write-Output 'Portfolio auto-push watcher ready'

while ($true) {
    $change = $watcher.WaitForChanged([System.IO.WatcherChangeTypes]::All, 1000)
    if ($change.TimedOut -or $watchedFiles -notcontains $change.Name) {
        continue
    }

    do {
        $change = $watcher.WaitForChanged([System.IO.WatcherChangeTypes]::All, 1200)
    } while (-not $change.TimedOut)

    $status = & git -C $repoRoot status --porcelain -- $watchedFiles
    if ($LASTEXITCODE -ne 0) {
        Write-Output 'ERROR: Git status failed; will retry after the next save.'
        continue
    }
    if (-not $status) {
        continue
    }

    & git -C $repoRoot add -- $watchedFiles
    if ($LASTEXITCODE -ne 0) {
        Write-Output 'ERROR: Git staging failed; will retry after the next save.'
        continue
    }

    & git -C $repoRoot diff --cached --quiet
    if ($LASTEXITCODE -eq 0) {
        continue
    }
    if ($LASTEXITCODE -ne 1) {
        Write-Output 'ERROR: Could not inspect staged changes; will retry after the next save.'
        continue
    }

    & git -C $repoRoot commit -m 'Auto-update portfolio'
    if ($LASTEXITCODE -ne 0) {
        Write-Output 'ERROR: Git commit failed; will retry after the next save.'
        continue
    }

    & git -C $repoRoot push origin main
    if ($LASTEXITCODE -ne 0) {
        Write-Output 'ERROR: GitHub push failed; the local commit is kept for the next retry.'
        continue
    }

    Write-Output 'Portfolio changes pushed to GitHub.'
}