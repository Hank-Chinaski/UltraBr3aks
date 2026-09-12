$ErrorActionPreference = 'Stop'
$gameRoot = [System.IO.Path]::GetFullPath('D:\GAMES\NBA 2K27')
$manifestPath = 'D:\GAMES\NBA 2K27\_Redist\fitgirl.md5'
$manifestBase = Split-Path -Parent $manifestPath
$outputRoot = 'C:\Users\PIZZAOVEN\Documents\CrashDiagnostics\NBA-FileVerification'
$runDirectory = Join-Path $outputRoot (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
$manifestLines = @(Get-Content -LiteralPath $manifestPath)
$entries = @()
$unparsedLines = @()
$lineNumber = 0
foreach ($manifestLine in $manifestLines) {
    $lineNumber++
    if ([string]::IsNullOrWhiteSpace($manifestLine) -or $manifestLine.StartsWith(';') -or $manifestLine.StartsWith('#')) { continue }
    if ($manifestLine -notmatch '^([0-9a-fA-F]{32})\s+\*?(.+)$') {
        $unparsedLines += [pscustomobject]@{Line=$lineNumber; Text=('{0}' -f $manifestLine)}
        continue
    }
    $expectedHash = $Matches[1].ToUpperInvariant()
    $relativePath = $Matches[2]
    $resolvedPath = [System.IO.Path]::GetFullPath((Join-Path $manifestBase $relativePath))
    if (-not $resolvedPath.StartsWith($gameRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)) { throw "Manifest path outside game folder: $relativePath" }
    $entries += [pscustomobject]@{Path=$resolvedPath; ExpectedMD5=$expectedHash}
}
if ($entries.Count -eq 0) { throw 'Manifest has no file entries.' }
New-Item -ItemType Directory -Path $runDirectory | Out-Null
$resultsPath = Join-Path $runDirectory 'file-results.csv'
$summaryPath = Join-Path $runDirectory 'summary.json'
$startedUtc = [DateTime]::UtcNow
$manifestHashBefore = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash
$bytesHashed = [int64]0
$index = 0
$results = [System.Collections.Generic.List[object]]::new()
$totalWatch = [System.Diagnostics.Stopwatch]::StartNew()
Write-Output "Output: $runDirectory"
Write-Output "Manifest entries: $($entries.Count)"
Write-Output "Non-checksum lines retained as unverified: $($unparsedLines.Count)"
foreach ($entry in $entries) {
    $index++
    $actualHash = $null
    $bytes = [int64]0
    $status = 'ERROR'
    $errorText = $null
    try {
        $before = Get-Item -LiteralPath $entry.Path -ErrorAction Stop
        if ($before.PSIsContainer) { throw 'Manifest entry is a directory.' }
        $bytes = $before.Length
        $actualHash = (Get-FileHash -LiteralPath $entry.Path -Algorithm MD5 -ErrorAction Stop).Hash
        $after = Get-Item -LiteralPath $entry.Path -ErrorAction Stop
        $bytesHashed += $bytes
        if ($before.Length -ne $after.Length -or $before.LastWriteTimeUtc -ne $after.LastWriteTimeUtc) { $status = 'CHANGED_DURING_READ' }
        elseif ($actualHash -eq $entry.ExpectedMD5) { $status = 'MATCH' }
        else { $status = 'MISMATCH' }
    } catch [System.Management.Automation.ItemNotFoundException] {
        $status = 'MISSING'
        $errorText = $_.Exception.Message
    } catch {
        $errorText = $_.Exception.Message
    }
    $row = [pscustomobject]@{Index=$index; Path=$entry.Path; Bytes=$bytes; ExpectedMD5=$entry.ExpectedMD5; ActualMD5=$actualHash; Status=$status; Error=$errorText}
    $results.Add($row)
    $row | Export-Csv -LiteralPath $resultsPath -NoTypeInformation -Append -Encoding UTF8
    if ($status -ne 'MATCH' -or $index % 10 -eq 0 -or $index -eq $entries.Count) {
        Write-Output ('{0}/{1}: {2}; hashed {3:N1} GiB; elapsed {4:N0}s; {5}' -f $index,$entries.Count,$status,($bytesHashed / 1GB),$totalWatch.Elapsed.TotalSeconds,$entry.Path)
    }
}
$manifestHashAfter = (Get-FileHash -LiteralPath $manifestPath -Algorithm SHA256).Hash
$summary = [pscustomobject]@{
    StartedUtc=$startedUtc.ToString('o'); FinishedUtc=[DateTime]::UtcNow.ToString('o'); Manifest=$manifestPath
    ManifestSHA256Before=$manifestHashBefore; ManifestSHA256After=$manifestHashAfter; ManifestUnchanged=($manifestHashBefore -eq $manifestHashAfter)
    Total=$entries.Count; Match=@($results | Where-Object Status -eq 'MATCH').Count
    UnparsedManifestLines=$unparsedLines
    Mismatch=@($results | Where-Object Status -eq 'MISMATCH').Count; Missing=@($results | Where-Object Status -eq 'MISSING').Count
    Error=@($results | Where-Object Status -eq 'ERROR').Count; ChangedDuringRead=@($results | Where-Object Status -eq 'CHANGED_DURING_READ').Count
    BytesHashed=$bytesHashed; DurationSeconds=$totalWatch.Elapsed.TotalSeconds
    VersionDllCovered=[bool]($entries.Path -contains (Join-Path $gameRoot 'version.dll'))
    ModExeCovered=[bool]($entries.Path -contains (Join-Path $gameRoot 'mod.exe'))
    ResultsPath=$resultsPath
    Scope='Consistency with the locally supplied manifest only; does not authenticate the package or diagnose the BSOD.'
}
$summary | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $summaryPath -Encoding UTF8
$summary | ConvertTo-Json -Depth 4 | Write-Output
