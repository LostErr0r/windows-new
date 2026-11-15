# ============================================================
#  Menu.ps1 — интерактивный выбор пунктов внутри каждого модуля
#  (список с галочками: что установить / что применить)
# ============================================================

# Человеческие названия для ключей config.json и имён пакетов
function Get-ItemLabels {
    return @{
        apps = @{
            winget          = 'Через winget'
            local           = 'С диска (WatchThisFolder)'
            manual          = 'Вручную — показать подсказку и ссылку'
            openManualLinks = 'Открыть ссылки ручных шагов в браузере'
            installRoot     = 'Ставить программы в папку (выкл. = по умолчанию на C:)'
        }
        privacy = @{
            disableTelemetry           = 'Телеметрия и диагностика (DiagTrack, задачи сбора данных)'
            disableAdvertisingId       = 'Рекламный идентификатор'
            disableTailoredExperiences = '«Персонализированные возможности» на основе диагностики'
            disableActivityHistory     = 'Журнал действий / временная шкала'
            disableFeedbackRequests    = 'Запросы «Оцените Windows»'
            disableSuggestionsAndAds   = 'Советы, реклама, авто-установка «рекомендуемых» приложений'
            disableCortana             = 'Cortana'
            disableBingInSearch        = 'Поиск Bing в меню Пуск'
            disableCopilot             = 'Windows Copilot'
            disableRecall              = 'Recall (ИИ-снимки экрана)'
            disableLocation            = 'Геолокация — выключить полностью'
        }
        debloat = @{
            apps           = 'Встроенные приложения'
            removeOneDrive = 'OneDrive'
            'Microsoft.549981C3F5F10'            = 'Cortana'
            'Microsoft.BingNews'                 = 'Новости (Bing)'
            'Microsoft.BingWeather'              = 'Погода (Bing)'
            'Microsoft.BingSearch'               = 'Поиск Bing'
            'Microsoft.Copilot'                  = 'Copilot (приложение)'
            'Microsoft.GamingApp'                = 'Xbox'
            'Microsoft.Xbox.TCUI'                = 'Xbox TCUI'
            'Microsoft.XboxGameOverlay'          = 'Xbox Game Overlay'
            'Microsoft.XboxGamingOverlay'        = 'Игровая панель Xbox (Win+G)'
            'Microsoft.XboxIdentityProvider'     = 'Xbox Identity Provider (вход в игры Store)'
            'Microsoft.XboxSpeechToTextOverlay'  = 'Xbox Speech-to-Text'
            'Microsoft.GetHelp'                  = 'Получить справку'
            'Microsoft.Getstarted'               = 'Советы'
            'Microsoft.MicrosoftOfficeHub'       = 'Office Hub'
            'Microsoft.MicrosoftSolitaireCollection' = 'Пасьянс (Solitaire)'
            'Microsoft.People'                   = 'Люди'
            'Microsoft.PowerAutomateDesktop'     = 'Power Automate Desktop'
            'Microsoft.Todos'                    = 'Microsoft To Do'
            'Microsoft.WindowsFeedbackHub'       = 'Центр отзывов'
            'Microsoft.WindowsMaps'              = 'Карты'
            'Microsoft.MixedReality.Portal'      = 'Mixed Reality Portal'
            'Microsoft.SkypeApp'                 = 'Skype'
            'Microsoft.YourPhone'                = 'Связь с телефоном'
            'Microsoft.ZuneMusic'                = 'Media Player'
            'Microsoft.ZuneVideo'                = 'Кино и ТВ'
            'Microsoft.OutlookForWindows'        = 'Outlook (новый)'
            'Microsoft.Windows.DevHome'          = 'Dev Home'
            'MicrosoftTeams'                     = 'Teams (старый)'
            'MSTeams'                            = 'Teams (новый)'
            'Clipchamp.Clipchamp'                = 'Clipchamp'
            'microsoft.windowscommunicationsapps' = 'Почта и Календарь'
        }
        explorer = @{
            showFileExtensions          = 'Показывать расширения файлов'
            showHiddenFiles             = 'Показывать скрытые файлы'
            openExplorerToThisPC        = 'Проводник открывается на «Этот компьютер»'
            classicContextMenu          = 'Классическое контекстное меню (Win 10)'
            hideRecentFilesInExplorer   = 'Скрыть недавние/частые файлы на главной'
            darkTheme                   = 'Тёмная тема Windows'
            compactView                 = 'Компактный вид Проводника'
            hideStatusBar               = 'Скрыть строку состояния'
            hideHomeInNavPane           = 'Убрать «Главная» из левой панели'
            hideGalleryInNavPane        = 'Убрать «Галерея» из левой панели'
            hideNetworkInNavPane        = 'Убрать «Сеть» из левой панели'
            showRecycleBinInNavPane     = 'Показать «Корзина» в левой панели'
            hideDesktopRecycleBin       = 'Убрать корзину с рабочего стола'
            taskbarAlignLeft            = 'Кнопки панели задач слева'
            taskbarSearch               = 'Поиск на панели задач'
            hideTaskView                = 'Скрыть «Представление задач»'
            hideWidgets                 = 'Скрыть виджеты'
            hideChat                    = 'Скрыть «Чат»'
            hideCopilotButton           = 'Скрыть кнопку Copilot'
            showSecondsInClock          = 'Секунды в часах'
            endTaskInTaskbar            = '«Завершить задачу» в меню панели задач'
            disableStartRecommendations = 'Убрать «Рекомендуем» в Пуске'
            showMorePinsInStart         = 'Больше закреплённых в Пуске'
        }
        system = @{
            powerPlan                       = 'План питания'
            monitorTimeoutMinutesAC         = 'Отключение экрана от сети, мин (0 = никогда)'
            sleepTimeoutMinutesAC           = 'Сон от сети, мин (0 = никогда)'
            disableHibernation              = 'Отключить гибернацию'
            disableFastStartup              = 'Отключить быстрый запуск'
            enableLongPaths                 = 'Длинные пути (> 260 символов)'
            enableClipboardHistory          = 'История буфера обмена (Win+V)'
            disableStickyKeysShortcut       = 'Отключить залипание клавиш по 5×Shift'
            verboseLogonStatus              = 'Подробные сообщения при входе/выходе'
            excludeDriversFromWindowsUpdate = 'Не ставить драйверы через Windows Update'
            developerMode                   = 'Режим разработчика'
            timeZone                        = 'Часовой пояс'
        }
        theme = @{
            cursors               = 'Курсоры W11 by Jepri Creations'
            eject                 = 'Тема EJECT'
            'eject.enabled'       = 'Тема EJECT — ставить'
            'eject.patchUxTheme'  = 'UltraUXThemePatcher (нужен для сторонних тем, затем перезагрузка)'
            'eject.themesFix'     = 'Themes Fix: тема не меняет значки, курсоры и обои'
            'eject.themesService' = 'Служба «Темы»: автозапуск и запуск'
            'eject.apply'         = 'Применить тему (сразу или после перезагрузки)'
        }
    }
}

