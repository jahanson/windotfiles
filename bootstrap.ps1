## Creates symbolic links to the PowerShell profile and custom scripts directory

$parentScriptsPath = Join-Path (Split-Path $PROFILE) "Scripts"
$hsndevPath = Join-Path $parentScriptsPath "hsndev"
$gitRepoPath = Join-Path $HOME "projects/windotfiles"

# Ensure parent Scripts directory exists
if (-not (Test-Path $parentScriptsPath)) {
    New-Item -ItemType Directory -Path $parentScriptsPath -Force
}
# Backup the current profile if it exists
if (Test-Path $PROFILE) {
    $backupPath = "$PROFILE.bak"
    Move-Item -Path $PROFILE -Destination $backupPath -Force
}

# Create a symbolic link for our custom scripts directory
New-Item -Path $hsndevPath -Value (Join-Path $HOME "projects/windotfiles/Powershell/Scripts/hsndev") -ItemType SymbolicLink -Force

# Create a symbolic link to the Microsoft.PowerShell_profile.ps1 file
New-Item -Path $PROFILE -Value $gitRepoPath/PowerShell/Microsoft.PowerShell_profile.ps1 -ItemType SymbolicLink -Force


