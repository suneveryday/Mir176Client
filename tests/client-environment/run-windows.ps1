param(
    [Parameter(Mandatory = $true)][string]$Ide,
    [Parameter(Mandatory = $true)][string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
if (!(Test-Path -LiteralPath $Ide -PathType Leaf)) { throw 'Licensed Delphi IDE required' }
if (Test-Path -LiteralPath $OutputDirectory) { throw 'Use a fresh test output directory' }
$root = [IO.Directory]::CreateDirectory($OutputDirectory).FullName
$unitDir = [IO.Directory]::CreateDirectory((Join-Path $root 'client/current-source/Source/MirClient')).FullName
$testDir = [IO.Directory]::CreateDirectory((Join-Path $root 'tests/client-environment')).FullName
Copy-Item -LiteralPath "$PSScriptRoot/../../client/current-source/Source/MirClient/ClientEnvironmentCheck.pas" -Destination $unitDir
Copy-Item -LiteralPath "$PSScriptRoot/EnvironmentRegression.dpr" -Destination $testDir
$project = Join-Path $testDir 'EnvironmentRegression.dpr'
$log = Join-Path $root 'compiler.err'
# Documented IDE AutoBuild; Community Edition does not support direct dcc32 builds.
$build = Start-Process -FilePath $Ide -ArgumentList @('-b', '-ns', '-np', ('-o"' + $log + '"'), ('"' + $project + '"')) -Wait -PassThru
if ($build.ExitCode -ne 0) { throw 'Offline regression did not compile; inspect the local compiler output' }
$programs = @(Get-ChildItem -LiteralPath $root -Recurse -File -Filter EnvironmentRegression.exe)
if ($programs.Count -ne 1) { throw 'Expected exactly one fresh regression executable' }
$result = & $programs[0].FullName
if ($LASTEXITCODE -ne 0 -or ($result -join "`n") -notmatch '^PASS \d+ client environment checks; no game connection$') {
    throw 'Client environment regression failed'
}
$result
