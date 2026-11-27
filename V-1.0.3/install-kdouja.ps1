<#
.SYNOPSIS
    Aarkam Kdouja — Production Installation & Bootstrap Script for Windows.

.DESCRIPTION
    Automates the production deployment of BOTH the Aarkam Kdouja Server Daemon ('kdoujad.exe')
    and Kdouja CLI & Storage Inspector ('kdouja.exe' / 'kdouja-cli.exe') on
    Windows Server 2022 / Windows Server 2025 and Windows 10/11 (x64).
    
    Features:
    - Deploys both Server Daemon and CLI binaries.
    - Permanently adds Kdouja to Machine or User PATH environment variable.
    - Broadcasts WM_SETTINGCHANGE so running and new terminal sessions recognize 'kdouja' and 'kdouja-cli' instantly.
    - Creates default data directory and appsettings.json.
    - Optionally registers kdoujad as a Windows Service or provides startup scripts.
    - Runs immediate verification (version and node hardware fingerprint).

.PARAMETER InstallDir
    Target directory for binaries. Defaults to 'C:\Program Files\Aarkam\Kdouja' (or '%LOCALAPPDATA%\Aarkam\Kdouja' if non-admin / -UserOnly).

.PARAMETER DataDir
    Target base directory for storage data. Defaults to 'C:\ProgramData\Aarkam\Kdouja\data'.

.PARAMETER SourcePath
    Path to folder or zip archive containing Kdouja Windows binaries. Defaults to script root.

.PARAMETER Port
    Default gRPC / HTTP port for Kdouja Server daemon (defaults to 57771).

.PARAMETER InstallServerService
    Registers and starts kdoujad as a Windows Service ('KdoujaServer'). Enabled by default when running as Administrator unless -SkipService or -UserOnly is specified.

.PARAMETER SkipService
    Skips registering and starting the 'KdoujaServer' Windows Service.

.PARAMETER StoragePreference
    Storage media priority when auto-selecting a non-OS data drive: 'Performance' (default: NVMe -> SSD -> Virtual -> HDD) or 'Capacity' (HDD -> Virtual -> SSD -> NVMe).

.PARAMETER UserOnly
    Installs exclusively for the current user without requiring Administrator elevation.

.EXAMPLE
    .\install-kdouja.ps1

.EXAMPLE
    .\install-kdouja.ps1 -StoragePreference Capacity

.EXAMPLE
    .\install-kdouja.ps1 -SkipService

.EXAMPLE
    .\install-kdouja.ps1 -UserOnly
#>

[CmdletBinding()]
param(
    [string]$InstallDir = "",
    [string]$DataDir = "",
    [string]$SourcePath = "",
    [int]$Port = 57771,
    [ValidateSet("Performance", "Capacity")]
    [string]$StoragePreference = "Performance",
    [switch]$InstallServerService,
    [switch]$SkipService,
    [switch]$UserOnly
)

$ErrorActionPreference = "Stop"

function Write-Info  { param([string]$Message) Write-Host "[INFO]  $Message" -ForegroundColor Cyan }
function Write-Ok    { param([string]$Message) Write-Host "[OK]    $Message" -ForegroundColor Green }
function Write-Warn  { param([string]$Message) Write-Host "[WARN]  $Message" -ForegroundColor Yellow }
function Write-Err   { param([string]$Message) Write-Host "[ERROR] $Message" -ForegroundColor Red }

Write-Host "======================================================================" -ForegroundColor Blue
Write-Host " Aarkam Kdouja — Server Daemon & CLI Production Installer (Windows)  " -ForegroundColor Cyan
Write-Host " Version: V-1.0.3 | Air-Gapped Sovereign Direct I/O Storage Engine    " -ForegroundColor Blue
Write-Host "======================================================================" -ForegroundColor Blue

# ------------------------------------------------------------------------------
# Step 1: Privilege & Architecture Verification
# ------------------------------------------------------------------------------
if ([IntPtr]::Size -ne 8) {
    Write-Err "64-bit architecture (x64) is required. 32-bit execution is unsupported."
    exit 1
}

$isAdmin = $false
try {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
} catch {
    $isAdmin = $false
}