# Строковые параметры с вариантами — повторный ввод номера переключает по кругу
function Get-ItemChoices {
    return @{
        'explorer.taskbarSearch' = @('icon', 'box', 'iconLabel', 'hidden', '')
        'system.powerPlan'       = @('high', 'balanced', 'ultimate', '')
        'theme.cursors'          = @('dark', 'light', '')
    }
}

function New-CfgItem {
    param([string]$Label, [string]$Note = '', [string]$Group = '', [string]$Kind, [string[]]$Path,
          [int]$Index = -1, $Value = $null, [bool]$On, [bool]$Fixed = $false, [string[]]$Options = @())
    return [pscustomobject]@{
        Label = $Label; Note = $Note; Group = $Group; Kind = $Kind; Path = $Path; Index = $Index
        Value = $Value; Orig = $Value; On = $On; Fixed = $Fixed; Options = $Options
    }
}

# Рекурсивно превращает секцию конфига в список пунктов
function Add-PropertyItems {
    param($List, [string]$Module, $Obj, [string[]]$Prefix, [string]$Group, $Labels, $Choices)
    foreach ($p in $Obj.PSObject.Properties) {
        $key = $p.Name; $v = $p.Value
        if ($key -in @('cursorsFolder', 'folder', 'source')) { continue }
        if ($Prefix.Count -eq 1 -and $key -eq 'enabled') { continue }
        $path  = [string[]]($Prefix + $key)
        $lkey  = (($path | Select-Object -Skip 1) -join '.')
        $label = if ($Labels[$lkey]) { $Labels[$lkey] } else { $key }
        $ckey  = "$Module.$lkey"

        if ($v -is [bool]) {
            $List.Add((New-CfgItem -Label $label -Group $Group -Kind 'bool' -Path $path -Value $v -On $v))
        }
        elseif ($v -is [string]) {
            if ($Choices[$ckey]) {
                $List.Add((New-CfgItem -Label $label -Group $Group -Kind 'choice' -Path $path -Value $v -On ($v -ne '') -Options $Choices[$ckey]))
            } else {
                $List.Add((New-CfgItem -Label $label -Group $Group -Kind 'string' -Path $path -Value $v -On ($v -ne '') -Fixed ($v -eq '')))
            }
        }
        elseif ($v -is [int] -or $v -is [long] -or $v -is [double] -or $v -is [decimal]) {
            $List.Add((New-CfgItem -Label $label -Group $Group -Kind 'int' -Path $path -Value $v -On ($v -ne -1) -Fixed ($v -eq -1)))
        }
        elseif ($v -is [array]) {
            $g = if ($Labels[$lkey]) { $Labels[$lkey] } else { $key }
            for ($i = 0; $i -lt $v.Count; $i++) {
                $e = $v[$i]
                if ($e -is [string]) {
                    $name = if ($Labels[$e]) { $Labels[$e] } else { $e }
                    $note = if ($Labels[$e]) { $e } else { '' }
                    $en = $true
                } else {
                    $id   = [string](Get-Cfg $e 'id' '')
                    $name = [string](Get-Cfg $e 'name' $id)
                    $note = $id
                    $en   = [bool](Get-Cfg $e 'enabled' $true)
                }
                $List.Add((New-CfgItem -Label $name -Note $note -Group $g -Kind 'list' -Path $path -Index $i -On $en))
            }
        }
        elseif ($v -is [System.Management.Automation.PSCustomObject]) {
            $g = if ($Labels[$lkey]) { $Labels[$lkey] } else { $key }
            Add-PropertyItems -List $List -Module $Module -Obj $v -Prefix $path -Group $g -Labels $Labels -Choices $Choices
        }
    }
}

