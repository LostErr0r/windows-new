# ============================================================
#  Explorer.ps1 — Проводник, панель задач, внешний вид
# ============================================================

function Invoke-ExplorerModule {
    param($Config)
    $cfg = Get-Cfg $Config 'explorer'
    if (-not (Get-Cfg $cfg 'enabled' $true)) { Write-Log 'Модуль explorer выключен в конфиге' 'WARN'; return }

    $ADV = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    $EXP = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer'

    Invoke-Step 'Проводник' {
        if (Get-Cfg $cfg 'showFileExtensions' $true)    { Set-RegValue $ADV 'HideFileExt' 0 }
        if (Get-Cfg $cfg 'showHiddenFiles' $true)       { Set-RegValue $ADV 'Hidden' 1 }
        if (Get-Cfg $cfg 'openExplorerToThisPC' $true)  { Set-RegValue $ADV 'LaunchTo' 1 }
        if (Get-Cfg $cfg 'hideRecentFilesInExplorer' $false) {
            Set-RegValue $EXP 'ShowRecent' 0
            Set-RegValue $EXP 'ShowFrequent' 0
            Set-RegValue $EXP 'ShowCloudFilesInQuickAccess' 0
            Set-RegValue $ADV 'Start_TrackDocs' 0
        }
        if (Get-Cfg $cfg 'classicContextMenu' $true) {
            Set-RegValue 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32' '(Default)' '' 'String'
        }
        if (Get-Cfg $cfg 'compactView' $false)   { Set-RegValue $ADV 'UseCompactMode' 1 }
        if (Get-Cfg $cfg 'hideStatusBar' $false) { Set-RegValue $ADV 'ShowStatusBar' 0 }
    }

    # Левая панель Проводника и значки рабочего стола (как в «Explorer config.bat»)
    Invoke-Step 'Левая панель Проводника' {
        $CLS = 'HKCU:\Software\Classes\CLSID'
        $pin = 'System.IsPinnedToNameSpaceTree'
        $clsidHome    = '{f874310e-b6b7-47dc-bc84-b9e6b38f5903}'
        $clsidGallery = '{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}'
        $clsidNetwork = '{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}'
        $clsidRecycle = '{645FF040-5081-101B-9F08-00AA002F954E}'
        if (Get-Cfg $cfg 'hideHomeInNavPane' $false)       { Set-RegValue "$CLS\$clsidHome"    $pin 0 }
        if (Get-Cfg $cfg 'hideGalleryInNavPane' $false)    { Set-RegValue "$CLS\$clsidGallery" $pin 0 }
        if (Get-Cfg $cfg 'hideNetworkInNavPane' $false)    { Set-RegValue "$CLS\$clsidNetwork" $pin 0 }
        if (Get-Cfg $cfg 'showRecycleBinInNavPane' $false) { Set-RegValue "$CLS\$clsidRecycle" $pin 1 }
        if (Get-Cfg $cfg 'hideDesktopRecycleBin' $false) {
            Set-RegValue "$EXP\HideDesktopIcons\NewStartPanel" $clsidRecycle 1
        }
    }

    if (Get-Cfg $cfg 'darkTheme' $true) {
        Invoke-Step 'Тёмная тема' {
            $k = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
            Set-RegValue $k 'AppsUseLightTheme' 0
            Set-RegValue $k 'SystemUsesLightTheme' 0
        }
    }

    Invoke-Step 'Панель задач' {
        if (Get-Cfg $cfg 'taskbarAlignLeft' $false)      { Set-RegValue $ADV 'TaskbarAl' 0 }
        if (Get-Cfg $cfg 'hideTaskView' $true)           { Set-RegValue $ADV 'ShowTaskViewButton' 0 }
        if (Get-Cfg $cfg 'hideWidgets' $true) {
            Set-RegValue $ADV 'TaskbarDa' 0
            Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0
        }
        if (Get-Cfg $cfg 'hideChat' $true)               { Set-RegValue $ADV 'TaskbarMn' 0 }
        if (Get-Cfg $cfg 'hideCopilotButton' $true)      { Set-RegValue $ADV 'ShowCopilotButton' 0 }
        if (Get-Cfg $cfg 'showSecondsInClock' $false)    { Set-RegValue $ADV 'ShowSecondsInSystemClock' 1 }
        if (Get-Cfg $cfg 'endTaskInTaskbar' $true)       { Set-RegValue "$ADV\TaskbarDeveloperSettings" 'TaskbarEndTask' 1 }

        $search = [string](Get-Cfg $cfg 'taskbarSearch' '')
        $mode = switch ($search.ToLower()) {
            'hidden'    { 0 }
            'icon'      { 1 }
            'box'       { 2 }
            'iconlabel' { 3 }
            default     { $null }
        }
        if ($null -ne $mode) { Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode' $mode }
    }

    Invoke-Step 'Меню Пуск' {
        if (Get-Cfg $cfg 'disableStartRecommendations' $true) {
            Set-RegValue $ADV 'Start_IrisRecommendations' 0
            Set-RegValue $ADV 'Start_TrackDocs' 0
        }
        if (Get-Cfg $cfg 'showMorePinsInStart' $false)   { Set-RegValue $ADV 'Start_Layout' 1 }
    }
}
