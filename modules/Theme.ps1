# ============================================================
#  Theme.ps1 — оформление: курсоры и тема EJECT из WatchThisFolder
# ============================================================

# ---------- Курсоры (эквивалент «ПКМ → Установить» на Install.inf) ----------

# Читает секцию [Strings] из Install.inf → hashtable key=value
function Read-InfStrings {
    param([string]$InfPath)
    $map = @{}
    $inStrings = $false
    foreach ($line in (Get-Content -Path $InfPath -Encoding UTF8)) {
        $t = $line.Trim()
        if ($t -match '^\[(.+)\]$') { $inStrings = ($Matches[1] -ieq 'Strings'); continue }
        if (-not $inStrings -or -not $t -or $t.StartsWith(';')) { continue }
        if ($t -match '^([^=]+?)\s*=\s*"?([^"]*)"?\s*$') { $map[$Matches[1].Trim()] = $Matches[2] }
    }
    return $map
}

function Install-CursorScheme {
    param([string]$CursorDir)   # папка с Install.inf и .cur/.ani

    $inf = Join-Path $CursorDir 'Install.inf'
    if (-not (Test-Path $inf)) { Write-Log "Не найден $inf" 'ERROR'; return }
    $s = Read-InfStrings $inf
    $curDir = $s['CUR_DIR']; $scheme = $s['SCHEME_NAME']
    if (-not $curDir -or -not $scheme) { Write-Log "В $inf нет CUR_DIR / SCHEME_NAME" 'ERROR'; return }

    $dest    = Join-Path $env:SystemRoot $curDir               # C:\Windows\Cursors\W11_dark_v2.2
    $destReg = "%SystemRoot%\$curDir"                          # как в INF: %10%\%CUR_DIR%

    # Копирование файлов
    if (Test-DryRun) { Write-Log "copy $CursorDir\*.cur,*.ani → $dest" 'DRY' }
    else {
        if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
        Get-ChildItem -Path $CursorDir -Include '*.cur','*.ani' -Recurse -File |
            Copy-Item -Destination $dest -Force
        Write-Log "Курсоры скопированы в $dest" 'OK'
    }

    # Соответствие «имя в реестре → ключ из [Strings]» (секция [Wreg] в Install.inf)
    $regMap = [ordered]@{
        AppStarting = 'working'; Arrow = 'pointer'; crosshair = 'precision'; precisionhair = 'precision'
        Hand = 'link'; Help = 'help'; IBeam = 'text'; No = 'unavailable'; NWPen = 'hand'
        SizeAll = 'move'; SizeNESW = 'dgn2'; SizeNS = 'vert'; SizeNWSE = 'dgn1'; SizeWE = 'horz'
        UpArrow = 'alternate'; Wait = 'busy'; Person = 'person'; Pin = 'pin'
    }
    # Порядок файлов в строке схемы (секция [Scheme.Reg])
    $schemeOrder = 'pointer','help','working','busy','precision','text','hand','unavailable',
                   'vert','horz','dgn1','dgn2','move','alternate','link','person','pin'

    $CUR = 'HKCU:\Control Panel\Cursors'
    Set-RegValue $CUR '(Default)' $scheme 'String'
    foreach ($k in $regMap.Keys) {
        $file = $s[$regMap[$k]]
        if ($file) { Set-RegValue $CUR $k "$destReg\$file" 'ExpandString' }
    }
    Set-RegValue $CUR 'Scheme Source' 1                        # 1 = пользовательская схема
    $schemeValue = ($schemeOrder | ForEach-Object { "$destReg\$($s[$_])" }) -join ','
    Set-RegValue "$CUR\Schemes" $scheme $schemeValue 'ExpandString'

    # Применить без перезагрузки: SystemParametersInfo(SPI_SETCURSORS)
    if (Test-DryRun) { Write-Log 'SystemParametersInfo(SPI_SETCURSORS)' 'DRY'; return }
    try {
        if (-not ('WDP.Native' -as [type])) {
            Add-Type -Namespace WDP -Name Native -MemberDefinition @'
[DllImport("user32.dll", SetLastError = true)]
public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, IntPtr pvParam, uint fWinIni);
'@
        }
        [void][WDP.Native]::SystemParametersInfo(0x0057, 0, [IntPtr]::Zero, 0x03)
        Write-Log "Схема курсоров «$scheme» применена" 'OK'
    } catch { Write-Log "Курсоры записаны в реестр, но применить сразу не удалось: $($_.Exception.Message). Вступят в силу после входа." 'WARN' }
}

# ---------- Тема EJECT ----------

function Test-UxThemePatched {
    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $hit = Get-ItemProperty -Path $keys -ErrorAction SilentlyContinue |
           Where-Object { $_.DisplayName -like 'UltraUXThemePatcher*' } | Select-Object -First 1
    return [bool]$hit
}