if (-not $isAdmin -and -not $UserOnly.IsPresent) {
    Write-Warn "Installer not running as Administrator. Falling back to CurrentUser installation."
    $UserOnly = [switch]::Present
}

# ------------------------------------------------------------------------------
# Step 2: Resolve Target Installation & Data Directories
# ------------------------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($InstallDir)) {
    if ($isAdmin -and -not $UserOnly.IsPresent) {
        $InstallDir = Join-Path $env:ProgramFiles "Aarkam\Kdouja"
    } else {
        $localAppData = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
        $InstallDir = Join-Path $localAppData "Aarkam\Kdouja"
    }
}

if ([string]::IsNullOrWhiteSpace($DataDir)) {
    $osDriveRoot = (($env:SystemDrive).TrimEnd('\') + "\").ToUpperInvariant()
    $minPreferredBytes = 10GB

    $candidates = @()
    foreach ($drv in [System.IO.DriveInfo]::GetDrives()) {
        if ($drv.DriveType -ne [System.IO.DriveType]::Fixed -or -not $drv.IsReady) { continue }
        if ($drv.RootDirectory.FullName.ToUpperInvariant() -eq $osDriveRoot) { continue }
        if ($drv.AvailableFreeSpace -le 0) { continue }

        $letter = $drv.Name.Substring(0, 1)
        $mediaClass = "Unknown"
        try {
            $part = Get-Partition -DriveLetter $letter -ErrorAction Stop | Select-Object -First 1
            $disk = Get-Disk -Number $part.DiskNumber -ErrorAction Stop
            $phys = Get-PhysicalDisk -ErrorAction SilentlyContinue | Where-Object { $_.DeviceId -eq "$($disk.Number)" } | Select-Object -First 1

            $busType = if ($phys -and $phys.BusType) { "$($phys.BusType)" } else { "$($disk.BusType)" }
            $mediaType = if ($phys -and $phys.MediaType) { "$($phys.MediaType)" } else { "Unspecified" }

            if ($busType -ieq "NVMe") {
                $mediaClass = "NVMe"
            } elseif ($mediaType -ieq "SSD") {
                $mediaClass = "SSD"
            } elseif ($mediaType -ieq "HDD") {
                $mediaClass = "HDD"
            }
        } catch {
            $mediaClass = "Unknown"
        }

        $tierRank = if ($StoragePreference -eq "Capacity") {
            switch ($mediaClass) {
                "HDD"     { 1 }
                "Unknown" { 2 }
                "SSD"     { 3 }
                "NVMe"    { 4 }
                default   { 2 }
            }
        } else {
            switch ($mediaClass) {
                "NVMe"    { 1 }
                "SSD"     { 2 }
                "Unknown" { 3 }
                "HDD"     { 4 }
                default   { 3 }
            }
        }

        $candidates += [PSCustomObject]@{
            Root        = $drv.RootDirectory.FullName
            Name        = $drv.Name
            MediaClass  = $mediaClass
            TierRank    = $tierRank
            FreeBytes   = $drv.AvailableFreeSpace
            FreeGb      = [Math]::Round($drv.AvailableFreeSpace / 1GB, 2)
        }
    }

    if ($candidates.Count -gt 0) {
        # Guardrail: prefer drives with >= 10 GB free when available
        $eligible = @($candidates | Where-Object { $_.FreeBytes -ge $minPreferredBytes })
        if ($eligible.Count -eq 0) { $eligible = $candidates }

        $bestDrive = $eligible | Sort-Object -Property @{ Expression = "TierRank"; Ascending = $true }, @{ Expression = "FreeBytes"; Ascending = $false } | Select-Object -First 1
        $DataDir = Join-Path $bestDrive.Root "Aarkam\Kdouja\data"
        Write-Ok "Selected non-OS storage partition '$($bestDrive.Name)' [$($bestDrive.MediaClass), $($bestDrive.FreeGb) GB free] (Preference: $StoragePreference)."
    } elseif ($isAdmin -and -not $UserOnly.IsPresent) {
        $DataDir = Join-Path $env:ProgramData "Aarkam\Kdouja\data"
        Write-Warn "No non-OS fixed partition detected. Falling back to OS partition: $DataDir"
    } else {
        $localAppData = [Environment]::GetFolderPath([Environment+SpecialFolder]::LocalApplicationData)
        $DataDir = Join-Path $localAppData "Aarkam\Kdouja\data"
        Write-Warn "No non-OS fixed partition detected. Falling back to OS partition: $DataDir"
    }
}

Write-Info "Target Binary Directory : $InstallDir"
Write-Info "Target Data Directory   : $DataDir"

if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
}

if (-not (Test-Path $DataDir)) {
    New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
}

# ------------------------------------------------------------------------------
# Step 3: Deploy Binaries (Server and CLI)
# ------------------------------------------------------------------------------
if ([string]::IsNullOrWhiteSpace($SourcePath)) {
    $scriptRoot = $PSScriptRoot
    if (Test-Path (Join-Path $scriptRoot "kdouja.exe")) {
        $SourcePath = $scriptRoot
    } elseif (Test-Path (Join-Path $scriptRoot "win\kdouja.exe")) {
        $SourcePath = Join-Path $scriptRoot "win"
    } elseif (Test-Path (Join-Path $scriptRoot "kdouja-v1.0.3-win-x64.zip")) {
        $SourcePath = Join-Path $scriptRoot "kdouja-v1.0.3-win-x64.zip"
    } else {
        $SourcePath = $scriptRoot
    }
}

Write-Info "Deploying binaries from: $SourcePath"

# Stop existing KdoujaServer Windows Service if running so binaries can be replaced cleanly
$serviceName = "KdoujaServer"
if ($isAdmin) {
    $runningSvc = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
    if ($runningSvc -and $runningSvc.Status -ne 'Stopped') {
        Write-Info "Stopping existing '$serviceName' service before updating binaries..."
        Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue
        $runningSvc.WaitForStatus('Stopped', [TimeSpan]::FromSeconds(15))
        Write-Ok "Stopped '$serviceName' service."
    }
}

if ($SourcePath.EndsWith(".zip", [System.StringComparison]::OrdinalIgnoreCase) -and (Test-Path $SourcePath)) {
    $tempExtract = Join-Path ([System.IO.Path]::GetTempPath()) ("kdouja_zip_" + [System.Guid]::NewGuid().ToString("N"))
    Expand-Archive -Path $SourcePath -DestinationPath $tempExtract -Force
    Copy-Item -Path "$tempExtract\*" -Destination $InstallDir -Recurse -Force
    Remove-Item -Path $tempExtract -Recurse -Force
} elseif (Test-Path $SourcePath) {
    Copy-Item -Path "$SourcePath\*" -Destination $InstallDir -Recurse -Force
} else {
    Write-Err "Could not find valid binary source at '$SourcePath'."
    exit 1
}

# Ensure both kdouja.exe and kdouja-cli.exe exist
$kdoujaExe = Join-Path $InstallDir "kdouja.exe"
$kdoujaCliExe = Join-Path $InstallDir "kdouja-cli.exe"
$kdoujadExe = Join-Path $InstallDir "kdoujad.exe"

if ((Test-Path $kdoujaExe) -and -not (Test-Path $kdoujaCliExe)) {
    Copy-Item $kdoujaExe $kdoujaCliExe -Force
}
if ((Test-Path $kdoujaCliExe) -and -not (Test-Path $kdoujaExe)) {
    Copy-Item $kdoujaCliExe $kdoujaExe -Force
}

if (-not (Test-Path $kdoujaExe) -or -not (Test-Path $kdoujadExe)) {
    Write-Err "Missing expected binaries (kdouja.exe and kdoujad.exe) in $InstallDir"
    exit 1
}

Write-Ok "Kdouja Server Daemon deployed : $kdoujadExe"
Write-Ok "Kdouja CLI deployed           : $kdoujaExe & $kdoujaCliExe"

# ------------------------------------------------------------------------------
# Step 4: Configure appsettings.json & Service Configuration
# ------------------------------------------------------------------------------
$appSettingsPath = Join-Path $InstallDir "appsettings.json"
if (-not (Test-Path $appSettingsPath)) {
    $configContent = @"
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft": "Warning",
      "Grpc": "Information"
    }
  },
  "Kdouja": {
    "BaseDirectory": "$($DataDir -replace '\\', '\\\\')",
    "Port": $Port,
    "EnableDirectIO": true,
    "SyncWAL": true
  }
}
"@
    Set-Content -Path $appSettingsPath -Value $configContent -Encoding utf8
    Write-Ok "Default appsettings.json created at $appSettingsPath (Port: $Port)"
}

