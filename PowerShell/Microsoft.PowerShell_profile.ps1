. $PSScriptRoot/Scripts/hsndev/functions.ps1

<#
.SYNOPSIS
    Personal PowerShell profile configuration for enhanced development environment.

.DESCRIPTION
    This PowerShell profile configures a customized shell environment with:
    - Terminal icons and visual enhancements
    - Custom aliases and functions (where, grep, ls/lsd, winutil, printenv, dig, ssh-copy-id)
    - Environment path synchronization and management
    - Telemetry opt-out settings
    - Module management and auto-installation
    - Shell enhancements (Starship prompt, Zoxide smart navigation)
    - Development tools integration (mise, github-cli, kubectl, helmfile)
    - Azure CLI completion support
    - Enhanced tab completion with PSReadline
    - PowerShell update management
    - Elevated command execution support
    - System utilities (cache clearing, zip extraction, symbolic links)
    - Network utilities (public IP lookup, DNS flushing)
    - Profile management (edit, update, reload)
    - Unix-like commands (df, sed, pkill, pgrep, head, tail)
    - Intelligent command history filtering
    - Custom completions for git, npm, deno, and dotnet
    - Smart directory navigation with zoxide
.NOTES
    Author: jahanson
    Last Updated: 2025-03-15
    Inspiration: Chris Titus (https://github.com/ChrisTitusTech/powershell-profile/)
#>

## Prompt Customization
# Enhanced PowerShell Experience
# Enhanced PSReadLine Configuration
$PSReadLineOptions = @{
    EditMode                      = 'Windows'
    HistoryNoDuplicates           = $true
    HistorySearchCursorMovesToEnd = $true
    Colors                        = @{
        Command   = '#87CEEB'  # SkyBlue (pastel)
        Parameter = '#98FB98'  # PaleGreen (pastel)
        Operator  = '#FFB6C1'  # LightPink (pastel)
        Variable  = '#DDA0DD'  # Plum (pastel)
        String    = '#FFDAB9'  # PeachPuff (pastel)
        Number    = '#B0E0E6'  # PowderBlue (pastel)
        Type      = '#F0E68C'  # Khaki (pastel)
        Comment   = '#D3D3D3'  # LightGray (pastel)
        Keyword   = '#8367c7'  # Violet (pastel)
        Error     = '#FF6347'  # Tomato (keeping it close to red for visibility)
    }
    PredictionSource              = 'History'
    PredictionViewStyle           = 'ListView'
    BellStyle                     = 'None'
}

# Import PSReadLine module first to ensure it's available before configuring
if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine
    Set-PSReadLineOption @PSReadLineOptions

    # Custom key handlers
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar
    Set-PSReadLineKeyHandler -Chord 'Ctrl+w' -Function BackwardDeleteWord
    Set-PSReadLineKeyHandler -Chord 'Alt+d' -Function DeleteWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow' -Function BackwardWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
    Set-PSReadLineKeyHandler -Chord 'Ctrl+z' -Function Undo
    Set-PSReadLineKeyHandler -Chord 'Ctrl+y' -Function Redo

    # Improved prediction settings - only if PSReadLine version supports it
    $psrlVer = (Get-Module PSReadLine).Version
    if ($psrlVer.Major -gt 2 -or ($psrlVer.Major -eq 2 -and $psrlVer.Minor -ge 1)) {
        Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    }

    # Safe way to add to history - only if PSReadLine is fully loaded
    if ($null -ne (Get-Command -Name Set-PSReadLineOption -ErrorAction SilentlyContinue)) {
        Set-PSReadLineOption -AddToHistoryHandler {
            param($line)
            $sensitive = @('password', 'secret', 'token', 'apikey', 'connectionstring')
            $hasSensitive = $sensitive | Where-Object { $line -match $_ }
            return ($null -eq $hasSensitive)
        }
    }
}

# Improved prediction settings
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -MaximumHistoryCount 10000

# Ability to disable synchronizing user PATH
if (-not $env:NO_PATH_SYNC) {
    # Use UserProcess mode with User paths first for session-specific sync
    Sync-Paths -Mode UserProcess -UserFirst $true
}

