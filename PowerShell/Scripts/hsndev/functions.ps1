# Synchronizes Machine and User paths despite the environment.
function Sync-Paths {
    <#
    .SYNOPSIS
        Synchronizes PATH environment variables across different scopes.

    .DESCRIPTION
        Combines and deduplicates PATH environment variables from different scopes
        (Machine, User, and Process). Provides flexible configuration for path
        prioritization and scope selection.

    .PARAMETER Mode
        Determines which PATH variables to sync:
        - 'MachineUser': Combines Machine and User PATH (traditional system-wide sync)
        - 'UserProcess': Combines User and Process PATH (session-specific sync)
        Default is 'MachineUser'.

    .PARAMETER UserFirst
        When true, places User paths at the beginning of the combined PATH.
        When false, places Machine/Process paths first.
        Default varies by Mode: false for MachineUser, true for UserProcess.

    .NOTES
        - Uses HashSet for efficient case-insensitive deduplication
        - Removes empty entries from all paths
        - Does not modify original PATH variables, only updates current session
        - Replaces both legacy Sync-Paths and Sync-UserPath functions

    .EXAMPLE
        Sync-Paths
        # Traditional Machine + User sync with Machine paths first

    .EXAMPLE
        Sync-Paths -Mode UserProcess -UserFirst $true
        # Session-specific sync with User paths first

    .EXAMPLE
        Sync-Paths -Mode MachineUser -UserFirst $true
        # System-wide sync but with User paths prioritized
    #>
    param(
        [ValidateSet('MachineUser', 'UserProcess')]
        [string]$Mode = 'MachineUser',
        [bool]$UserFirst = ($Mode -eq 'UserProcess')
    )

    # Get paths based on mode
    $userPath = [Environment]::GetEnvironmentVariable("PATH", "User")
    $otherPath = if ($Mode -eq 'MachineUser') {
        [Environment]::GetEnvironmentVariable("PATH", "Machine")
    }
    else {
        $env:PATH
    }

    # Split paths and remove empty entries
    $userPaths = $userPath.Split(';', [StringSplitOptions]::RemoveEmptyEntries)
    $otherPaths = $otherPath.Split(';', [StringSplitOptions]::RemoveEmptyEntries)

    # Create HashSet for efficient duplicate checking
    $pathSet = [System.Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )

    # Initialize arrays for primary and secondary paths
    $primaryPaths = @()
    $secondaryPaths = @()

    # Determine which paths go first based on UserFirst parameter
    if ($UserFirst) {
        $firstPaths = $userPaths
        $secondPaths = $otherPaths
    }
    else {
        $firstPaths = $otherPaths
        $secondPaths = $userPaths
    }

    # Process first set of paths
    foreach ($path in $firstPaths) {
        if ($pathSet.Add($path)) {
            $primaryPaths += $path
        }
    }

    # Process second set of paths
    foreach ($path in $secondPaths) {
        if ($pathSet.Add($path)) {
            $secondaryPaths += $path
        }
    }

    # Combine paths maintaining specified order
    $env:PATH = ($primaryPaths + $secondaryPaths) -join ';'
}

# Create alias for backward compatibility
Set-Alias -Name Sync-UserPath -Value Sync-Paths

