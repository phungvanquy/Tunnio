$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
if ($env:GITHUB_ACTIONS -ne 'true' -or -not $IsWindows) {
    throw 'Run this installer test only on a disposable Windows Actions runner.'
}

$installers = @(Get-ChildItem dist -Recurse -Filter '*.exe' -File)
if ($installers.Count -ne 1) { throw "Expected one installer, found $($installers.Count)." }
$scratch = Join-Path $env:RUNNER_TEMP ('tunnio-uninstall-' + [guid]::NewGuid())
$installation = Join-Path $scratch 'Installed App'
$otherProfile = Join-Path $scratch 'Other User'
$redirected = Join-Path $scratch 'Redirected Roaming'
$outside = Join-Path $scratch 'Exported backup'
$profileId = 'S-1-5-21-111111111-222222222-333333333-9999'
$profileKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$profileId"
$userKey = "Registry::HKEY_USERS\$profileId"
$fixtureName = 'Software\TunnioUninstallFixture-' + [guid]::NewGuid()
$fixtureKey = "HKCU:\$fixtureName"
$hiveLoaded = $false
$appProcess = $null
$unrelatedProcess = $null
$blockedProcess = $null
$internetKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
$internetSettings = Get-Item -LiteralPath $internetKey
$savedProxySettings = @{}
foreach ($name in @('ProxyEnable', 'ProxyServer')) {
    if ($internetSettings.GetValueNames() -contains $name) {
        $savedProxySettings[$name] = @($internetSettings.GetValue($name), $internetSettings.GetValueKind($name))
    }
}
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$approvedKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run'
$protocolKeys = @('flclash', 'clashmeta', 'tunnio', 'clash') | ForEach-Object { "HKCU:\Software\Classes\$_" }
$bases = @(
    [Environment]::GetFolderPath('ApplicationData'),
    [Environment]::GetFolderPath('LocalApplicationData'),
    (Join-Path $otherProfile 'AppData\Roaming'),
    (Join-Path $otherProfile 'AppData\Local'),
    $redirected
)
$dataDirectories = @($bases | ForEach-Object { Join-Path $_ 'com.follow\clash' })
foreach ($path in @($dataDirectories) + @($protocolKeys) + @($profileKey, $userKey)) {
    if (Test-Path -LiteralPath $path) { throw "Test requires an unused path: $path" }
}
if (Get-ItemProperty -LiteralPath $runKey -Name FlClash -ErrorAction SilentlyContinue) {
    throw 'A real startup registration is present.'
}

function Invoke-Installer([string] $Executable, [string[]] $Arguments) {
    $process = Start-Process -FilePath $Executable -ArgumentList $Arguments -Wait -PassThru
    if ($process.ExitCode -ne 0) { throw "Installer exited with $($process.ExitCode)." }
}

function Set-TestRegistrations([string] $Executable) {
    foreach ($key in $protocolKeys) {
        New-Item -Path "$key\shell\open\command" -Force | Out-Null
        $owner = if ($key.EndsWith('\clash')) { 'C:\OtherApp\Other.exe' } else { $Executable }
        Set-Item -Path "$key\shell\open\command" -Value "`"$owner`" `"%1`""
    }
    if (-not (Test-Path -LiteralPath $runKey)) { New-Item -Path $runKey -Force | Out-Null }
    New-ItemProperty -Path $runKey -Name FlClash -Value $Executable -Force | Out-Null
    New-Item -Path $approvedKey -Force | Out-Null
    New-ItemProperty -Path $approvedKey -Name FlClash -PropertyType Binary -Value ([byte[]](2, 0, 0, 0)) -Force | Out-Null
}

function Read-BootStage {
    foreach ($directory in $dataDirectories[0..1]) {
        $path = Join-Path $directory 'shared_preferences.json'
        if (-not (Test-Path -LiteralPath $path)) { continue }
        try {
            $preferences = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable
            if ($preferences.ContainsKey('flutter.boot_record')) {
                return ($preferences['flutter.boot_record'] | ConvertFrom-Json).stage
            }
        } catch { }
    }
    return $null
}

function Start-TestApp([string] $Executable) {
    $script:appProcess = Start-Process -FilePath $Executable -PassThru
    $deadline = [DateTime]::UtcNow.AddSeconds(45)
    while ((Read-BootStage) -ne 'running') {
        if ($script:appProcess.HasExited) { throw 'The installed app exited during startup.' }
        if ([DateTime]::UtcNow -ge $deadline) { throw 'The installed app did not finish startup.' }
        Start-Sleep -Milliseconds 100
    }
    New-ItemProperty -Path $internetKey -Name ProxyServer -PropertyType String -Value '127.0.0.1:7890' -Force | Out-Null
    New-ItemProperty -Path $internetKey -Name ProxyEnable -PropertyType DWord -Value 1 -Force | Out-Null
    [InstallerProxyFixture]::Refresh()
}

