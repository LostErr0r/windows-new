<#
.SYNOPSIS
    WindowsDoProgram — настройка Windows после переустановки.

.DESCRIPTION
    Читает config.json и применяет выбранные модули:
      apps     — установка программ через winget
      privacy  — приватность и телеметрия
      debloat  — удаление встроенных приложений
      explorer — Проводник, панель задач, внешний вид
      theme    — курсоры и тема EJECT из папки WatchThisFolder
      system   — питание, системные параметры

.EXAMPLE
    .\Setup.ps1                       # интерактивное меню
    .\Setup.ps1 -All                  # всё из config.json без вопросов
    .\Setup.ps1 -Modules privacy,explorer
    .\Setup.ps1 -All -DryRun          # только показать, что будет сделано
#>
[CmdletBinding()]
param(
    [switch]$All,
    [ValidateSet('apps','privacy','debloat','explorer','theme','system')]
    [string[]]$Modules,
    [string]$ConfigPath,
    [switch]$NoRestorePoint,
    [switch]$DryRun
)

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

# ---------- Самоповышение до администратора ----------
$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Требуются права администратора. Перезапуск...' -ForegroundColor Yellow
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    foreach ($kv in $PSBoundParameters.GetEnumerator()) {
        if ($kv.Value -is [switch]) { if ($kv.Value) { $argList += "-$($kv.Key)" } }
        else { $argList += "-$($kv.Key)"; $argList += ($kv.Value -join ',') }
    }
    Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList
    exit
}

