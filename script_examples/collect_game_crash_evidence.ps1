# Read-only evidence collector for the DingleDerp game-triggered bugchecks.
# Usage tip: run once before launching the game and once while it is at the menu.
# Limitation: this collects live state and event metadata; it does not modify or analyze dump files.
[CmdletBinding()]
param(
    [ValidateSet("Baseline", "GameRunning")]
    [string]$Phase = "Baseline",

    [string]$OutputRoot = "C:\Users\PIZZAOVEN\Documents\CrashDiagnostics\GameComparison",

    [string[]]$GameProcessPattern = @("NBA2K*", "Shipbreaker*")
)

$ErrorActionPreference = "Continue"
$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outputDirectory = Join-Path $OutputRoot ("{0}-{1}" -f $Phase, $timestamp)
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

$errors = [System.Collections.Generic.List[object]]::new()

function Invoke-EvidenceQuery {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Query
    )

    try {
        $result = & $Query
        $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $outputDirectory "$Name.json") -Encoding UTF8
        return $result
    }
    catch {
        $errors.Add([pscustomobject]@{
            Query = $Name
            Error = $_.Exception.Message
        })
        return $null
    }
}

$metadata = [pscustomobject]@{
    ComputerName = $env:COMPUTERNAME
    UserName = $env:USERNAME
    Phase = $Phase
    CapturedAt = (Get-Date).ToString("o")
    IsAdministrator = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
    OutputDirectory = $outputDirectory
}
$metadata | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outputDirectory "metadata.json") -Encoding UTF8

Invoke-EvidenceQuery "operating-system" {
    Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, BuildNumber, LastBootUpTime
} | Out-Null

Invoke-EvidenceQuery "computer-system" {
    Get-CimInstance Win32_ComputerSystem | Select-Object Manufacturer, Model, TotalPhysicalMemory, HypervisorPresent
} | Out-Null

Invoke-EvidenceQuery "video-controller" {
    Get-CimInstance Win32_VideoController | Select-Object Name, DriverVersion, DriverDate, AdapterRAM, PNPDeviceID
} | Out-Null

Invoke-EvidenceQuery "physical-memory" {
    Get-CimInstance Win32_PhysicalMemory | Select-Object BankLabel, DeviceLocator, Manufacturer, PartNumber, Capacity, Speed, ConfiguredClockSpeed
} | Out-Null

Invoke-EvidenceQuery "disks-and-volumes" {
    Get-Disk | ForEach-Object {
        $disk = $_
        $partitions = @(Get-Partition -DiskNumber $disk.Number -ErrorAction SilentlyContinue | ForEach-Object {
            $partition = $_
            $volume = $partition | Get-Volume -ErrorAction SilentlyContinue
            [pscustomobject]@{
                PartitionNumber = $partition.PartitionNumber
                DriveLetter = $partition.DriveLetter
                Size = $partition.Size
                FileSystem = $volume.FileSystem
                FileSystemLabel = $volume.FileSystemLabel
                HealthStatus = $volume.HealthStatus
            }
        })
        [pscustomobject]@{
            Number = $disk.Number
            FriendlyName = $disk.FriendlyName
            SerialNumber = $disk.SerialNumber
            FirmwareVersion = $disk.FirmwareVersion
            BusType = $disk.BusType
            HealthStatus = $disk.HealthStatus
            OperationalStatus = $disk.OperationalStatus
            Partitions = $partitions
        }
    }
} | Out-Null

$gameProcesses = Invoke-EvidenceQuery "matching-game-processes" {
    Get-Process | Where-Object {
        $processName = $_.ProcessName
        @($GameProcessPattern | Where-Object { $processName -like $_ }).Count -gt 0
    } | Select-Object Id, ProcessName, Path, StartTime, MainWindowTitle
}

Invoke-EvidenceQuery "game-process-modules" {
    foreach ($process in @($gameProcesses)) {
        try {
            Get-Process -Id $process.Id -Module -ErrorAction Stop | ForEach-Object {
                [pscustomobject]@{
                    ProcessId = $process.Id
                    ProcessName = $process.ProcessName
                    ModuleName = $_.ModuleName
                    FileName = $_.FileName
                    FileVersion = $_.FileVersionInfo.FileVersion
                    CompanyName = $_.FileVersionInfo.CompanyName
                }
            }
        }
        catch {
            $errors.Add([pscustomobject]@{ Query = "modules:$($process.Id)"; Error = $_.Exception.Message })
        }
    }
} | Out-Null

Invoke-EvidenceQuery "system-drivers" {
    Get-CimInstance Win32_SystemDriver | Select-Object Name, DisplayName, State, StartMode, PathName, ServiceType
} | Out-Null

try {
    (& "$env:SystemRoot\System32\fltmc.exe" filters 2>&1) | Set-Content -LiteralPath (Join-Path $outputDirectory "filesystem-minifilters.txt") -Encoding UTF8
}
catch {
    $errors.Add([pscustomobject]@{ Query = "filesystem-minifilters"; Error = $_.Exception.Message })
}

Invoke-EvidenceQuery "gameinput-services" {
    Get-Service | Where-Object { $_.Name -match "GameInput|GamingServices|Xbox" -or $_.DisplayName -match "GameInput|Gaming|Xbox" } |
        Select-Object Name, DisplayName, Status, StartType
} | Out-Null

Invoke-EvidenceQuery "recent-storage-and-game-events" {
    $startTime = (Get-Date).AddHours(-6)
    Get-WinEvent -FilterHashtable @{ LogName = @("System", "Application"); StartTime = $startTime } -ErrorAction Stop |
        Where-Object {
            $_.ProviderName -match "disk|stornvme|storport|volmgr|WHEA|Display|nvlddmkm|GameInput|GamingServices|MsiInstaller|Windows Error Reporting" -or
            $_.Id -in @(41, 129, 153, 161, 162, 1000, 1001, 11714)
        } |
        Select-Object TimeCreated, LogName, ProviderName, Id, LevelDisplayName, Message
} | Out-Null

Invoke-EvidenceQuery "winsrvext-file" {
    $path = "$env:SystemRoot\System32\winsrvext.dll"
    $file = Get-Item -LiteralPath $path -ErrorAction Stop
    $signature = Get-AuthenticodeSignature -LiteralPath $path
    $hash = Get-FileHash -LiteralPath $path -Algorithm SHA256
    [pscustomobject]@{
        Path = $file.FullName
        Length = $file.Length
        LastWriteTime = $file.LastWriteTime
        FileVersion = $file.VersionInfo.FileVersion
        ProductVersion = $file.VersionInfo.ProductVersion
        SignatureStatus = $signature.Status
        Signer = $signature.SignerCertificate.Subject
        SHA256 = $hash.Hash
    }
} | Out-Null

$errors | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $outputDirectory "collection-errors.json") -Encoding UTF8

Write-Host "Read-only evidence capture complete: $outputDirectory"
if ($errors.Count -gt 0) {
    Write-Warning "$($errors.Count) query or sub-query failures were logged to collection-errors.json. Rerun elevated only if access-denied entries affect the required comparison."
}
