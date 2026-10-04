$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. "$PSScriptRoot/../../tool/windows_installer_readiness.ps1"

function Assert-Equal($Actual, $Expected, [string] $Message) {
    if ($Actual -cne $Expected) { throw "$Message (expected '$Expected', got '$Actual')" }
}

function Assert-Throws([scriptblock] $Action, [string] $Expected) {
    try { & $Action } catch {
        if ($_.Exception.Message -like $Expected) { return }
        throw
    }
    throw "Expected an error matching: $Expected"
}

$scratch = Join-Path ([System.IO.Path]::GetTempPath()) ('tunnio-readiness-' + [guid]::NewGuid())
$paths = @('roaming.json', 'local.json') | ForEach-Object { Join-Path $scratch $_ }
$currentProcess = Get-Process -Id $PID
$writer = $null
$config = '{"appSettingProps":{"silentLaunch":true,"minimizeOnExit":true}}'
$ready = @{ 'flutter.config' = $config; 'flutter.sharedState' = '{"startTip":"Start","stopTip":"Stop"}' } |
    ConvertTo-Json -Compress

try {
    New-Item -ItemType Directory -Path $scratch | Out-Null
    Assert-Equal (Test-AppReady $paths) $false 'Missing preferences must not report readiness'
    Reset-AppReadiness $paths

    Set-Content -LiteralPath $paths[0] -Value '{"flutter.boot_record":"{\"stage\":\"running\"}"}'
    Assert-Equal (Test-AppReady $paths) $false 'An Android boot record must not satisfy Windows startup'
    Assert-Throws { Wait-AppReady $currentProcess $paths -TimeoutSeconds 0 } '*did not publish startup state within 0 seconds*'

    foreach ($path in $paths) { Set-Content -LiteralPath $path -Value $ready }
    Assert-Equal (Test-AppReady $paths) $true 'Windows startup must work without an Android boot record'
    Wait-AppReady $currentProcess $paths -TimeoutSeconds 0
    Reset-AppReadiness $paths
    Assert-Equal (Test-AppReady $paths) $false 'A previous launch must not satisfy the next startup'
    foreach ($path in $paths) {
        $preferences = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
        Assert-Equal $preferences['flutter.config'] $config 'Reset must preserve configuration'
    }

    Set-Content -LiteralPath $paths[0] -Value '{"flutter.sharedState":'
    Set-Content -LiteralPath $paths[1] -Value '{"flutter.sharedState":"{"}'
    Assert-Equal (Test-AppReady $paths) $false 'Partial preference writes must be retried'
    Set-Content -LiteralPath $paths[1] -Value $ready
    Assert-Equal (Test-AppReady $paths) $true 'A malformed file must not hide another valid preference path'

    Set-Content -LiteralPath $paths[0] -Value '{}'
    Reset-AppReadiness $paths
    $writer = Start-ThreadJob -ArgumentList $paths[1], $ready -ScriptBlock {
        param($Path, $Contents)
        Start-Sleep -Milliseconds 200
        Set-Content -LiteralPath $Path -Value $Contents
    }
    Wait-AppReady $currentProcess $paths -TimeoutSeconds 10
    $writer | Wait-Job | Receive-Job
    Assert-Equal (Test-AppReady $paths) $true 'Polling must observe delayed startup state'

    $exited = Start-Process -FilePath $currentProcess.Path -ArgumentList @('-NoProfile', '-NonInteractive', '-Command', 'exit 7') -Wait -PassThru
    Assert-Throws { Wait-AppReady $exited $paths -TimeoutSeconds 0 } '*exited during startup (exit code 7)*'
    Write-Output 'Windows installer readiness tests passed.'
}
finally {
    if ($null -ne $writer) { $writer | Remove-Job -Force }
    Remove-Item -LiteralPath $scratch -Recurse -Force
}
