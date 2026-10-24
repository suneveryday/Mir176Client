param([string]$Address,[int]$Port)
$ErrorActionPreference='Stop'
if(!$Address){$Address=Read-Host 'Classic server address'}
if(!$Port){$Port=[int](Read-Host 'Classic login port')}
if($Address -notmatch '^[A-Za-z0-9.-]{1,30}$' -or $Port -lt 1 -or $Port -gt 65535){throw 'Invalid address or port'}
# The legacy resource scanner also enumerates the optional root Data directory.
New-Item (Join-Path $PSScriptRoot 'Data') -ItemType Directory -Force|Out-Null
$ini=Join-Path $PSScriptRoot 'Mir2Classic176.ini'
if(Test-Path $ini){throw 'Classic configuration already exists. Edit that file to change the connection.'}
@"
[Server]
Address=$Address
Port=$Port
[Client]
ResourceDir=Resource
Width=800
Height=600
FullScreen=0
[Diagnostics]
Enabled=0
"@|Set-Content $ini -Encoding ASCII
Write-Output 'Classic configuration created. Start Mir2Classic176.exe when the matching server is ready.'
