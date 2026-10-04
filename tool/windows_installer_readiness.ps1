function Reset-AppReadiness([string[]] $PreferencePaths) {
    foreach ($path in $PreferencePaths) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $preferences = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
        $preferences.Remove('flutter.sharedState') | Out-Null
        $preferences | ConvertTo-Json -Depth 100 -Compress | Set-Content -LiteralPath $path
    }
}

function Test-AppReady([string[]] $PreferencePaths) {
    foreach ($path in $PreferencePaths) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        try {
            $preferences = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
            $sharedState = $preferences['flutter.sharedState']
            if ($sharedState -is [string] -and
                ($sharedState | ConvertFrom-Json -AsHashtable) -is [System.Collections.IDictionary]) {
                return $true
            }
        } catch { }
    }
    return $false
}

function Wait-AppReady(
    [System.Diagnostics.Process] $Process,
    [string[]] $PreferencePaths,
    [int] $TimeoutSeconds = 45
) {
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        if ($Process.HasExited) { throw "The installed app exited during startup (exit code $($Process.ExitCode))." }
        if (Test-AppReady $PreferencePaths) { return }
        if ($timer.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
            throw "The installed app did not publish startup state within $TimeoutSeconds seconds. Checked: $($PreferencePaths -join ', ')"
        }
        Start-Sleep -Milliseconds 100
    }
}
