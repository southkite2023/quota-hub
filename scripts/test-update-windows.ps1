param([string]$CandidateZip, [string]$Installer)
$ErrorActionPreference='Stop'
$fixture=Join-Path $env:RUNNER_TEMP ('astracct-update-test-' + [guid]::NewGuid())
$target=Join-Path $fixture 'Installed App With Spaces'
New-Item -ItemType Directory -Path $target -Force | Out-Null
[IO.Compression.ZipFile]::ExtractToDirectory($CandidateZip,$target)
Set-Content -LiteralPath (Join-Path $target 'keep-user-file.txt') -Value 'unrelated file'
Set-Content -LiteralPath (Join-Path $target 'data/old-bundle-marker.txt') -Value 'old bundle'
$waiter=Start-Process -FilePath powershell.exe -ArgumentList '-NoProfile','-Command','Start-Sleep -Seconds 2' -PassThru -WindowStyle Hidden
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Installer $CandidateZip $target $waiter.Id '1.3.0'; if ($LASTEXITCODE -ne 0) { throw 'Installer rejected replacement' }
if (Test-Path -LiteralPath (Join-Path $target 'data/old-bundle-marker.txt')) {throw 'Old bundle not replaced'}
if (-not (Test-Path -LiteralPath (Join-Path $target 'keep-user-file.txt'))) {throw 'Unrelated file was removed'}
$backups=Get-ChildItem -LiteralPath $target -Directory -Force | Where-Object {$_.Name -like '.astracct-backup-*'}
if (-not (Test-Path -LiteralPath (Join-Path $backups[0].FullName 'data/old-bundle-marker.txt'))) {throw 'Old data bundle not backed up'}
Start-Sleep -Seconds 3
$running=Get-Process astracct -ErrorAction SilentlyContinue | Where-Object {$_.Path -eq (Join-Path $target 'astracct.exe')}
if (-not $running) {throw 'Updated app did not remain running'}
$running | Stop-Process -Force
Start-Sleep -Seconds 1
# Force a real Windows sharing violation, then verify replacement rolls back.
Set-Content -LiteralPath (Join-Path $target 'data/rollback-marker.txt') -Value 'keep on failure'
$lock=[IO.File]::Open((Join-Path $target 'flutter_windows.dll'),[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::None)
$failed=$false
try {
    $waiter=Start-Process -FilePath powershell.exe -ArgumentList '-NoProfile','-Command','Start-Sleep -Seconds 2' -PassThru -WindowStyle Hidden
    try { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Installer $CandidateZip $target $waiter.Id '1.3.0'; if ($LASTEXITCODE -ne 0) { throw 'Installer rejected replacement' } } catch { $failed=$true }
} finally {$lock.Dispose()}
if (-not $failed) {throw 'Locked bundle should reject replacement'}
if (-not (Test-Path -LiteralPath (Join-Path $target 'astracct.exe')) -or -not (Test-Path -LiteralPath (Join-Path $target 'data/rollback-marker.txt'))) {throw 'Rollback did not restore bundle'}
Write-Output 'ASTRACCT_WINDOWS_UPDATE_PASS: version, spaces in path, replacement, backup, relaunch, locked-file rollback'
# The sharing-violation child must fail; clear its expected native exit code after assertions.
$global:LASTEXITCODE=0