# ---------- Пути, лог ----------
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root
if (-not $ConfigPath) { $ConfigPath = Join-Path $Root 'config.json' }
$logDir = Join-Path $Root 'logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir | Out-Null }
$Global:WDP_LogFile = Join-Path $logDir ("setup_{0}.log" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
$Global:WDP_DryRun  = [bool]$DryRun
$Global:WDP_Root    = $Root

# ---------- Загрузка модулей ----------
Get-ChildItem -Path (Join-Path $Root 'modules') -Filter '*.ps1' | Sort-Object Name | ForEach-Object { . $_.FullName }

# ---------- Загрузка конфига (JSON с // комментариями) ----------
function Import-Config {
    param([string]$Path)
    if (-not (Test-Path $Path)) { throw "Файл конфигурации не найден: $Path" }
    $raw = Get-Content -Path $Path -Raw -Encoding UTF8
    # убираем // комментарии (целые строки и хвосты строк вне кавычек)
    $lines = $raw -split "`r?`n" | ForEach-Object {
        $line = $_
        if ($line.TrimStart().StartsWith('//')) { return '' }
        $inStr = $false; $cut = -1
        for ($i = 0; $i -lt $line.Length - 1; $i++) {
            $c = $line[$i]
            if ($c -eq '"' -and ($i -eq 0 -or $line[$i-1] -ne '\')) { $inStr = -not $inStr }
            elseif (-not $inStr -and $c -eq '/' -and $line[$i+1] -eq '/') { $cut = $i; break }
        }
        if ($cut -ge 0) { $line.Substring(0, $cut) } else { $line }
    }
    $json = $lines -join "`n"
    # убираем висящие запятые перед ] или }
    $json = [regex]::Replace($json, ',(\s*[\]\}])', '$1')
    try { return $json | ConvertFrom-Json }
    catch { throw "Ошибка разбора config.json: $($_.Exception.Message)" }
}

try { $Config = Import-Config -Path $ConfigPath }
catch { Write-Host $_.Exception.Message -ForegroundColor Red; Read-Host 'Нажмите Enter для выхода'; exit 1 }

# ---------- Карта модулей ----------
$ModuleMap = [ordered]@{
    apps     = @{ Title = 'Установка программ';                     Action = { param($c) Invoke-AppsModule     -Config $c } }
    privacy  = @{ Title = 'Приватность и телеметрия';               Action = { param($c) Invoke-PrivacyModule  -Config $c } }
    debloat  = @{ Title = 'Удаление встроенных приложений';         Action = { param($c) Invoke-DebloatModule  -Config $c } }
    explorer = @{ Title = 'Проводник, панель задач, внешний вид';   Action = { param($c) Invoke-ExplorerModule -Config $c } }
    theme    = @{ Title = 'Оформление: курсоры и тема EJECT';       Action = { param($c) Invoke-ThemeModule    -Config $c } }
    system   = @{ Title = 'Система: питание и параметры';           Action = { param($c) Invoke-SystemModule   -Config $c } }
}

function Invoke-Modules {
    param([string[]]$Names, $Cfg)
    if ($null -eq $Cfg) { $Cfg = $Config }   # без выбора в меню — всё по config.json
    $start = Get-Date
    $mode = if ($Global:WDP_DryRun) { ' [DRY RUN]' } else { '' }
    Write-Log ("Старт. Конфиг: {0}. Лог: {1}{2}" -f $ConfigPath, $Global:WDP_LogFile, $mode)

    if (-not $NoRestorePoint -and (Get-Cfg $Config 'createRestorePoint' $true)) {
        Invoke-Step 'Точка восстановления' { New-RestorePointSafe }
    }

    foreach ($n in $Names) {
        $m = $ModuleMap[$n]
        Write-Host ''
        Write-Host ('=' * 64) -ForegroundColor DarkCyan
        Write-Host ("  {0}" -f $m.Title) -ForegroundColor White
        Write-Host ('=' * 64) -ForegroundColor DarkCyan
        try { & $m.Action $Cfg }
        catch { Write-Log "Модуль '$n' завершился с ошибкой: $($_.Exception.Message)" 'ERROR' }
    }

    if ($Names -contains 'explorer' -or $Names -contains 'privacy' -or $Names -contains 'theme') { Restart-Explorer }

    $elapsed = [int]((Get-Date) - $start).TotalSeconds
    Write-Host ''
    Write-Log "Готово за $elapsed с. Часть настроек вступит в силу после перезагрузки." 'OK'
    if ($Global:WDP_RebootRequired) {
        Write-Log 'ТРЕБУЕТСЯ ПЕРЕЗАГРУЗКА: установлен UltraUXThemePatcher. Тема EJECT применится автоматически после входа.' 'WARN'
    }
}

# ---------- Режим без меню ----------
if ($All)     { Invoke-Modules -Names @($ModuleMap.Keys); exit 0 }
if ($Modules) { Invoke-Modules -Names $Modules;           exit 0 }

# ---------- Интерактивное меню ----------
function Show-Menu {
    Clear-Host
    Write-Host ''
    Write-Host '   WindowsDoProgram — настройка Windows после переустановки' -ForegroundColor Cyan
    Write-Host ("   Конфиг: {0}" -f $ConfigPath) -ForegroundColor DarkGray
    if ($Global:WDP_DryRun) { Write-Host '   РЕЖИМ ПРОВЕРКИ (DryRun): изменения не применяются' -ForegroundColor Magenta }
    Write-Host ''
    Write-Host '   [1] Выполнить ВСЁ по config.json (без вопросов)' -ForegroundColor Green
    Write-Host ''
    $i = 2
    foreach ($k in $ModuleMap.Keys) {
        $enabled = Get-Cfg (Get-Cfg $Config $k) 'enabled' $true
        $mark  = if ($enabled) { '' } else { '(выкл. в конфиге)' }
        $color = if ($enabled) { 'White' } else { 'DarkGray' }
        Write-Host ("   [{0}] {1,-45} {2}" -f $i, $ModuleMap[$k].Title, $mark) -ForegroundColor $color
        $i++
    }
    Write-Host ''
    Write-Host '   Пункты [2]-[7] открывают список, где вы отмечаете, что именно установить или применить.' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '   [D] Переключить режим проверки (DryRun)'
    Write-Host '   [C] Открыть config.json в Блокноте'
    Write-Host '   [L] Открыть папку с логами'
    Write-Host '   [0] Выход'
    Write-Host ''
}

$keys = @($ModuleMap.Keys)
while ($true) {
    Show-Menu
    $choice = (Read-Host '   Выбор').Trim().ToUpper()
    switch ($choice) {
        '0' { exit 0 }
        '1' { Invoke-Modules -Names $keys; Read-Host 'Нажмите Enter для возврата в меню' | Out-Null }
        'D' { $Global:WDP_DryRun = -not $Global:WDP_DryRun }
        'C' { Start-Process notepad.exe -ArgumentList "`"$ConfigPath`"" }
        'L' { Start-Process explorer.exe -ArgumentList "`"$logDir`"" }
        default {
            if ($choice -match '^\d+$' -and [int]$choice -ge 2 -and [int]$choice -le ($keys.Count + 1)) {
                $name  = $keys[[int]$choice - 2]
                $items = @(Get-ModuleItems -Module $name -Config $Config)
                if ($items.Count -eq 0) {
                    Invoke-Modules -Names @($name)
                }
                elseif (Show-Checklist -Title $ModuleMap[$name].Title -Items $items) {
                    $runCfg = ConvertTo-SelectedConfig -Config $Config -Items $items
                    Set-CfgPath $runCfg @($name, 'enabled') $true   # модуль выбран явно — выполняем, даже если выключен в конфиге
                    Clear-Host
                    Invoke-Modules -Names @($name) -Cfg $runCfg
                }
                else { continue }
                Read-Host 'Нажмите Enter для возврата в меню' | Out-Null
            }
        }
    }
}