function Get-ModuleItems {
    param([string]$Module, $Config)
    $list = New-Object System.Collections.Generic.List[object]
    $section = Get-Cfg $Config $Module
    if ($null -eq $section) { return @() }
    $labels  = (Get-ItemLabels)[$Module]; if (-not $labels) { $labels = @{} }
    Add-PropertyItems -List $list -Module $Module -Obj $section -Prefix @($Module) -Group '' -Labels $labels -Choices (Get-ItemChoices)
    return @($list.ToArray())
}

# ---------- Применение выбора к копии конфига ----------

function Get-CfgPath {
    param($Obj, [string[]]$Path)
    $o = $Obj
    foreach ($k in $Path) { if ($null -eq $o) { return $null }; $o = $o.PSObject.Properties[$k].Value }
    return $o
}

function Set-CfgPath {
    param($Obj, [string[]]$Path, $Value)
    $o = $Obj
    for ($i = 0; $i -lt $Path.Count - 1; $i++) { $o = $o.PSObject.Properties[$Path[$i]].Value }
    $o | Add-Member -NotePropertyName $Path[-1] -NotePropertyValue $Value -Force
}

function Copy-Config {
    param($Config)
    return ($Config | ConvertTo-Json -Depth 32 | ConvertFrom-Json)
}

