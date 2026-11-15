# ============================================================
#  Apps.ps1 — установка программ через winget
# ============================================================

function Test-WingetInstalled {
    param([string]$Id, [string[]]$SourceArgs = @())
    $out = & winget list --id $Id -e --accept-source-agreements @SourceArgs 2>$null
    return ($LASTEXITCODE -eq 0 -and (($out -join "`n") -match [regex]::Escape($Id)))
}

# Проверка по «Установка и удаление программ» (DisplayName содержит $Pattern)
function Test-ProgramInstalled {
    param([string]$Pattern)
    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )
    $hit = Get-ItemProperty -Path $keys -ErrorAction SilentlyContinue |
           Where-Object { $_.DisplayName -and $_.DisplayName -like "*$Pattern*" } |
           Select-Object -First 1
    return [bool]$hit
}

# Локальные установщики (apps.local): exe/msi из папки проекта
function Install-LocalApps {
    param($Cfg)
    $list = @(Get-Cfg $Cfg 'local' @())
    if ($list.Count -eq 0) { return }
    $root = if ($Global:WDP_Root) { $Global:WDP_Root } else { (Get-Location).Path }

    Write-Host ''
    Write-Log "Локальные установщики ($($list.Count)):" 'STEP'
    foreach ($item in $list) {
        $name    = Get-Cfg $item 'name' '?'
        $rel     = Get-Cfg $item 'path' ''
        $iargs   = @((Get-Cfg $item 'args' '') -split '\s+' | Where-Object { $_ })
        $detect  = [string](Get-Cfg $item 'detect' '')
        $note    = Get-Cfg $item 'note' ''
        if (-not (Get-Cfg $item 'enabled' $true)) { Write-Log "$name — пропуск (enabled=false)"; continue }
        if (-not $rel) { Write-Log "$name — не указан path" 'WARN'; continue }

        $path = if ([IO.Path]::IsPathRooted($rel)) { $rel } else { Join-Path $root $rel }
        if (-not (Test-Path $path)) { Write-Log "$name — установщик не найден: $path" 'ERROR'; continue }

        if ($detect) {
            $installed = if ($detect -match '[\\/]') { Test-Path ([Environment]::ExpandEnvironmentVariables($detect)) }
                         else { Test-ProgramInstalled $detect }
            if ($installed) { Write-Log "$name уже установлен" 'OK'; continue }
        }

        Write-Log "Установка: $name" 'STEP'
        if ($path -like '*.msi') { $code = Invoke-External 'msiexec.exe' (@('/i', "`"$path`"", '/qn', '/norestart') + $iargs) }
        else {
            if (Test-DryRun) { Write-Log "run  $path $($iargs -join ' ')" 'DRY'; $code = 0 }
            else {
                Write-Log "run  $path $($iargs -join ' ')"
                $p = if ($iargs.Count) { Start-Process -FilePath $path -ArgumentList $iargs -Wait -PassThru } else { Start-Process -FilePath $path -Wait -PassThru }
                $code = $p.ExitCode
            }
        }
        if ($code -eq 0) { Write-Log "$name установлен" 'OK' } else { Write-Log "$name — код выхода $code" 'WARN' }
        if ($note) { Write-Host ("      {0}" -f $note) -ForegroundColor Gray }
    }
}

function Show-ManualSteps {
    param($Cfg)
    $manual = @((Get-Cfg $Cfg 'manual' @()) | Where-Object { Get-Cfg $_ 'enabled' $true })
    if ($manual.Count -eq 0) { return }

    Write-Host ''
    Write-Log "Шаги, которые нужно сделать вручную ($($manual.Count)):" 'STEP'
    $i = 1
    foreach ($m in $manual) {
        $name = Get-Cfg $m 'name' '?'
        $url  = Get-Cfg $m 'url'  ''
        $note = Get-Cfg $m 'note' ''
        Write-Host ("   {0}. {1}" -f $i, $name) -ForegroundColor White
        if ($note) { Write-Host ("      {0}" -f $note) -ForegroundColor Gray }
        if ($url)  { Write-Host ("      {0}" -f $url)  -ForegroundColor DarkCyan }
        $i++
    }
    if ($Global:WDP_LogFile) {
        $manual | ForEach-Object { Add-Content -Path $Global:WDP_LogFile -Value ("MANUAL: {0} | {1} | {2}" -f (Get-Cfg $_ 'name'), (Get-Cfg $_ 'note'), (Get-Cfg $_ 'url')) -Encoding UTF8 }
    }

    if (Get-Cfg $Cfg 'openManualLinks' $false) {
        $urls = @($manual | ForEach-Object { Get-Cfg $_ 'url' '' } | Where-Object { $_ })
        if (Test-DryRun) { Write-Log "open $($urls.Count) ссылок в браузере" 'DRY' }
        else {
            Write-Log "Открываю $($urls.Count) ссылок в браузере..."
            foreach ($u in $urls) { Start-Process $u; Start-Sleep -Milliseconds 400 }
        }
    }
}

function Invoke-AppsModule {
    param($Config)
    $cfg = Get-Cfg $Config 'apps'
    if (-not (Get-Cfg $cfg 'enabled' $true)) { Write-Log 'Модуль apps выключен в конфиге' 'WARN'; return }

    $list = @(Get-Cfg $cfg 'winget' @())
    if ($list.Count -eq 0) {
        Write-Log 'Список программ пуст — добавьте ID пакетов в config.json → apps.winget' 'WARN'
        Install-LocalApps $cfg
        Show-ManualSteps $cfg
        return
    }

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Log 'winget не найден. Установите «Установщик приложений» из Microsoft Store и повторите.' 'ERROR'
        Install-LocalApps $cfg
        Show-ManualSteps $cfg
        return
    }

    # Источник пакетов. По умолчанию только 'winget': источник msstore на свежей Windows часто
    # падает с ошибкой сертификата (0x8A15005E) и валит вместе с собой каждую установку.
    $source  = [string](Get-Cfg $cfg 'source' 'winget')
    $srcArgs = if ($source) { @('--source', $source) } else { @() }

    Invoke-Step 'Обновление источников winget' {
        $upd = @('source','update'); if ($source) { $upd += @('--name', $source) }
        Invoke-External 'winget' $upd | Out-Null
    }

    $ok = 0; $skip = 0; $fail = 0
    foreach ($item in $list) {
        if ($item -is [string]) { $id = $item; $name = $item; $extra = @(); $enabled = $true }
        else {
            $id      = Get-Cfg $item 'id'
            $name    = Get-Cfg $item 'name' $id
            $extra   = @((Get-Cfg $item 'args' '') -split '\s+' | Where-Object { $_ })
            $enabled = Get-Cfg $item 'enabled' $true
        }
        if (-not $id) { continue }
        if (-not $enabled) { Write-Log "$name — пропуск (enabled=false)"; $skip++; continue }

        if (-not (Test-DryRun) -and (Test-WingetInstalled $id $srcArgs)) {
            Write-Log "$name уже установлен" 'OK'; $skip++; continue
        }

        Write-Log "Установка: $name ($id)" 'STEP'
        $wargs = @('install','--id',$id,'-e','--silent','--accept-source-agreements','--accept-package-agreements','--disable-interactivity') + $srcArgs + $extra
        $code = Invoke-External 'winget' $wargs
        switch ($code) {
            0            { Write-Log "$name установлен" 'OK'; $ok++ }
            -1978335189  { Write-Log "$name уже установлен (актуальная версия)" 'OK'; $skip++ }   # 0x8A15002B
            -1978335135  { Write-Log "$name уже установлен" 'OK'; $skip++ }                        # 0x8A150061
            -1978335138  {                                                                                # 0x8A15005E PINNED_CERTIFICATE_MISMATCH
                Write-Log "$name — ошибка сертификата источника winget (0x8A15005E). Обновите «Установщик приложений» в Microsoft Store или выполните: winget source remove msstore" 'ERROR'; $fail++
            }
            default      { Write-Log ("{0} — ошибка установки, код {1} (0x{2:X8})" -f $name, $code, ($code -band 0xFFFFFFFF)) 'ERROR'; $fail++ }
        }
    }
    Write-Log "Программы: установлено $ok, пропущено $skip, ошибок $fail" $(if ($fail) {'WARN'} else {'OK'})
    Install-LocalApps $cfg
    Show-ManualSteps $cfg
}