# Create interactive start script for daemon
$startBatPath = Join-Path $InstallDir "start-kdoujad.cmd"
$startBatContent = @"
@echo off
set "KDOUJA_BASE_DIRECTORY=$DataDir"
set "DOTNET_CLI_TELEMETRY_OPTOUT=1"
echo Starting Aarkam Kdouja Storage Engine Daemon on port $Port...
"$kdoujadExe" --urls "http://0.0.0.0:$Port"
"@
Set-Content -Path $startBatPath -Value $startBatContent -Encoding ascii
Write-Ok "Created daemon startup launcher: $startBatPath"

# ------------------------------------------------------------------------------
# Step 5: Configure System / User Environment PATH (MANDATORY REQUIREMENT)
# ------------------------------------------------------------------------------
$targetScope = if ($isAdmin -and -not $UserOnly.IsPresent) { 
    [System.EnvironmentVariableTarget]::Machine 
} else { 
    [System.EnvironmentVariableTarget]::User 
}

$existingPath = [System.Environment]::GetEnvironmentVariable("Path", $targetScope)
$paths = @($existingPath -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
$filteredPaths = @($paths | Where-Object { $_.TrimEnd('\') -ine $InstallDir.TrimEnd('\') })
$newPath = (@($InstallDir) + $filteredPaths) -join ';'

if ($existingPath -ne $newPath) {
    Write-Info "Adding '$InstallDir' to $($targetScope.ToString()) PATH..."
    [System.Environment]::SetEnvironmentVariable("Path", $newPath, $targetScope)
    Write-Ok "PATH updated successfully in $($targetScope.ToString()) environment."
} else {
    Write-Ok "'$InstallDir' is already present in $($targetScope.ToString()) PATH."
}

# Update current PowerShell process PATH
$sessionPaths = @($env:Path -split ';' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $_.TrimEnd('\') -ine $InstallDir.TrimEnd('\') })
$env:Path = (@($InstallDir) + $sessionPaths) -join ';'
Write-Ok "Current PowerShell session PATH refreshed."

# Persist KDOUJA_BASE_DIRECTORY so kdouja CLI and KdoujaServer always target the same non-OS data directory
[System.Environment]::SetEnvironmentVariable("KDOUJA_BASE_DIRECTORY", $DataDir, $targetScope)
$env:KDOUJA_BASE_DIRECTORY = $DataDir
Write-Ok "Configured KDOUJA_BASE_DIRECTORY='$DataDir' in $($targetScope.ToString()) environment."

# Broadcast WM_SETTINGCHANGE so running Explorer, CMD, and PowerShell pick up new PATH
try {
    Add-Type -Namespace Win32 -Name NativeMethods -MemberDefinition @"
[System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true, CharSet = System.Runtime.InteropServices.CharSet.Auto)]
public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
"@
    $HWND_BROADCAST = [IntPtr]0xffff
    $WM_SETTINGCHANGE = 0x001A
    $SMTO_ABORTIFHUNG = 0x0002
    $result = [UIntPtr]::Zero
    [Win32.NativeMethods]::SendMessageTimeout($HWND_BROADCAST, $WM_SETTINGCHANGE, [UIntPtr]::Zero, "Environment", $SMTO_ABORTIFHUNG, 3000, [ref]$result) | Out-Null
    Write-Ok "Broadcasted environment change notification to all Windows processes."
} catch {
    Write-Warn "Could not broadcast WM_SETTINGCHANGE (non-critical): $_"
}

# ------------------------------------------------------------------------------
# Step 6: Windows Service Registration & Startup for Kdouja Server Daemon
# ------------------------------------------------------------------------------
$shouldInstallService = ($InstallServerService.IsPresent) -or ($isAdmin -and -not $UserOnly.IsPresent -and -not $SkipService.IsPresent)

if ($shouldInstallService) {
    if ($isAdmin) {
        Write-Info "Registering '$serviceName' as a Windows Service..."
        $binPathInner = '\"' + $kdoujadExe + '\" --Kdouja:BaseDirectory=\"' + $DataDir + '\" --urls=\"http://0.0.0.0:' + $Port + '\"'

        $existingService = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($existingService) {
            Write-Info "Service '$serviceName' already exists. Updating binary path and configuration..."
            $scArgs = "config $serviceName binPath= `"$binPathInner`" start= auto"
            $p = Start-Process -FilePath "sc.exe" -ArgumentList $scArgs -Wait -NoNewWindow -PassThru
            if ($p.ExitCode -ne 0) { throw "sc.exe config failed with exit code $($p.ExitCode)" }
        } else {
            $scArgs = "create $serviceName binPath= `"$binPathInner`" start= auto DisplayName= `"Aarkam Kdouja Storage Engine Daemon`""
            $p = Start-Process -FilePath "sc.exe" -ArgumentList $scArgs -Wait -NoNewWindow -PassThru
            if ($p.ExitCode -ne 0) { throw "sc.exe create failed with exit code $($p.ExitCode)" }
            Start-Process -FilePath "sc.exe" -ArgumentList "description $serviceName `"High-throughput standalone LSM-tree and Direct I/O storage engine substrate.`"" -Wait -NoNewWindow | Out-Null
        }

        # Configure automatic crash recovery (restart on failure)
        Start-Process -FilePath "sc.exe" -ArgumentList "failure $serviceName reset= 86400 actions= restart/5000/restart/10000/restart/30000" -Wait -NoNewWindow | Out-Null
        Write-Ok "Windows Service '$serviceName' registered successfully (Automatic startup)."

        try {
            Write-Info "Starting '$serviceName' Windows Service..."
            Start-Service -Name $serviceName
            Start-Sleep -Seconds 2
            $svcStatus = (Get-Service -Name $serviceName).Status
            if ($svcStatus -eq 'Running') {
                Write-Ok "Windows Service '$serviceName' is RUNNING on port $Port."
            } else {
                Write-Warn "Windows Service '$serviceName' status is '$svcStatus'. Check Windows Event Viewer (Application log) for details."
            }
        } catch {
            Write-Warn "Registered '$serviceName', but failed to start automatically: $_"
            Write-Info "You can inspect logs or start manually with: Start-Service $serviceName"
        }
    } else {
        Write-Warn "Administrator privileges are required to install to 'C:\Program Files\Aarkam\Kdouja' and register '$serviceName' as a Windows Service."
        Write-Info "Re-run PowerShell as Administrator and execute .\install-kdouja.ps1 to register the service."
    }
} elseif (-not $isAdmin) {
    Write-Warn "Skipped Windows Service registration (not running as Administrator). Run PowerShell as Administrator to install to 'C:\Program Files\Aarkam\Kdouja' and register '$serviceName'."
}

# ------------------------------------------------------------------------------
# Step 7: Verification
# ------------------------------------------------------------------------------
Write-Info "Verifying Kdouja installation and extracting node identity..."
try {
    $cliTest = & $kdoujaExe --version
    Write-Ok "CLI Execution Verified  : $cliTest"
} catch {
    Write-Warn "Failed to execute '$kdoujaExe --version': $_"
}

try {
    Write-Info "Testing node hardware fingerprint..."
    & $kdoujaExe license fingerprint --table
} catch {
    Write-Warn "Could not probe fingerprint: $_"
}

Write-Host "======================================================================" -ForegroundColor Green
Write-Host " Aarkam Kdouja Installation Completed Successfully!                   " -ForegroundColor Green
Write-Host " CLI Commands:  'kdouja --help' or 'kdouja-cli --help'               " -ForegroundColor Cyan
Write-Host " Server Daemon: '$startBatPath' or 'kdoujad.exe'                      " -ForegroundColor Cyan
Write-Host " Environment:   '$InstallDir' is permanently added to PATH           " -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
