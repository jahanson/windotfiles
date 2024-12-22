. $PSScriptRoot/Scripts/hsndev/functions.ps1
# What the heck windows? Why is where an alias for Where-Object? Be normal!
Remove-Item -Path Alias:where -Force
Set-Alias -Name where -Value where.exe -Force
# https://github.com/ChrisTitusTech/winutil
Set-Alias -Name winutil -Value Invoke-WinUtil
# https://github.com/devblackops/Terminal-Icons
Import-Module -Name Terminal-Icons