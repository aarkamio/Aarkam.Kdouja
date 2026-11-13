Write-Host "=== Aarkam Kdouja Windows Installer (v1.0.2) ===" -ForegroundColor Cyan

$InstallDir = $PSScriptRoot
$TargetDir = "$env:ProgramFiles\Aarkam\Kdouja"
$DataDir = "$env:ProgramData\Aarkam\Kdouja"
$ConfigDir = "$env:ProgramData\Aarkam\Kdouja\config"

if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
}

if (-not (Test-Path $DataDir)) {
    New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
}

if (-not (Test-Path $ConfigDir)) {
    New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
}

# Copy binaries and dependencies
Copy-Item "$InstallDir\*" -Destination $TargetDir -Recurse -Force

# Create backwards compatibility wrapper kdouja-cli.cmd pointing to kdouja.exe
$WrapperCmd = "@echo off`r`n`"%~dp0kdouja.exe`" %*"
Set-Content -Path "$TargetDir\kdouja-cli.cmd" -Value $WrapperCmd -Encoding ASCII

# Register in system PATH if not present
$CurrentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($CurrentPath -notlike "*$TargetDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$CurrentPath;$TargetDir", "Machine")
    Write-Host "[✓] Added $TargetDir to System PATH." -ForegroundColor Green
}

# Set KDOUJA_BASE_DIRECTORY system environment variable if not present
$CurrentDataDir = [Environment]::GetEnvironmentVariable("KDOUJA_BASE_DIRECTORY", "Machine")
if ([string]::IsNullOrWhiteSpace($CurrentDataDir)) {
    [Environment]::SetEnvironmentVariable("KDOUJA_BASE_DIRECTORY", "$DataDir", "Machine")
    Write-Host "[✓] Configured KDOUJA_BASE_DIRECTORY -> $DataDir" -ForegroundColor Green
}

Write-Host "Aarkam Kdouja v1.0.2 installed successfully to $TargetDir." -ForegroundColor Green
Write-Host "Run 'kdouja --help' (or interactive shell 'kdouja') or 'kdoujad.exe' to get started." -ForegroundColor White