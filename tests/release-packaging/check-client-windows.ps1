param([string]$OutputDirectory)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/../../client/package/Check-Client.ps1" -LibraryOnly
if (Test-Path -LiteralPath $OutputDirectory) { throw 'Use a new test directory' }
$root = [IO.Directory]::CreateDirectory($OutputDirectory).FullName
function Write-Json($Name, $Value) {
    [IO.File]::WriteAllText((Join-Path $root $Name), ($Value | ConvertTo-Json -Depth 12), (New-Object Text.UTF8Encoding($false)))
}
function Hash($Name) { return (Get-FileHash -LiteralPath (Join-Path $root $Name) -Algorithm SHA256).Hash.ToLowerInvariant() }
function Expect-Failure([scriptblock]$Action) {
    $failed = $false
    try { $null = & $Action } catch { $failed = $true }
    if (-not $failed) { throw 'Expected validation failure' }
}
foreach ($dir in @('Map', 'Resource', 'Wav', 'Data')) { $null = New-Item -ItemType Directory (Join-Path $root $dir) }
[IO.File]::WriteAllText((Join-Path $root 'Data/README.txt'), 'Keep directory')
[IO.File]::WriteAllText((Join-Path $root 'Mir2Classic176.exe'), 'fixture-game')
[IO.File]::WriteAllText((Join-Path $root 'Mir176Launcher.exe'), 'fixture-launcher')
$index = @{ project = 'Mir2Classic176'; files = @() }
foreach ($path in @('Map/0.map', 'Resource/test.wil', 'Wav/test.wav')) {
    [IO.File]::WriteAllText((Join-Path $root $path), 'fixture-resource')
    $index.files += @{Path = $path; Size = 16; Sha256 = (Hash $path)}
}
Write-Json 'resource-index.json' $index
$spec = @{schema_version = 1; project = 'Mir2Classic176'; resource_index_sha256 = (Hash 'resource-index.json');
          resource_files = 3; resource_bytes = 48; program_files = @{'Mir2Classic176.exe' = (Hash 'Mir2Classic176.exe');
          'Mir176Launcher.exe' = (Hash 'Mir176Launcher.exe')}}
function Save-Spec { $spec.resource_set_id = 'assets-' + $spec.resource_index_sha256.Substring(0,12); Write-Json 'client-distribution.json' $spec }
Save-Spec
$result = Test-ClassicClient $root
if ($result.resources -ne 3) { throw 'Wrong resource count' }
$config = '[Server] user setting remains untouched'
[IO.File]::WriteAllText((Join-Path $root 'Mir2Classic176.ini'), $config)
$null = Test-ClassicClient $root
if ([IO.File]::ReadAllText((Join-Path $root 'Mir2Classic176.ini')) -ne $config) { throw 'Changed user configuration' }
Remove-Item -LiteralPath (Join-Path $root 'Map/0.map')
Expect-Failure { Test-ClassicClient $root }
[IO.File]::WriteAllText((Join-Path $root 'Map/0.map'), 'fixture-resource')
[IO.File]::WriteAllText((Join-Path $root 'Wav/test.wav'), 'altered-resource')
Expect-Failure { Test-ClassicClient $root }
[IO.File]::WriteAllText((Join-Path $root 'Wav/test.wav'), 'fixture-resource')
[IO.File]::WriteAllText((Join-Path $root 'Mir2Classic176.exe'), 'altered-game')
Expect-Failure { Test-ClassicClient $root }
[IO.File]::WriteAllText((Join-Path $root 'Mir2Classic176.exe'), 'fixture-game')
$spec.resource_index_sha256 = '0' * 64; Save-Spec
Expect-Failure { Test-ClassicClient $root }
$spec.resource_index_sha256 = Hash 'resource-index.json'; Save-Spec
$index.files[0].Path = 'Map/../outside'
Write-Json 'resource-index.json' $index
$spec.resource_index_sha256 = Hash 'resource-index.json'; Save-Spec
Expect-Failure { Test-ClassicClient $root }
Write-Host 'PASS: 7 isolated Windows assembly checks; no game connection.'
