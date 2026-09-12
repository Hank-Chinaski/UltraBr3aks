$ErrorActionPreference = 'Stop'
if (Get-Process -Name 'NBA2K27' -ErrorAction SilentlyContinue) { throw 'Close NBA 2K27 before restoring its configuration.' }
$configPath = 'C:\Users\PIZZAOVEN\AppData\Local\2K Sports\NBA 2K27\VideoSettings.cfg'
$backupPath = 'C:\Users\PIZZAOVEN\Documents\CrashDiagnostics\NBA-DLSS-Test\20260912-022339-080\VideoSettings.before.cfg'
if (-not (Test-Path -LiteralPath $backupPath -PathType Leaf)) { throw 'The saved pre-test configuration is missing.' }
$savedConfig = [System.IO.File]::ReadAllText($backupPath) | ConvertFrom-Json
if ($savedConfig.RESOLUTION_SCALING_TECHNIQUE -ne 2) { throw 'Backup does not contain the expected DLSS configuration.' }
[System.IO.File]::Copy($backupPath,$configPath,$true)
if ((Get-FileHash -LiteralPath $configPath -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $backupPath -Algorithm SHA256).Hash) { throw 'Restoration verification failed.' }
Write-Output 'Restored the exact pre-test NBA configuration, including DLSS Performance.'