function Update-PowerShell {
    <#
    .SYNOPSIS
        Checks for and installs PowerShell updates using winget.

    .DESCRIPTION
        Compares current PowerShell version against the latest GitHub release.
        If an update is available, uses winget to perform the upgrade in a detached process.

    .PARAMETER CurrentVersion
        The current version of PowerShell. Defaults to $PSVersionTable.PSVersion.ToString()

    .PARAMETER Force
        Forces the update check regardless of version comparison

    .PARAMETER NoPrompt
        Skips the confirmation prompt before updating

    .EXAMPLE
        Update-PowerShell -Force

    .EXAMPLE
        Update-PowerShell -NoPrompt
    #>
    [CmdletBinding()]
    param(
        [string]$CurrentVersion = $PSVersionTable.PSVersion.ToString(),
        [switch]$Force,
        [switch]$NoPrompt
    )

    try {
        Write-Host "Checking for PowerShell updates..." -ForegroundColor Cyan

        # Get latest version from GitHub API
        $gitHubApiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        $latestReleaseInfo = Invoke-RestMethod -Uri $gitHubApiUrl
        $latestVersion = $latestReleaseInfo.tag_name.Trim('v')

        Write-Host "Current version: $CurrentVersion" -ForegroundColor Yellow
        Write-Host "Latest version: $latestVersion" -ForegroundColor Yellow

        $updateNeeded = $Force -or ($CurrentVersion -lt $latestVersion)

        if ($updateNeeded) {
            if (-not $NoPrompt) {
                $confirmation = Read-Host "Do you want to update PowerShell? (y/N)"
                if ($confirmation -ne 'y') {
                    Write-Host "Update cancelled by user." -ForegroundColor Yellow
                    return
                }
            }

            Write-Host "Starting PowerShell update in background..." -ForegroundColor Yellow

            # Start update process detached
            $updateScript = {
                Start-Process powershell.exe -ArgumentList "-NoProfile -Command winget upgrade Microsoft.PowerShell --accept-source-agreements --accept-package-agreements" -WindowStyle Hidden
            }

            Start-Job -ScriptBlock $updateScript | Out-Null
            Write-Host "Update process started in background. You may need to restart your shell when complete." -ForegroundColor Magenta
        }
        else {
            Write-Host "Your PowerShell is up to date." -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to check for PowerShell updates. Error: $_"
        throw
    }
}

function Invoke-WinUtil {
    <#
    .SYNOPSIS
        Invokes Chris Titus's WinUtil script with elevated privileges.

    .DESCRIPTION
        Downloads and executes the WinUtil script from christitus.com/win in an elevated PowerShell session.
        Uses Invoke-ElevatedCommand to ensure the script runs with administrator privileges.

    .NOTES
        Source: https://github.com/ChrisTitusTech/winutil
        Requires: Administrator privileges (will prompt if not running as admin)

    .EXAMPLE
        Invoke-WinUtil
        # Downloads and runs the WinUtil with elevated privileges
    #>
    Invoke-ElevatedCommand { Invoke-RestMethod "https://christitus.com/win" | Invoke-Expression }
}

function Invoke-ElevatedCommand {
    <#
    .SYNOPSIS
        Executes a command with elevated (administrator) privileges.

    .DESCRIPTION
        Ensures a command runs with administrator privileges. If the current session
        is not elevated, it will prompt for elevation using PowerShell's "Run as Administrator".

    .PARAMETER ScriptBlock
        The command to execute as a script block.

    .NOTES
        - If already running as admin, executes the command in the current session
        - If not running as admin, starts a new elevated PowerShell session
        - The new session runs with -NoProfile and -ExecutionPolicy Bypass

    .EXAMPLE
        Invoke-ElevatedCommand { Write-Host "Running as admin" }
        # Executes the script block with administrator privileges

    .EXAMPLE
        Invoke-ElevatedCommand { Install-Module -Name MyModule -Scope AllUsers }
        # Installs a PowerShell module with elevated privileges
    #>
    param([scriptblock]$ScriptBlock)

    if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -Command `"$ScriptBlock`"" -Verb RunAs
        return
    }

    Invoke-Command -ScriptBlock $ScriptBlock
}

