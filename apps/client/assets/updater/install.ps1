param([string]$Archive, [string]$Target, [int]$OldPid, [string]$Version)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$Target = [IO.Path]::GetFullPath($Target)
if (-not (Test-Path -LiteralPath (Join-Path $Target 'astracct.exe'))) { throw 'Missing installed Astracct' }
$stage = Join-Path $Target ('.astracct-stage-' + [guid]::NewGuid())
$backup = Join-Path $Target ('.astracct-backup-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $stage | Out-Null
$moved = @()
$installed = @()
try {
    $zip = [IO.Compression.ZipFile]::OpenRead($Archive)
    try {
        foreach ($entry in $zip.Entries) {
            $path = [IO.Path]::GetFullPath((Join-Path $stage $entry.FullName))
            if (-not $path.StartsWith($stage + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe ZIP entry' }
        }
    } finally { $zip.Dispose() }
    [IO.Compression.ZipFile]::ExtractToDirectory($Archive, $stage)
    $exe = Join-Path $stage 'astracct.exe'
    if (-not (Test-Path -LiteralPath $exe) -or -not (Test-Path -LiteralPath (Join-Path $stage 'data/flutter_assets'))) { throw 'Incomplete application bundle' }
    $actual = [Diagnostics.FileVersionInfo]::GetVersionInfo($exe).ProductVersion
    if (($actual -split '\+')[0] -ne $Version) { throw 'Wrong application version' }
    New-Item -ItemType Directory -Path $backup | Out-Null
    [Console]::Out.WriteLine('READY')
    [Console]::Out.Flush()
    $old = Get-Process -Id $OldPid -ErrorAction SilentlyContinue
    if ($old -and -not $old.WaitForExit(120000)) { throw 'Application did not exit' }
    foreach ($item in Get-ChildItem -LiteralPath $stage -Force) {
        $destination = Join-Path $Target $item.Name
        if (Test-Path -LiteralPath $destination) {
            Move-Item -LiteralPath $destination -Destination (Join-Path $backup $item.Name)
            $moved += $item.Name
        }
        Move-Item -LiteralPath $item.FullName -Destination $destination
        $installed += $item.Name
    }
    Start-Process -FilePath (Join-Path $Target 'astracct.exe') -WorkingDirectory $Target
} catch {
    foreach ($name in $installed) { Remove-Item -LiteralPath (Join-Path $Target $name) -Recurse -Force }
    foreach ($name in $moved) { Move-Item -LiteralPath (Join-Path $backup $name) -Destination (Join-Path $Target $name) }
    $_ | Out-String | Set-Content -LiteralPath (Join-Path $backup 'install-error.txt')
    throw
} finally {
    if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force }
}
