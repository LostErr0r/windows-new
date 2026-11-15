# ============================================================
#  System.ps1 — питание и системные параметры
# ============================================================

function Invoke-SystemModule {
    param($Config)
    $cfg = Get-Cfg $Config 'system'
    if (-not (Get-Cfg $cfg 'enabled' $true)) { Write-Log 'Модуль system выключен в конфиге' 'WARN'; return }

    # ---------- Питание ----------
    $plan = [string](Get-Cfg $cfg 'powerPlan' '')
    if ($plan) {
        Invoke-Step "План питания: $plan" {
            switch ($plan.ToLower()) {
                'balanced' { Invoke-External 'powercfg' @('/setactive','381b4222-f694-41f0-9685-ff5bb260df2e') | Out-Null }
                'high'     { Invoke-External 'powercfg' @('/setactive','8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c') | Out-Null }
                'ultimate' {
                    # Схема «Максимальная производительность» скрыта — сначала дублируем её
                    $out = & powercfg /list 2>$null
                    if (-not ($out -match 'e9a42b02-d5df-448d-aa00-03f14749eb61')) {
                        Invoke-External 'powercfg' @('-duplicatescheme','e9a42b02-d5df-448d-aa00-03f14749eb61') | Out-Null
                    }
                    Invoke-External 'powercfg' @('/setactive','e9a42b02-d5df-448d-aa00-03f14749eb61') | Out-Null
                }
                default    { Write-Log "Неизвестный план питания '$plan' (допустимо: balanced, high, ultimate)" 'WARN' }
            }
        }
    }

    $mon = Get-Cfg $cfg 'monitorTimeoutMinutesAC' -1
    if ($mon -ge 0) { Invoke-Step "Отключение экрана (сеть): $mon мин" { Invoke-External 'powercfg' @('/change','monitor-timeout-ac',"$mon") | Out-Null } }
    $slp = Get-Cfg $cfg 'sleepTimeoutMinutesAC' -1
    if ($slp -ge 0) { Invoke-Step "Переход в сон (сеть): $slp мин"   { Invoke-External 'powercfg' @('/change','standby-timeout-ac',"$slp") | Out-Null } }

    if (Get-Cfg $cfg 'disableHibernation' $false) {
        Invoke-Step 'Отключение гибернации' { Invoke-External 'powercfg' @('/hibernate','off') | Out-Null }
    }
    if (Get-Cfg $cfg 'disableFastStartup' $false) {
        Invoke-Step 'Отключение быстрого запуска' {
            Set-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled' 0
        }
    }

    # ---------- Системные параметры ----------
    if (Get-Cfg $cfg 'enableLongPaths' $true) {
        Invoke-Step 'Длинные пути (>260 символов)' {
            Set-RegValue 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' 'LongPathsEnabled' 1
        }
    }
    if (Get-Cfg $cfg 'enableClipboardHistory' $true) {
        Invoke-Step 'История буфера обмена (Win+V)' {
            Set-RegValue 'HKCU:\Software\Microsoft\Clipboard' 'EnableClipboardHistory' 1
        }
    }
    if (Get-Cfg $cfg 'disableStickyKeysShortcut' $true) {
        Invoke-Step 'Отключение залипания клавиш по горячей клавише' {
            Set-RegValue 'HKCU:\Control Panel\Accessibility\StickyKeys' 'Flags' '506' 'String'
            Set-RegValue 'HKCU:\Control Panel\Accessibility\ToggleKeys' 'Flags' '58' 'String'
            Set-RegValue 'HKCU:\Control Panel\Accessibility\Keyboard Response' 'Flags' '122' 'String'
        }
    }
    if (Get-Cfg $cfg 'verboseLogonStatus' $false) {
        Invoke-Step 'Подробные сообщения при входе' {
            Set-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'VerboseStatus' 1
        }
    }
    if (Get-Cfg $cfg 'excludeDriversFromWindowsUpdate' $false) {
        Invoke-Step 'Исключить драйверы из Windows Update' {
            Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' 'ExcludeWUDriversInQualityUpdate' 1
        }
    }
    if (Get-Cfg $cfg 'developerMode' $false) {
        Invoke-Step 'Режим разработчика' {
            Set-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' 'AllowDevelopmentWithoutDevLicense' 1
        }
    }

    $tz = [string](Get-Cfg $cfg 'timeZone' '')
    if ($tz) {
        Invoke-Step "Часовой пояс: $tz" {
            if (Test-DryRun) { Write-Log "tzutil /s `"$tz`"" 'DRY' }
            else {
                try { Set-TimeZone -Id $tz -ErrorAction Stop; Write-Log "Часовой пояс установлен: $tz" 'OK' }
                catch { Write-Log "Часовой пояс '$tz' не найден. Список: tzutil /l" 'ERROR' }
            }
        }
    }
}