function grep {
    <#
    .SYNOPSIS
        Searches for text patterns in files or pipeline input.

    .DESCRIPTION
        A PowerShell implementation of the Unix-like grep command that searches for
        text patterns using regular expressions. Can search either through files in
        a directory or through pipeline input.

    .PARAMETER Pattern
        The regular expression pattern to search for.

    .PARAMETER Path
        Optional. The path to search in. Can be a file or directory. Supports wildcards.
        If not specified, searches through pipeline input instead.

    .PARAMETER CaseSensitive
        Optional. Makes the search case-sensitive. Default is case-insensitive.

    .PARAMETER Context
        Optional. Number of lines to show before and after each match.

    .PARAMETER Recurse
        Optional. Search subdirectories recursively when a directory is specified.

    .EXAMPLE
        grep "error" .\logs -Recurse
        # Recursively searches for "error" in all files in the logs directory

    .EXAMPLE
        Get-Content .\log.txt | grep "error" -Context 2
        # Searches for "error" in log.txt showing 2 lines before and after each match

    .EXAMPLE
        grep "Error" .\*.log -CaseSensitive
        # Case-sensitive search for "Error" in all .log files

    .NOTES
        - Uses Select-String cmdlet for pattern matching
        - Supports both directory/file searching and pipeline input
        - Regular expressions follow .NET regex syntax
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Pattern,

        [Parameter(Position = 1)]
        [string]$Path,

        [switch]$CaseSensitive,

        [ValidateRange(0, 10)]
        [int]$Context = 0,

        [switch]$Recurse
    )

    $selectStringParams = @{
        Pattern       = $Pattern
        CaseSensitive = $CaseSensitive
        Context       = $Context
    }

    try {
        if ($Path) {
            # Handle file/directory search
            if (Test-Path -Path $Path) {
                if ((Get-Item $Path).PSIsContainer) {
                    # Directory search
                    $items = Get-ChildItem -Path $Path -Recurse:$Recurse -File
                    $items | Select-String @selectStringParams
                }
                else {
                    # Single file search
                    Get-Content -Path $Path | Select-String @selectStringParams
                }
            }
            else {
                # Handle wildcards
                Get-ChildItem -Path (Split-Path $Path) -Filter (Split-Path $Path -Leaf) -Recurse:$Recurse -File |
                Select-String @selectStringParams
            }
        }
        else {
            # Handle pipeline input
            $input | Select-String @selectStringParams
        }
    }
    catch {
        Write-Error "Error performing search: $_"
    }
}

function Update-Profile {
    <#
    .SYNOPSIS
        Reloads the PowerShell profile in the current session.

    .DESCRIPTION
        Sources the current user's PowerShell profile, effectively reloading
        all profile configurations, functions, and aliases in the current session.

    .EXAMPLE
        Update-Profile
        # Reloads the PowerShell profile
    #>
    & $profile
}

function Expand-ZipFile {
    <#
    .SYNOPSIS
        Extracts a ZIP file to the current directory.

    .DESCRIPTION
        Extracts the contents of a ZIP file to the current working directory.
        Uses Expand-Archive cmdlet to perform the extraction and provides
        feedback about the operation.

    .PARAMETER File
        The name of the ZIP file to extract. The file must be in the current directory.

    .EXAMPLE
        Expand-ZipFile "example.zip"
        # Extracts example.zip to the current directory

    .NOTES
        - The ZIP file must be in the current working directory
        - Destination is always the current directory ($pwd)
        - Uses built-in Expand-Archive cmdlet for extraction
    #>
    param(
        [Parameter(Mandatory = $true,
            Position = 0,
            HelpMessage = "Name of the ZIP file to extract")]
        [string]$File
    )

    Write-Output("Extracting", $File, "to", $pwd)
    $fullFile = Get-ChildItem -Path $pwd -Filter $File | ForEach-Object { $_.FullName }
    Expand-Archive -Path $fullFile -DestinationPath $pwd
}


## From https://github.com/ChrisTitusTech/powershell-profile/
function Clear-Cache {
    # add clear cache logic here
    Write-Host "Clearing cache..." -ForegroundColor Cyan

    # Clear Windows Prefetch
    Write-Host "Clearing Windows Prefetch..." -ForegroundColor Yellow
    Remove-Item -Path "$env:SystemRoot\Prefetch\*" -Force -ErrorAction SilentlyContinue

    # Clear Windows Temp
    Write-Host "Clearing Windows Temp..." -ForegroundColor Yellow
    Remove-Item -Path "$env:SystemRoot\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

    # Clear User Temp
    Write-Host "Clearing User Temp..." -ForegroundColor Yellow
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue

    # Clear Internet Explorer Cache
    Write-Host "Clearing Internet Explorer Cache..." -ForegroundColor Yellow
    Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*" -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "Cache clearing completed." -ForegroundColor Green
}

function Test-CommandExists {
    param($command)
    $exists = $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
    return $exists
}

# Quick Access to Editing the Profile
function Edit-Profile {
    vim $PROFILE.CurrentUserAllHosts
}