function Assert-AppStopped {
    if (-not $script:appProcess.WaitForExit(5000)) { throw 'The installer left the app running.' }
    if ($script:appProcess.ExitCode -ne 0) { throw 'The app did not exit cleanly.' }
    if ((Get-ItemPropertyValue -LiteralPath $internetKey -Name ProxyEnable) -ne 0) {
        throw 'Application exit left the system proxy enabled.'
    }
    if ($unrelatedProcess.HasExited) { throw 'The installer killed another installation with the same image name.' }
}

function Start-BlockingApp([string] $Path) {
    Copy-Item -LiteralPath "$env:SystemRoot\System32\PING.EXE" -Destination $Path -Force
    return Start-Process -FilePath $Path -ArgumentList @('-n', '600', '127.0.0.1') -WindowStyle Hidden -PassThru
}

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class InstallerProxyFixture {
    [DllImport("wininet.dll", SetLastError = true)]
    private static extern bool InternetSetOption(IntPtr handle, int option, IntPtr buffer, int size);
    public static void Refresh() {
        InternetSetOption(IntPtr.Zero, 39, IntPtr.Zero, 0);
        InternetSetOption(IntPtr.Zero, 37, IntPtr.Zero, 0);
    }
}
'@

try {
    New-Item -ItemType Directory -Path $scratch, $outside -Force | Out-Null
    $export = Join-Path $outside 'keep.yaml'
    Set-Content -LiteralPath $export -Value 'user export'
    $arguments = @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', "/DIR=`"$installation`"")
    Invoke-Installer $installers[0].FullName $arguments
    $executable = Join-Path $installation 'Tunnio.exe'
    if (-not (Test-Path -LiteralPath $executable)) { throw 'The app was not installed.' }
    $legacyExecutable = Join-Path $installation 'FlClash.exe'
    foreach ($name in @('FlClash.exe', 'FlClashCore.exe', 'FlClashHelperService.exe')) {
        Copy-Item -LiteralPath (Join-Path $installation $name.Replace('FlClash', 'Tunnio')) -Destination (Join-Path $installation $name)
    }
    foreach ($path in $dataDirectories) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $path 'shared_preferences.json') -Value '{}'
        New-Item -ItemType Directory -Path (Join-Path $path 'profiles\generations') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $path 'profiles\generations\saved.yaml') -Value 'saved profile'
    }
    $config = @{
        appSettingProps = @{ silentLaunch = $true; minimizeOnExit = $true; autoCheckUpdate = $false }
        networkProps = @{ systemProxy = $false }
        patchClashConfig = @{ tun = @{ enable = $false } }
    } | ConvertTo-Json -Depth 8 -Compress
    foreach ($directory in $dataDirectories[0..1]) {
        @{ 'flutter.config' = $config } | ConvertTo-Json -Compress |
            Set-Content -LiteralPath (Join-Path $directory 'shared_preferences.json')
    }
    $unrelatedProcess = Start-BlockingApp (Join-Path $outside 'Tunnio.exe')
    $sibling = Join-Path $bases[0] 'com.follow\OtherApp'
    New-Item -ItemType Directory -Path $sibling -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $sibling 'keep.txt') -Value 'other app'
    New-Item -ItemType Junction -Path (Join-Path $dataDirectories[0] 'export-link') -Target $outside | Out-Null
    New-Item -Path $profileKey -Force | Out-Null
    New-ItemProperty -Path $profileKey -Name ProfileImagePath -Value $otherProfile | Out-Null
    $folders = "$fixtureKey\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders"
    New-Item -Path $folders -Force | Out-Null
    New-ItemProperty -Path $folders -Name AppData -Value $redirected | Out-Null
    $hiveFile = Join-Path $scratch 'fixture.dat'
    & reg.exe save "HKCU\$fixtureName" $hiveFile /y
    if ($LASTEXITCODE -ne 0) { throw 'Could not save the isolated test registry hive.' }
    & reg.exe load "HKU\$profileId" $hiveFile
    if ($LASTEXITCODE -ne 0) { throw 'Could not load the isolated test registry hive.' }
    $hiveLoaded = $true

    $blockedProcess = Start-BlockingApp $legacyExecutable
    $refusedUpgrade = Start-Process -FilePath $installers[0].FullName -ArgumentList $arguments -Wait -PassThru
    if ($refusedUpgrade.ExitCode -eq 0) { throw 'Upgrade ignored an app that could not shut down.' }
    if ($blockedProcess.HasExited) { throw 'Upgrade force-killed an unresponsive app.' }
    foreach ($path in $dataDirectories) {
        if (-not (Test-Path (Join-Path $path 'profiles\generations\saved.yaml'))) {
            throw "Aborted upgrade deleted saved data: $path"
        }
    }
    Stop-Process -Id $blockedProcess.Id -Force
    $blockedProcess.WaitForExit()
    Copy-Item -LiteralPath $executable -Destination $legacyExecutable -Force
    Start-TestApp $executable
    Set-TestRegistrations $legacyExecutable
    Invoke-Installer $installers[0].FullName $arguments
    Assert-AppStopped
    if ($null -ne (Read-BootStage)) { throw 'Upgrade skipped the application exit coordinator.' }
    if ((Get-ItemPropertyValue -LiteralPath $runKey -Name FlClash) -ne $executable) {
        throw 'Upgrade did not migrate the startup executable.'
    }
    foreach ($key in $protocolKeys[0..2]) {
        if ((Get-Item -LiteralPath "$key\shell\open\command").GetValue('') -ne "`"$executable`" `"%1`"") {
            throw "Upgrade did not migrate protocol: $key"
        }
    }
    foreach ($name in @('FlClash.exe', 'FlClashCore.exe', 'FlClashHelperService.exe')) {
        if (Test-Path -LiteralPath (Join-Path $installation $name)) { throw "Upgrade retained legacy binary: $name" }
    }
    foreach ($path in $dataDirectories) {
        if (-not (Test-Path (Join-Path $path 'profiles\generations\saved.yaml'))) {
            throw "Upgrade deleted saved data: $path"
        }
    }
    $uninstaller = @(Get-ChildItem -LiteralPath $installation -Filter 'unins*.exe')
    if ($uninstaller.Count -ne 1) { throw 'Expected one uninstaller.' }
    $blockedProcess = Start-BlockingApp $legacyExecutable
    $refusedUninstall = Start-Process -FilePath $uninstaller[0].FullName -ArgumentList @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART') -Wait -PassThru
    if ($blockedProcess.HasExited) { throw 'Uninstall force-killed an unresponsive app.' }
    if (-not (Test-Path -LiteralPath $executable)) { throw 'Aborted uninstall removed the executable.' }
    foreach ($path in $dataDirectories) {
        if (-not (Test-Path (Join-Path $path 'profiles\generations\saved.yaml'))) {
            throw "Aborted uninstall deleted saved data: $path"
        }
    }
    Stop-Process -Id $blockedProcess.Id -Force
    $blockedProcess.WaitForExit()
    Remove-Item -LiteralPath $legacyExecutable
    Start-TestApp $executable
    Set-TestRegistrations $executable
    Invoke-Installer $uninstaller[0].FullName @('/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', "/LOG=`"$scratch\uninstall.log`"")
    Assert-AppStopped
    foreach ($path in $dataDirectories) {
        if (Test-Path -LiteralPath $path) { throw "Uninstall retained app data: $path" }
    }
    if (Test-Path -LiteralPath $executable) { throw 'Uninstall retained the executable.' }
    if (-not (Test-Path -LiteralPath $export)) { throw 'Uninstall followed a junction into an export.' }
    if (-not (Test-Path (Join-Path $sibling 'keep.txt'))) { throw 'Uninstall deleted another app.' }
    foreach ($key in $protocolKeys[0..2]) {
        if (Test-Path -LiteralPath $key) { throw "Uninstall retained protocol: $key" }
    }
    if (-not (Test-Path -LiteralPath $protocolKeys[3])) { throw 'Uninstall deleted another protocol owner.' }
    foreach ($key in @($runKey, $approvedKey)) {
        if (Get-ItemProperty -LiteralPath $key -Name FlClash -ErrorAction SilentlyContinue) {
            throw "Uninstall retained startup registration: $key"
        }
    }
    Write-Output 'Windows install, graceful shutdown, proxy cleanup, upgrade preservation, and uninstall cleanup passed.'
}
finally {
    foreach ($process in @($appProcess, $unrelatedProcess, $blockedProcess)) {
        if ($null -ne $process -and -not $process.HasExited) {
            Stop-Process -Id $process.Id -Force
            $process.WaitForExit()
        }
    }
    foreach ($name in @('ProxyEnable', 'ProxyServer')) {
        if ($savedProxySettings.ContainsKey($name)) {
            $setting = $savedProxySettings[$name]
            New-ItemProperty -Path $internetKey -Name $name -Value $setting[0] -PropertyType $setting[1] -Force | Out-Null
        } else {
            Remove-ItemProperty -LiteralPath $internetKey -Name $name -ErrorAction SilentlyContinue
        }
    }
    [InstallerProxyFixture]::Refresh()
    if ($hiveLoaded) {
        & reg.exe unload "HKU\$profileId"
        if ($LASTEXITCODE -ne 0) { Write-Warning 'Could not unload the isolated test registry hive.' }
    }
    foreach ($key in @($profileKey, $fixtureKey) + @($protocolKeys)) {
        if (Test-Path -LiteralPath $key) { Remove-Item -LiteralPath $key -Recurse -Force }
    }
}
