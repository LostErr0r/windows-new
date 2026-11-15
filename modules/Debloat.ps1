# ============================================================
#  Debloat.ps1 — удаление встроенных приложений
# ============================================================

function Remove-AppxSafe {
    param([Parameter(Mandatory)][string]$Name)

    try {
        $installed   = @(Get-AppxPackage -AllUsers -Name $Name -ErrorAction Stop)
        $provisioned = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop | Where-Object { $_.DisplayName -like $Name })
    } catch {
        Write-Log "$Name — не удалось получить список пакетов (нужны права администратора?): $($_.Exception.Message.Trim())" 'ERROR'
        return
    }

    if ($installed.Count -eq 0 -and $provisioned.Count -eq 0) {
        Write-Log "$Name — не установлено, пропуск"
        return
    }
    if (Test-DryRun) { Write-Log "appx remove $Name (установлено: $($installed.Count), provisioned: $($provisioned.Count))" 'DRY'; return }

    foreach ($p in $installed) {
        try {
            Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Stop
            Write-Log "$($p.Name) удалён для всех пользователей" 'OK'
        } catch { Write-Log "$($p.Name) — не удалось удалить: $($_.Exception.Message)" 'WARN' }
    }
    foreach ($p in $provisioned) {
        try {
            Remove-AppxProvisionedPackage -Online -PackageName $p.PackageName -ErrorAction Stop | Out-Null
            Write-Log "$($p.DisplayName) удалён из образа (не будет ставиться новым пользователям)" 'OK'
        } catch { Write-Log "$($p.DisplayName) — не удалось удалить provisioned: $($_.Exception.Message)" 'WARN' }
    }
}

function Remove-OneDriveSafe {
    $exe = @("$env:SystemRoot\System32\OneDriveSetup.exe", "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (Test-DryRun) { Write-Log "OneDrive uninstall ($exe)" 'DRY'; return }

    Stop-Process -Name OneDrive -Force -ErrorAction SilentlyContinue
    $done = $false
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        $code = Invoke-External 'winget' @('uninstall','--id','Microsoft.OneDrive','-e','--silent','--accept-source-agreements','--disable-interactivity')
        $done = ($code -eq 0)
    }
    if (-not $done -and $exe) {
        Invoke-External $exe @('/uninstall') | Out-Null
        $done = $true
    }
    if ($done) {
        # Убираем OneDrive из боковой панели Проводника
        Set-RegValue 'HKCU:\Software\Classes\CLSID\{018D5C66-4533-4307-9B53-224DE2ED1FE6}' 'System.IsPinnedToNameSpaceTree' 0
        Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' 'DisableFileSyncNGSC' 1
        Write-Log 'OneDrive удалён' 'OK'
    } else {
        Write-Log 'OneDrive: установщик не найден, удаление пропущено' 'WARN'
    }
}

function Invoke-DebloatModule {
    param($Config)
    $cfg = Get-Cfg $Config 'debloat'
    if (-not (Get-Cfg $cfg 'enabled' $true)) { Write-Log 'Модуль debloat выключен в конфиге' 'WARN'; return }

    $apps = @(Get-Cfg $cfg 'apps' @())
    if ($apps.Count -gt 0) {
        Invoke-Step "Удаление $($apps.Count) встроенных приложений" {
            foreach ($a in $apps) { if ($a) { Remove-AppxSafe -Name $a } }
        }
    }

    if (Get-Cfg $cfg 'removeOneDrive' $false) {
        Invoke-Step 'Удаление OneDrive' { Remove-OneDriveSafe }
    }
}
