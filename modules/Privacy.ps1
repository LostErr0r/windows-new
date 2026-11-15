# ============================================================
#  Privacy.ps1 — приватность, телеметрия, реклама, Copilot
# ============================================================

function Invoke-PrivacyModule {
    param($Config)
    $cfg = Get-Cfg $Config 'privacy'
    if (-not (Get-Cfg $cfg 'enabled' $true)) { Write-Log 'Модуль privacy выключен в конфиге' 'WARN'; return }

    $CDM = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'

    if (Get-Cfg $cfg 'disableTelemetry' $true) {
        Invoke-Step 'Телеметрия и диагностика' {
            Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0
            Set-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection' 'AllowTelemetry' 0
            Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'DoNotShowFeedbackNotifications' 1
            Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat' 'AITEnable' 0            # инвентаризация приложений
            Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat' 'DisableInventory' 1
            Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows' 'CEIPEnable' 0           # Программа улучшения качества
            Disable-ServiceSafe 'DiagTrack'
            Disable-ServiceSafe 'dmwappushservice'
            foreach ($t in @(
                '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
                '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
                '\Microsoft\Windows\Application Experience\StartupAppTask',
                '\Microsoft\Windows\Autochk\Proxy',
                '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
                '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
                '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector',
                '\Microsoft\Windows\Feedback\Siuf\DmClient',
                '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload'
            )) { Disable-TaskSafe $t }
        }
    }

    if (Get-Cfg $cfg 'disableAdvertisingId' $true) {
        Invoke-Step 'Рекламный идентификатор' {
            Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0
            Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' 'DisabledByGroupPolicy' 1
        }
    }

    if (Get-Cfg $cfg 'disableTailoredExperiences' $true) {
        Invoke-Step 'Персонализированные возможности' {
            Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 0
            Set-RegValue 'HKCU:\Software\Policies\Microsoft\Windows\CloudContent' 'DisableTailoredExperiencesWithDiagnosticData' 1
        }
    }

    if (Get-Cfg $cfg 'disableActivityHistory' $true) {
        Invoke-Step 'Журнал действий' {
            $k = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
            Set-RegValue $k 'EnableActivityFeed' 0
            Set-RegValue $k 'PublishUserActivities' 0
            Set-RegValue $k 'UploadUserActivities' 0
        }
    }

    if (Get-Cfg $cfg 'disableFeedbackRequests' $true) {
        Invoke-Step 'Запросы отзывов' {
            Set-RegValue 'HKCU:\Software\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' 0
            Remove-RegValue 'HKCU:\Software\Microsoft\Siuf\Rules' 'PeriodInNanoSeconds'
        }
    }

    if (Get-Cfg $cfg 'disableSuggestionsAndAds' $true) {
        Invoke-Step 'Советы, реклама и предложения' {
            foreach ($n in @(
                'ContentDeliveryAllowed','SilentInstalledAppsEnabled','PreInstalledAppsEnabled','OemPreInstalledAppsEnabled',
                'PreInstalledAppsEverEnabled','SoftLandingEnabled','SystemPaneSuggestionsEnabled','RotatingLockScreenOverlayEnabled',
                'SubscribedContent-310093Enabled','SubscribedContent-338387Enabled','SubscribedContent-338388Enabled',
                'SubscribedContent-338389Enabled','SubscribedContent-338393Enabled','SubscribedContent-353694Enabled',
                'SubscribedContent-353696Enabled','SubscribedContent-353698Enabled'
            )) { Set-RegValue $CDM $n 0 }
            Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1   # авто-установка «рекомендуемых» приложений
            Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableSoftLanding' 1
            Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\UserProfileEngagement' 'ScoobeSystemSettingEnabled' 0  # «Завершим настройку устройства»
            Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowSyncProviderNotifications' 0  # реклама OneDrive в Проводнике
        }
    }

    if (Get-Cfg $cfg 'disableCortana' $true) {
        Invoke-Step 'Cortana' {
            Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'AllowCortana' 0
            Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'CortanaConsent' 0
        }
    }

    if (Get-Cfg $cfg 'disableBingInSearch' $true) {
        Invoke-Step 'Поиск Bing в меню Пуск' {
            Set-RegValue 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1
            Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' 0
            Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'DisableWebSearch' 1
            Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' 'ConnectedSearchUseWeb' 0
        }
    }

    if (Get-Cfg $cfg 'disableCopilot' $true) {
        Invoke-Step 'Windows Copilot' {
            Set-RegValue 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
            Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1
            Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowCopilotButton' 0
        }
    }

    if (Get-Cfg $cfg 'disableRecall' $true) {
        Invoke-Step 'Recall (ИИ-снимки экрана)' {
            Set-RegValue 'HKCU:\Software\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 1
            Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 1
            Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'AllowRecallEnablement' 0
        }
    }

    if (Get-Cfg $cfg 'disableLocation' $false) {
        Invoke-Step 'Геолокация' {
            Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' 'DisableLocation' 1
            Set-RegValue 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' 'Value' 'Deny' 'String'
        }
    }
}
