. $PSScriptRoot/Scripts/hsndev/functions.ps1

# Ability to disable synchronizing user PATH
if (-not $env:NO_PATH_SYNC) {
    Sync-UserPath
}

<# Aliases
 Linux-like aliases which/where
#>
Remove-Item -Path Alias:where -Force
Set-Alias -Name where -Value where.exe -Force
Set-Alias which where.exe

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

<# Doggo - https://github.com/mr-karan/doggo #>
Set-Alias -Name dig -Value doggo.exe -Force

<# Starship init #>
Invoke-Expression (&starship init powershell)

<# Zoxide #>
Invoke-Expression (& { (zoxide init powershell | Out-String) })

# Disable complettion and module activation in non-Windows Terminal environments
# if ($env:TERM_PROGRAM -eq "vscode") {
#     Write-Host "Running in VS Code Terminal"
# }
# elseif ($env:WT_SESSION) {
# It seems these work best in Windows Terminal
<# Mise activate #>
$(mise activate pwsh) | Out-String | Invoke-Expression
<# Command not found #>
Import-Module -Name Microsoft.WinGet.CommandNotFound

# To display all available options in the menu
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete
<# github-cli completion #>
$(gh completion -s powershell) | Out-String | Invoke-Expression
$(kubectl completion powershell) | Out-String | Invoke-Expression
$(helmfile completion powershell) | Out-String | Invoke-Expression
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
# }
