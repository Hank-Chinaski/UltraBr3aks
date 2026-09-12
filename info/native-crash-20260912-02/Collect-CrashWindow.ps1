$ErrorActionPreference = 'Stop'
$start = [datetime]'2026-09-12 05:10:30'
$end = [datetime]'2026-09-12 05:12:10'
$destination = 'C:\UltraBr3aks\info\native-crash-20260912-02\system-crash-window.json'
try {
    $events = @(Get-WinEvent -FilterHashtable @{ LogName = 'System'; StartTime = $start; EndTime = $end } -ErrorAction Stop)
    $records = @($events | Sort-Object TimeCreated | ForEach-Object {
        [pscustomobject]@{ TimeCreated = $_.TimeCreated.ToString('o'); ProviderName = $_.ProviderName; Id = $_.Id; Level = $_.Level; Message = $_.Message; Xml = $_.ToXml() }
    })
    $status = 'Success'
} catch {
    if ($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*') {
        $records = @()
        $status = 'NoMatchingEvents'
    } else { throw }
}
[pscustomobject]@{ StartLocal = $start.ToString('o'); EndLocal = $end.ToString('o'); Status = $status; Count = $records.Count; Events = $records } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $destination -Encoding UTF8
[pscustomobject]@{ Status = $status; Count = $records.Count; Output = $destination } | Format-List
$records | Select-Object TimeCreated,ProviderName,Id,Level,Message | Format-List