#opt-out of telemetry before doing anything, only if PowerShell is run as admin
if ([bool]([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsSystem) {
    [System.Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', 'true', [System.EnvironmentVariableTarget]::Machine)
}

# Admin Check and Prompt Customization
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
function prompt {
    if ($isAdmin) { "[" + (Get-Location) + "] # " } else { "[" + (Get-Location) + "] $ " }
}
$adminSuffix = if ($isAdmin) { " [ADMIN]" } else { "" }
$Host.UI.RawUI.WindowTitle = "PowerShell {0}$adminSuffix" -f $PSVersionTable.PSVersion.ToString()

# Editor Configuration
$EDITOR = if (Test-CommandExists nvim) { 'nvim' }
elseif (Test-CommandExists vim) { 'vim' }
elseif (Test-CommandExists vi) { 'vi' }
elseif (Test-CommandExists code) { 'code' }
elseif (Test-CommandExists notepad++) { 'notepad++' }
else { 'notepad' }
Set-Alias -Name vim -Value $EDITOR

# Aliases Linux-like aliases which/where
if (Test-Path Alias:where) {
    Remove-Item -Path Alias:where -Force
}
Set-Alias -Name where -Value where.exe -Force
Set-Alias which where.exe
# Set UNIX-like aliases for the admin command, so sudo <command> will run the command with elevated rights.
Set-Alias -Name su -Value admin
Set-Alias -Name Reload-Profile -Value Update-Profile
Set-Alias -Name unzip -Value Expand-ZipFile
Set-Alias -Name ln -Value New-SymLink -Option AllScope -Force
Set-Alias -Name cosign -Value cosign-windows-amd64.exe

<# grep #>
Set-Alias grep Select-String

<# ls --> lsd #>
Set-Alias ls lsd
function l { lsd -l $args }
function la { lsd -a $args }
function lla { lsd -la $args }
function lt { lsd --tree $args }

<# https://github.com/ChrisTitusTech/winutil #>
Set-Alias -Name winutil -Value Invoke-WinUtil

<# printenv  #>
function Show-Environment {
    Get-ChildItem Env: | Format-Table -AutoSize
}
Set-Alias -Name printenv -Value Show-Environment

<# Starship init #>
if (Get-Command starship -ErrorAction SilentlyContinue) {
    $(&starship init powershell) | Out-String | Invoke-Expression
}
<# Mise activate #>
if (Get-Command mise -ErrorAction SilentlyContinue) {
    $(mise activate pwsh) | Out-String | Invoke-Expression
}
<# Command not found #>
Import-Module -Name Microsoft.WinGet.CommandNotFound

# To display all available options in the menu
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

<# Command completions for CLI tools #>
# GitHub CLI completion
if (Get-Command gh -ErrorAction SilentlyContinue) {
    $(gh completion -s powershell) | Out-String | Invoke-Expression
}

# Kubectl completion
if (Get-Command kubectl -ErrorAction SilentlyContinue) {
    $(kubectl completion powershell) | Out-String | Invoke-Expression
}

<# Azure CLI completion #>
Register-ArgumentCompleter -Native -CommandName az -ScriptBlock {
    param($commandName, $wordToComplete, $cursorPosition)
    $completion_file = New-TemporaryFile
    $env:ARGCOMPLETE_USE_TEMPFILES = 1
    $env:_ARGCOMPLETE_STDOUT_FILENAME = $completion_file
    $env:COMP_LINE = $wordToComplete
    $env:COMP_POINT = $cursorPosition
    $env:_ARGCOMPLETE = 1
    $env:_ARGCOMPLETE_SUPPRESS_SPACE = 0
    $env:_ARGCOMPLETE_IFS = "`n"
    $env:_ARGCOMPLETE_SHELL = 'powershell'
    az 2>&1 | Out-Null
    Get-Content $completion_file | Sort-Object | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, "ParameterValue", $_)
    }
    Remove-Item $completion_file, Env:\_ARGCOMPLETE_STDOUT_FILENAME, Env:\ARGCOMPLETE_USE_TEMPFILES, Env:\COMP_LINE, Env:\COMP_POINT, Env:\_ARGCOMPLETE, Env:\_ARGCOMPLETE_SUPPRESS_SPACE, Env:\_ARGCOMPLETE_IFS, Env:\_ARGCOMPLETE_SHELL
}

## Titus Aliases
### Quality of Life Aliases

# Navigation Shortcuts
function docs {
    $docs = if (([Environment]::GetFolderPath("MyDocuments"))) { ([Environment]::GetFolderPath("MyDocuments")) } else { $HOME + "\Documents" }
    Set-Location -Path $docs
}

function desktop {
    $dtop = if ([Environment]::GetFolderPath("Desktop")) { [Environment]::GetFolderPath("Desktop") } else { $HOME + "\Documents" }
    Set-Location -Path $dtop
}

# Enhanced Listing
function la { Get-ChildItem -Path . -Force | Format-Table -AutoSize }
function ll { Get-ChildItem -Path . -Force -Hidden | Format-Table -AutoSize }

# Quick Access to System Information
function sysinfo { Get-ComputerInfo }

# Networking Utilities
function flushdns {
    Clear-DnsClientCache
    Write-Host "DNS has been flushed"
}

# Custom completion for common commands
$scriptblock = {
    param($wordToComplete, $commandAst, $cursorPosition)
    $customCompletions = @{
        'git'  = @('status', 'add', 'commit', 'push', 'pull', 'clone', 'checkout')
        'npm'  = @('install', 'start', 'run', 'test', 'build')
        'deno' = @('run', 'compile', 'bundle', 'test', 'lint', 'fmt', 'cache', 'info', 'doc', 'upgrade')
    }

    $command = $commandAst.CommandElements[0].Value
    if ($customCompletions.ContainsKey($command)) {
        $customCompletions[$command] | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}
Register-ArgumentCompleter -Native -CommandName git, npm, deno -ScriptBlock $scriptblock

# Adds terminal completion for `dotnet` command
$scriptblock = {
    param($wordToComplete, $commandAst, $cursorPosition)
    dotnet complete --position $cursorPosition $commandAst.ToString() |
    ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock $scriptblock

# Custom completion for common commands
$scriptblock = {
    param($wordToComplete, $commandAst, $cursorPosition)
    $customCompletions = @{
        'git'  = @('status', 'add', 'commit', 'push', 'pull', 'clone', 'checkout')
        'npm'  = @('install', 'start', 'run', 'test', 'build')
        'deno' = @('run', 'compile', 'bundle', 'test', 'lint', 'fmt', 'cache', 'info', 'doc', 'upgrade')
    }

    $command = $commandAst.CommandElements[0].Value
    if ($customCompletions.ContainsKey($command)) {
        $customCompletions[$command] | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}
Register-ArgumentCompleter -Native -CommandName git, npm, deno -ScriptBlock $scriptblock

# Adds terminal completion for `dotnet` command
$scriptblock = {
    param($wordToComplete, $commandAst, $cursorPosition)
    dotnet complete --position $cursorPosition $commandAst.ToString() |
    ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock $scriptblock

# Initialize zoxide - a smarter cd command that learns your most frequently used directories
# First, check if zoxide is already installed on the system
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    # Initialize zoxide with PowerShell integration
    # --cmd cd: Override the default cd command with zoxide's smart cd
    # The Out-String ensures proper formatting of the initialization script
    Invoke-Expression (& { (zoxide init --cmd cd powershell | Out-String) })
}
else {
    # If zoxide is not found, attempt to install it using winget
    Write-Host "zoxide command not found. Attempting to install via winget..."
    try {
        # Install zoxide using winget with exact match (-e) and specific package ID
        winget install -e --id ajeetdsouza.zoxide
        Write-Host "zoxide installed successfully. Initializing..."
        # After installation, initialize zoxide just as we would above
        Invoke-Expression (& { (zoxide init powershell | Out-String) })
    }
    catch {
        # If installation fails, show the error message
        Write-Error "Failed to install zoxide. Error: $_"
    }
}

# Create global aliases for zoxide commands that work in all scopes
# z: Quick jump to a directory using fuzzy matching (e.g., 'z proj' -> '~/projects')
Set-Alias -Name z -Value __zoxide_z -Option AllScope -Scope Global -Force
# zi: Interactive selection of directories from your database
Set-Alias -Name zi -Value __zoxide_zi -Option AllScope -Scope Global -Force