function ConvertTo-SelectedConfig {
    param($Config, $Items)
    $clone = Copy-Config $Config
    $lists = [ordered]@{}
    foreach ($it in $Items) {
        switch ($it.Kind) {
            'bool'   { Set-CfgPath $clone $it.Path ([bool]$it.On) }
            'choice' { Set-CfgPath $clone $it.Path ([string]$it.Value) }
            'string' { Set-CfgPath $clone $it.Path $(if ($it.On) { [string]$it.Value } else { '' }) }
            'int'    { Set-CfgPath $clone $it.Path $(if ($it.On) { $it.Value } else { -1 }) }
            'list'   {
                $k = $it.Path -join '/'
                if (-not $lists.Contains($k)) { $lists[$k] = @{ Path = $it.Path; Keep = New-Object System.Collections.Generic.List[int] } }
                if ($it.On) { $lists[$k].Keep.Add($it.Index) }
            }
        }
    }
    foreach ($l in $lists.Values) {
        $orig = @(Get-CfgPath $clone $l.Path)
        $new = New-Object System.Collections.Generic.List[object]
        foreach ($i in $l.Keep) {
            $e = $orig[$i]
            if ($e -isnot [string]) { $e | Add-Member -NotePropertyName 'enabled' -NotePropertyValue $true -Force }
            $new.Add($e)
        }
        Set-CfgPath $clone $l.Path ([object[]]$new.ToArray())
    }
    return $clone
}

# ---------- Интерактивный список с галочками ----------

function Set-ItemOn {
    param($It, [bool]$On)
    if ($It.Fixed) { return }
    switch ($It.Kind) {
        'choice' {
            if ($On) { if ($It.Value -eq '') { $It.Value = @($It.Options | Where-Object { $_ })[0] } }
            else     { $It.Value = '' }
            $It.On = ($It.Value -ne '')
        }
        'int'    { $It.Value = if ($On) { $It.Orig } else { -1 }; $It.On = $On }
        'string' { $It.Value = if ($On) { $It.Orig } else { '' }; $It.On = $On }
        default  { $It.On = $On }
    }
}

function Switch-Item {
    param($Items, [int]$Idx)
    if ($Idx -lt 0 -or $Idx -ge $Items.Count) { return }
    $it = $Items[$Idx]
    if ($it.Fixed) { return }
    if ($it.Kind -eq 'choice') {
        $i = [array]::IndexOf([string[]]$it.Options, [string]$it.Value)
        $it.Value = $it.Options[($i + 1) % $it.Options.Count]
        $it.On = ($it.Value -ne '')
    } else { Set-ItemOn $it (-not $it.On) }
}

function Format-ItemText {
    param($It)
    $text = $It.Label
    switch ($It.Kind) {
        'choice' { $text = "$text : " + $(if ($It.On) { $It.Value } else { 'не менять' }) }
        'int'    { $text = "$text : " + $(if ($It.On) { $It.Value } else { 'не менять' }) }
        'string' { $text = "$text : " + $(if ($It.Fixed) { 'не задано в config.json' } elseif ($It.On) { $It.Value } else { 'не менять' }) }
        default  { if ($It.Note -and $It.Note -ne $It.Label) { $text = "$text  ($($It.Note))" } }
    }
    return $text
}

function Write-ChecklistCell {
    param($Line, [int]$Width)
    if ($Line.Header) {
        $t = "-- $($Line.Header) --"
        if ($t.Length -gt $Width) { $t = $t.Substring(0, $Width) }
        Write-Host $t.PadRight($Width) -NoNewline -ForegroundColor DarkCyan
        return
    }
    $it = $Line.Item
    $mark  = if ($it.Fixed) { '[-]' } elseif ($it.On) { '[x]' } else { '[ ]' }
    $mcol  = if ($it.Fixed) { 'DarkGray' } elseif ($it.On) { 'Green' } else { 'DarkGray' }
    $tcol  = if ($it.Fixed) { 'DarkGray' } elseif ($it.On) { 'White' } else { 'Gray' }
    $body  = ('{0,3}. ' -f $Line.Num) + (Format-ItemText $it)
    $max   = $Width - 4
    if ($body.Length -gt $max) { $body = $body.Substring(0, $max - 1) + '~' }
    Write-Host $mark -NoNewline -ForegroundColor $mcol
    Write-Host (' ' + $body).PadRight($Width - 3) -NoNewline -ForegroundColor $tcol
}

