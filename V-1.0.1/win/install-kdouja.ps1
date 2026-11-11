Write-Host "=== Aarkam Kdouja Windows Installer (v1.0.1) ===" -ForegroundColor Cyan

$InstallDir = $PSScriptRoot
$TargetDir = "$env:ProgramFiles\Aarkam\Kdouja"
$DataDir = "$env:ProgramData\Aarkam\Kdouja"

if (-not (Test-Path $TargetDir)) {
    New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
}

if (-not (Test-Path $DataDir)) {
    New-Item -ItemType Directory -Force -Path $DataDir | Out-Null
}

Copy-Item "$InstallDir\*" -Destination $TargetDir -Recurse -Force

# Add to system PATH if not present
$CurrentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($CurrentPath -notlike "*$TargetDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$CurrentPath;$TargetDir", "Machine")
    Write-Host "Added $TargetDir to System PATH." -ForegroundColor Green
}

Write-Host "Aarkam Kdouja installed successfully to $TargetDir." -ForegroundColor Green
Write-Host "Run 'kdouja-cli --help' or 'kdoujad.exe' to get started." -ForegroundColor White
