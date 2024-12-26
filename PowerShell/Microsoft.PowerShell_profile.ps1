. $PSScriptRoot/Scripts/hsndev/functions.ps1
# Linux-like aliases
# which/where
Remove-Item -Path Alias:where -Force
Set-Alias -Name where -Value where.exe -Force
New-Alias which where.exe
# grep
New-Alias grep Select-String
# ls --> lsd
Set-Alias ls lsd
function l { lsd -l $args }
function la { lsd -a $args }
function lla { lsd -la $args }
function lt { lsd --tree $args }
# https://github.com/ChrisTitusTech/winutil
Set-Alias -Name winutil -Value Invoke-WinUtil
# Starship init
Invoke-Expression (&starship init powershell)
#f45873b3-b655-43a6-b217-97c00aa0db58 PowerToys CommandNotFound module
Import-Module -Name Microsoft.WinGet.CommandNotFound
#f45873b3-b655-43a6-b217-97c00aa0db58