function Write-Checklist {
    param([string]$Title, $Items)
    Write-Host ''
    Write-Host "   $Title" -ForegroundColor Cyan
    Write-Host '   Введите номера, чтобы включить/выключить пункт: 3  или  1,4,7  или  5-12.' -ForegroundColor DarkGray
    Write-Host '   Пункты со значением (dark/light, high/balanced...) переключаются по кругу повторным вводом номера.' -ForegroundColor DarkGray
    Write-Host ''

    $lines = New-Object System.Collections.Generic.List[object]
    $lastGroup = $null
    for ($i = 0; $i -lt $Items.Count; $i++) {
        $it = $Items[$i]
        if ($it.Group -ne $lastGroup -and ($it.Group -or $lastGroup)) {
            $lines.Add(@{ Header = $(if ($it.Group) { $it.Group } else { 'Прочее' }) })
            $lastGroup = $it.Group
        }
        $lines.Add(@{ Item = $it; Num = $i + 1 })
    }
    $width = 120
    try { $w = $Host.UI.RawUI.WindowSize.Width; if ($w -gt 40) { $width = $w } } catch {}
    $cols = if ($lines.Count -gt 16 -and $width -ge 100) { 2 } else { 1 }
    $colW = [math]::Floor(($width - 4) / $cols) - 1
    $rows = [math]::Ceiling($lines.Count / $cols)
    for ($r = 0; $r -lt $rows; $r++) {
        Write-Host '  ' -NoNewline
        for ($c = 0; $c -lt $cols; $c++) {
            $idx = $r + $c * $rows
            if ($idx -lt $lines.Count) { Write-ChecklistCell $lines[$idx] $colW; Write-Host ' ' -NoNewline }
        }
        Write-Host ''
    }
    Write-Host ''
    $on = @($Items | Where-Object { $_.On }).Count
    Write-Host ("   Выбрано: {0} из {1}" -f $on, $Items.Count) -ForegroundColor White
    Write-Host '   [A] все   [N] ничего   [I] инвертировать   [S] ЗАПУСТИТЬ выбранное   [0] назад' -ForegroundColor Yellow
}

# Возвращает $true — запустить с текущим выбором, $false — отмена
function Show-Checklist {
    param([string]$Title, $Items)
    while ($true) {
        Clear-Host
        Write-Checklist -Title $Title -Items $Items
        $inp = (Read-Host '   Ввод').Trim()
        if ($inp -eq '') { continue }
        $u = $inp.ToUpper()
        if ($u -eq '0') { return $false }
        if ($u -eq 'S' -or $u -eq 'Y') { return $true }
        if ($u -eq 'A') { foreach ($it in $Items) { Set-ItemOn $it $true };  continue }
        if ($u -eq 'N') { foreach ($it in $Items) { Set-ItemOn $it $false }; continue }
        if ($u -eq 'I') { foreach ($it in $Items) { Set-ItemOn $it (-not $it.On) }; continue }
        foreach ($tok in ($inp -split '[,;\s]+' | Where-Object { $_ })) {
            if ($tok -match '^(\d+)-(\d+)$') {
                $a = [int]$Matches[1]; $b = [int]$Matches[2]
                if ($a -gt $b) { $t = $a; $a = $b; $b = $t }
                for ($k = $a; $k -le $b; $k++) { Switch-Item $Items ($k - 1) }
            }
            elseif ($tok -match '^\d+$') { Switch-Item $Items ([int]$tok - 1) }
        }
    }
}
