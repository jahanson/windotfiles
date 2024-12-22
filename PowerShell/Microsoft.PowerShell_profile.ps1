# What the heck windows? Why is where an alias for Where-Object? Be normal!
Remove-Item -Path Alias:where -Force
Set-Alias -Name where -Value where.exe -Force
Set-Alias -Name winutil -Value Invoke-WinUtil

function Invoke-WinUtil {
    Invoke-ElevatedCommand { Invoke-RestMethod "https://christitus.com/win" | Invoke-Expression }
}

function Invoke-ElevatedCommand {
    param([scriptblock]$ScriptBlock)
    
    if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -Command `"$ScriptBlock`"" -Verb RunAs
        return
    }
    
    Invoke-Command -ScriptBlock $ScriptBlock
}

Import-Module -Name Terminal-Icons