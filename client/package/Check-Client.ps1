param([string]$ClientDirectory = $PSScriptRoot, [switch]$LibraryOnly)
$ErrorActionPreference = 'Stop'

function Get-ClientFile([string]$Root, [string]$Name) {
    if ([string]::IsNullOrWhiteSpace($Name) -or $Name.Contains('\') -or $Name.Contains(':') -or
        $Name -match '(^/|(^|/)(\.|\.\.)(/|$)|//)' -or $Name.Contains([char]0)) {
        throw 'Unsafe manifest path'
    }
    $current = Get-Item -LiteralPath $Root
    if ($current.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Linked installation directory' }
    foreach ($part in $Name.Split('/')) {
        $current = Get-Item -LiteralPath (Join-Path $current.FullName $part)
        if ($current.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Linked installation member' }
    }
    if ($current.PSIsContainer) { throw 'Expected a file' }
    return $current
}

function Test-ClassicClient([string]$Root) {
    $Root = (Get-Item -LiteralPath $Root).FullName
    $descriptor = Get-ClientFile $Root 'client-distribution.json'
    $spec = Get-Content -LiteralPath $descriptor.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($spec.project -ne 'Mir2Classic176' -or $spec.schema_version -ne 1) { throw 'Wrong distribution descriptor' }
    $indexFile = Get-ClientFile $Root 'resource-index.json'
    if ((Get-FileHash -LiteralPath $indexFile.FullName -Algorithm SHA256).Hash.ToLowerInvariant() -ne $spec.resource_index_sha256) {
        throw 'Resource index checksum mismatch'
    }
    $index = Get-Content -LiteralPath $indexFile.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    $expectedId = 'assets-' + $spec.resource_index_sha256.Substring(0, 12)
    if ($spec.resource_set_id -ne $expectedId -or $index.project -ne 'Mir2Classic176' -or
        $index.files.Count -ne $spec.resource_files) { throw 'Resource set mismatch' }
    $count = 0
    $total = [long]0
    $programNames = @($spec.program_files.PSObject.Properties.Name | Sort-Object)
    if (($programNames -join ',') -ne 'Mir176Launcher.exe,Mir2Classic176.exe') { throw 'Wrong program file set' }
    $names = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($property in $spec.program_files.PSObject.Properties) {
        $file = Get-ClientFile $Root $property.Name
        if ((Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant() -ne $property.Value) {
            throw ('Program checksum mismatch: ' + $property.Name)
        }
    }
    foreach ($row in $index.files) {
        if ($row.Path -notmatch '^(Map|Resource|Wav)/' -or -not $names.Add($row.Path)) { throw 'Invalid resource path or duplicate' }
        $file = Get-ClientFile $Root $row.Path
        if ($file.Length -ne $row.Size -or
            (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant() -ne $row.Sha256) {
            throw ('Resource checksum mismatch: ' + $row.Path)
        }
        $total += $file.Length
        $count++
    }
    if ($total -ne $spec.resource_bytes) { throw 'Resource size mismatch' }
    $null = Get-ClientFile $Root 'Data/README.txt'
    return [pscustomobject]@{ resource_set_id = $expectedId; resources = $count; bytes = $total }
}

if (-not $LibraryOnly) {
    try {
        Write-Host 'Checking program and resource files. This may take a few minutes...'
        $result = Test-ClassicClient $ClientDirectory
        Write-Host ('PASS: {0} resources verified ({1}). Start Mir176Launcher.exe.' -f $result.resources, $result.resource_set_id)
        exit 0
    } catch {
        Write-Host ('CHECK FAILED: ' + $_.Exception.Message)
        Write-Host 'Extract the matching program ZIP and resource ZIP into the SAME NEW folder, then retry.'
        exit 1
    }
}