# Network Utilities
function Get-PubIP { (Invoke-WebRequest http://ifconfig.me/ip).Content }

# System Utilities
function admin {
    if ($args.Count -gt 0) {
        $argList = $args -join ' '
        Start-Process wt -Verb runAs -ArgumentList "pwsh.exe -NoExit -Command $argList"
    }
    else {
        Start-Process wt -Verb runAs
    }
}

function df {
    get-volume
}

function sed($file, $find, $replace) {
    (Get-Content $file).replace("$find", $replace) | Set-Content $file
}

function export($name, $value) {
    set-item -force -path "env:$name" -value $value;
}

function pkill($name) {
    Get-Process $name -ErrorAction SilentlyContinue | Stop-Process
}

function pgrep($name) {
    Get-Process $name
}

function head {
    param($Path, $n = 10)
    Get-Content $Path -Head $n
}

function tail {
    param($Path, $n = 10, [switch]$f = $false)
    Get-Content $Path -Tail $n -Wait:$f
}

function trash($path) {
    $fullPath = (Resolve-Path -Path $path).Path

    if (Test-Path $fullPath) {
        $item = Get-Item $fullPath

        if ($item.PSIsContainer) {
            # Handle directory
            $parentPath = $item.Parent.FullName
        }
        else {
            # Handle file
            $parentPath = $item.DirectoryName
        }

        $shell = New-Object -ComObject 'Shell.Application'
        $shellItem = $shell.NameSpace($parentPath).ParseName($item.Name)

        if ($item) {
            $shellItem.InvokeVerb('delete')
            Write-Host "Item '$fullPath' has been moved to the Recycle Bin."
        }
        else {
            Write-Host "Error: Could not find the item '$fullPath' to trash."
        }
    }
    else {
        Write-Host "Error: Item '$fullPath' does not exist."
    }
}

# Custom functions for PSReadLine
Set-PSReadLineOption -AddToHistoryHandler {
    param($line)
    $sensitive = @('password', 'secret', 'token', 'apikey', 'connectionstring')
    $hasSensitive = $sensitive | Where-Object { $line -match $_ }
    return ($null -eq $hasSensitive)
}

function New-SymLink {
    <#
    .SYNOPSIS
        Creates a symbolic link, mimicking the Linux 'ln -s' command.

    .DESCRIPTION
        Creates a symbolic link to a target file or directory. By default, creates
        a symbolic link in the current directory with the same name as the target.
        Supports both files and directories.

    .PARAMETER Target
        The path to the target file or directory that the symbolic link will point to.
        Can be relative or absolute path.

    .PARAMETER Link
        Optional. The path where the symbolic link will be created.
        If not specified, creates the link in the current directory with the same name as the target.

    .PARAMETER Force
        Optional. If specified, overwrites an existing symbolic link at the destination.

    .EXAMPLE
        New-SymLink -Target "~/Documents/file.txt" -Link "~/Desktop/file.txt"
        Creates a symbolic link on the desktop pointing to a file in Documents.

    .EXAMPLE
        New-SymLink -Target "C:\Projects\repo" -Link "C:\workspace\repo" -Force
        Creates a symbolic link to a directory, overwriting if it exists.

    .NOTES
        Requires elevated privileges to create symbolic links by default on Windows.
        Use 'sudo' or run PowerShell as administrator if needed.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Target,

        [Parameter(Position = 1)]
        [string]$Link,

        [switch]$Force
    )

    try {
        # Resolve the target path to absolute path
        $Target = Resolve-Path $Target -ErrorAction Stop | Select-Object -ExpandProperty Path

        # If no link path specified, use the target's name in current directory
        if (-not $Link) {
            $Link = Join-Path (Get-Location) (Split-Path $Target -Leaf)
        }
        # Resolve the link path
        $Link = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Link)

        # Check if target exists
        if (-not (Test-Path $Target)) {
            throw "Target path '$Target' does not exist."
        }

        # Check if link already exists
        if (Test-Path $Link) {
            if ($Force) {
                Remove-Item $Link -Force
            }
            else {
                throw "Link path '$Link' already exists. Use -Force to overwrite."
            }
        }

        # Create the symbolic link
        New-Item -ItemType SymbolicLink -Path $Link -Target $Target | Out-Null
        Write-Host "Created symbolic link: '$Link' -> '$Target'"
    }
    catch {
        Write-Error "Failed to create symbolic link: $_"
        if ($_.Exception.Message -match "Access is denied") {
            Write-Warning "You may need to run PowerShell as Administrator to create symbolic links."
        }
    }
}

# Custom exit function to ensure reliable shell exit
function exit {
    param(
        [Parameter(Position = 0)]
        [int]$Code = 0
    )
    [Environment]::Exit($Code)
}
