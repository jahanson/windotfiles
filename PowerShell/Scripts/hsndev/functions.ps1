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

function Sync-UserPath {
    # Get current User and Process PATH values
    $userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
    $processPath = $env:PATH

    # Split paths into arrays and remove empty entries
    $userPaths = $userPath.Split(';', [StringSplitOptions]::RemoveEmptyEntries)
    $processPaths = $processPath.Split(';', [StringSplitOptions]::RemoveEmptyEntries)

    # Create HashSet for efficient duplicate checking
    $pathSet = [System.Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )

    # Add system paths first (they come at the end of $env:PATH)
    foreach ($path in $processPaths) {
        $pathSet.Add($path) | Out-Null
    }

    # Add user paths at the beginning
    $newPaths = @()
    foreach ($path in $userPaths) {
        if ($pathSet.Add($path)) {
            $newPaths += $path
        }
    }

    # Combine paths, ensuring user paths come first
    $env:PATH = ($newPaths + $processPaths) -join ';'
}