function Install-EjectTheme {
    param($Cfg, [string]$EjectDir)

    $patcher   = Join-Path $EjectDir 'UltraUXThemePatcher.exe'
    $srcThemes = Join-Path $EjectDir 'Eject Theme\Themes'
    $dstThemes = Join-Path $env:SystemRoot 'Resources\Themes'
    $themeFile = Join-Path $dstThemes 'Eject.theme'

    if (-not (Test-Path $srcThemes)) { Write-Log "Не найдена папка темы: $srcThemes" 'ERROR'; return }

    # 1. Патч uxtheme (нужен для сторонних .msstyles)
    $patchedBefore = Test-UxThemePatched
    if (Get-Cfg $Cfg 'patchUxTheme' $true) {
        Invoke-Step 'UltraUXThemePatcher' {
            if ($patchedBefore) { Write-Log 'UltraUXThemePatcher уже установлен' 'OK'; return }
            if (-not (Test-Path $patcher)) { Write-Log "Не найден $patcher" 'ERROR'; return }
            $code = if (Test-DryRun) { Write-Log "run  $patcher /S" 'DRY'; 0 }
                    else {
                        Write-Log "run  $patcher /S"
                        (Start-Process -FilePath $patcher -ArgumentList '/S' -Wait -PassThru).ExitCode
                    }
            if ($code -eq 0) {
                Write-Log 'UltraUXThemePatcher установлен — нужна перезагрузка' 'OK'
                $Global:WDP_RebootRequired = $true
            } else { Write-Log "UltraUXThemePatcher — код выхода $code" 'WARN' }
        }
    }

    # 2. Файлы темы → C:\Windows\Resources\Themes
    Invoke-Step 'Копирование темы EJECT' {
        if (Test-DryRun) { Write-Log "copy $srcThemes\* → $dstThemes" 'DRY'; return }
        Copy-Item -Path (Join-Path $srcThemes '*') -Destination $dstThemes -Recurse -Force
        Write-Log "Тема скопирована: $themeFile" 'OK'
    }

    # 3. Themes Fix.reg — тема не меняет значки, курсоры и обои
    if (Get-Cfg $Cfg 'themesFix' $true) {
        Invoke-Step 'Themes Fix (значки, курсоры и обои не меняются темой)' {
            $k = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes'
            Set-RegValue $k 'ThemeChangesDesktopIcons'  0
            Set-RegValue $k 'ThemeChangesMousePointers' 0
            Set-RegValue $k 'WallpaperSetFromTheme'     0
        }
    }

    # 4. Служба «Темы» (Служба Темы.bat: sc config Themes start=auto && net start Themes)
    if (Get-Cfg $Cfg 'themesService' $true) {
        Invoke-Step 'Служба Themes' {
            if (Test-DryRun) { Write-Log 'service Themes start=auto + start' 'DRY'; return }
            Set-Service -Name Themes -StartupType Automatic -ErrorAction Stop
            Start-Service -Name Themes -ErrorAction SilentlyContinue
            Write-Log 'Служба Themes: автозапуск, запущена' 'OK'
        }
    }

    # 5. Применение темы
    if (-not (Get-Cfg $Cfg 'apply' $true)) { return }
    $applyCmd = "rundll32.exe `"$env:SystemRoot\System32\themecpl.dll`",OpenThemeAction `"$themeFile`""
    if ($patchedBefore) {
        Invoke-Step 'Применение темы EJECT' {
            if (Test-DryRun) { Write-Log "run  $applyCmd" 'DRY'; return }
            Start-Process -FilePath 'rundll32.exe' -ArgumentList "`"$env:SystemRoot\System32\themecpl.dll`",OpenThemeAction `"$themeFile`""
            Start-Sleep -Seconds 6
            Stop-Process -Name SystemSettings -Force -ErrorAction SilentlyContinue
            Write-Log 'Тема EJECT применена' 'OK'
        }
    } else {
        Invoke-Step 'Тема EJECT применится после перезагрузки (RunOnce)' {
            Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' 'WDP_ApplyEjectTheme' $applyCmd 'String'
        }
    }
}

# ---------- Модуль ----------

function Invoke-ThemeModule {
    param($Config)
    $cfg = Get-Cfg $Config 'theme'
    if (-not (Get-Cfg $cfg 'enabled' $true)) { Write-Log 'Модуль theme выключен в конфиге' 'WARN'; return }

    $root = if ($Global:WDP_Root) { $Global:WDP_Root } else { (Get-Location).Path }
    function Resolve-Rel([string]$p) { if ([IO.Path]::IsPathRooted($p)) { $p } else { Join-Path $root $p } }

    # Курсоры
    $variant    = [string](Get-Cfg $cfg 'cursors' '')
    $cursorsDir = Resolve-Rel ([string](Get-Cfg $cfg 'cursorsFolder' 'resources\cursors'))
    if ($variant) {
        Invoke-Step "Курсоры ($variant)" {
            $dir = Join-Path $cursorsDir "$variant\cursor"
            if (Test-Path $dir) { Install-CursorScheme -CursorDir $dir }
            else { Write-Log "Папка курсоров не найдена: $dir (ожидается dark или light)" 'ERROR' }
        }
    } else { Write-Log 'Курсоры: не выбран вариант — пропуск' }

    # Тема EJECT
    $eject    = Get-Cfg $cfg 'eject'
    $ejectDir = Resolve-Rel ([string](Get-Cfg $eject 'folder' 'resources\themes\EJECT'))
    if (Get-Cfg $eject 'enabled' $true) {
        if (Test-Path $ejectDir) { Install-EjectTheme -Cfg $eject -EjectDir $ejectDir }
        else { Write-Log "Папка темы не найдена: $ejectDir" 'ERROR' }
    } else { Write-Log 'Тема EJECT выключена в конфиге' }
}
