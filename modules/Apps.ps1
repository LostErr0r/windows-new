# ============================================================
#  Apps.ps1 — установка программ через winget и с диска
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

# ---------- Папка установки ----------

# Имя подпапки из названия программы: «Firefox (русский)» → «Firefox»
function Get-SafeFolderName {
    param([string]$Name, [string]$Fallback = 'App')
    $n = $Name -replace '\s*\([^)]*\)', ''          # убрать скобки с пояснениями
    $n = $n -replace '[\\/:*?"<>|]', ''             # недопустимые символы
    $n = ($n -replace '\s+', ' ').Trim().TrimEnd('.')
    if (-not $n) { $n = ($Fallback -split '\.')[-1] }
    return $n
}

# Самый свободный несистемный локальный диск → <диск>\Programs
function Find-AutoInstallRoot {
    $sys = $env:SystemDrive
    $d = Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue |
         Where-Object { $_.DeviceID -ne $sys -and $_.FreeSpace -gt 0 } |
         Sort-Object FreeSpace -Descending | Select-Object -First 1
    if (-not $d) { return $null }
    return @{ Path = (Join-Path "$($d.DeviceID)\" 'Programs'); Note = ("auto: диск {0} ({1} ГБ свободно)" -f $d.DeviceID, [math]::Round($d.FreeSpace / 1GB)) }
}

# Перебирает варианты installRoot по порядку, возвращает @{Path; Note} или $null
function Resolve-InstallRoot {
    param($Spec)   # строка или список строк; "auto" — самый свободный несистемный диск
    $cands = @($Spec | ForEach-Object { [string]$_ } | Where-Object { $_ })
    foreach ($c in $cands) {
        if ($c -ieq 'auto') {
            $a = Find-AutoInstallRoot
            if ($a) { return $a }
            Write-Log 'Папка установки "auto": несистемных дисков нет — пробую следующий вариант' 'WARN'
            continue
        }
        $p = [Environment]::ExpandEnvironmentVariables($c)
        $drive = [IO.Path]::GetPathRoot($p)
        if ($drive -and (Test-Path $drive)) { return @{ Path = $p; Note = $c } }
        Write-Log "Папка установки $p : диск $drive не найден — пробую следующий вариант" 'WARN'
    }
    return $null
}

# Вопрос пользователю: список дисков, рекомендуемый вариант, свой путь или «по умолчанию»
function Read-InstallRootFromUser {
    param($Suggested, [string]$FolderName = 'Programs')
    $sys = $env:SystemDrive
    $disks = @(Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction SilentlyContinue | Sort-Object DeviceID)

    # Варианты: рекомендуемый первым, затем <диск>\Programs для каждого диска
    $opts = New-Object System.Collections.Generic.List[object]
    if ($Suggested) { $opts.Add(@{ Path = $Suggested.Path; Note = "рекомендуется: $($Suggested.Note)" }) }
    foreach ($d in $disks) {
        $p = Join-Path "$($d.DeviceID)\" $FolderName
        if ($opts | Where-Object { $_.Path -ieq $p }) { continue }
        $note = if ($d.DeviceID -eq $sys) { 'системный диск' } else { '' }
        $opts.Add(@{ Path = $p; Note = $note })
    }

    while ($true) {
        Write-Host ''
        Write-Host '   Куда ставить программы?' -ForegroundColor Cyan
        foreach ($d in $disks) {
            $label = if ($d.VolumeName) { $d.VolumeName } else { '' }
            $mark  = if ($d.DeviceID -eq $sys) { ' (системный)' } else { '' }
            Write-Host ("     {0}  {1,-18} {2,6} ГБ, свободно {3,6} ГБ{4}" -f $d.DeviceID, $label, [math]::Round($d.Size / 1GB), [math]::Round($d.FreeSpace / 1GB), $mark) -ForegroundColor DarkGray
        }
        Write-Host ''
        for ($i = 0; $i -lt $opts.Count; $i++) {
            $o = $opts[$i]
            $color = if ($i -eq 0 -and $Suggested) { 'Green' } else { 'White' }
            $tail  = if ($o.Note) { "   ($($o.Note))" } else { '' }
            Write-Host ("   [{0}] {1}{2}" -f ($i + 1), $o.Path, $tail) -ForegroundColor $color
        }
        Write-Host '   [0] По умолчанию (обычно C:\Program Files)'
        $hint = if ($Suggested) { 'Enter — вариант [1]' } else { 'Enter — по умолчанию' }
        $ans = (Read-Host "   Номер, свой путь (например E:\Soft) или $hint").Trim().Trim('"')

        if (-not $ans) { if ($Suggested) { return $opts[0] } else { return $null } }
        if ($ans -eq '0') { return $null }
        if ($ans -match '^\d+$' -and [int]$ans -ge 1 -and [int]$ans -le $opts.Count) { return $opts[[int]$ans - 1] }

        $drive = $null; try { $drive = [IO.Path]::GetPathRoot($ans) } catch {}
        if ($drive -and (Test-Path $drive)) { return @{ Path = $ans; Note = 'введено вручную' } }
        Write-Host "   Диск «$drive» не найден, попробуйте ещё раз." -ForegroundColor Red
    }
}

# Готовит корневую папку установки. Возвращает путь или '' (ставить по умолчанию).
function Initialize-InstallRoot {
    param($Spec, [bool]$Ask = $true)
    $cands = @($Spec | ForEach-Object { [string]$_ } | Where-Object { $_ })

    $r = $null
    if ($cands.Count -gt 0) { $r = Resolve-InstallRoot -Spec $cands }

    # Из меню всегда спрашиваем (вариант из конфига — по Enter); в режиме -All берём конфиг молча
    if ($Global:WDP_Interactive -and $Ask) {
        $folder = 'Programs'
        $first = @($cands | Where-Object { $_ -ine 'auto' })
        if ($first.Count -gt 0) { $leaf = Split-Path -Leaf ([Environment]::ExpandEnvironmentVariables($first[0])); if ($leaf) { $folder = $leaf } }
        $r = Read-InstallRootFromUser -Suggested $r -FolderName $folder
    }
    elseif ($cands.Count -eq 0) { return '' }

    if (-not $r) {
        Write-Log 'Папка установки не выбрана — программы будут ставиться по умолчанию (обычно C:\Program Files)' 'WARN'
        return ''
    }

    $Root = $r.Path
    if (-not (Test-Path $Root)) {
        if (Test-DryRun) { Write-Log "mkdir $Root" 'DRY' }
        else { New-Item -ItemType Directory -Path $Root -Force | Out-Null }
    }
    Write-Log "Папка установки: $Root [$($r.Note)] — каждая программа в своей подпапке; установщики без выбора папки ставятся по умолчанию"
    Set-WingetInstallRoot -Root $Root
    return $Root
}

# Настройки winget: куда класть portable-пакеты и пакеты с обязательной папкой
function Set-WingetInstallRoot {
    param([string]$Root)
    $path     = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\settings.json'
    $portable = Join-Path $Root '_portable'
    if (Test-DryRun) { Write-Log "winget settings: installBehavior → $Root, portable → $portable" 'DRY'; return }
    try {
        $obj = $null
        if (Test-Path $path) {
            $raw   = Get-Content -Path $path -Raw -Encoding UTF8
            $clean = ($raw -split "`r?`n" | Where-Object { -not $_.TrimStart().StartsWith('//') }) -join "`n"
            if ($clean.Trim()) { $obj = $clean | ConvertFrom-Json }
        }
        if (-not $obj) { $obj = [pscustomobject]@{ '$schema' = 'https://aka.ms/winget-settings.schema.json' } }
        $ib = Get-Cfg $obj 'installBehavior'
        if (-not $ib) { $ib = [pscustomobject]@{}; $obj | Add-Member -NotePropertyName 'installBehavior' -NotePropertyValue $ib -Force }
        $ib | Add-Member -NotePropertyName 'defaultInstallRoot'         -NotePropertyValue $Root     -Force
        $ib | Add-Member -NotePropertyName 'portablePackageUserRoot'    -NotePropertyValue $portable -Force
        $ib | Add-Member -NotePropertyName 'portablePackageMachineRoot' -NotePropertyValue $portable -Force
        $dir = Split-Path -Parent $path
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        [IO.File]::WriteAllText($path, ($obj | ConvertTo-Json -Depth 10), (New-Object Text.UTF8Encoding $false))
        Write-Log "winget: portable-пакеты будут ставиться в $portable" 'OK'
    } catch { Write-Log "Не удалось обновить настройки winget: $($_.Exception.Message)" 'WARN' }
}

# Папка для конкретной программы: location (абсолютный) > folder (внутри root) > имя программы
function Get-AppInstallLocation {
    param($Item, [string]$Name, [string]$Id, [string]$Root)
    if (-not $Root) { return '' }
    if ($Item -is [string]) { return (Join-Path $Root (($Id -split '\.')[-1])) }   # "Google.Chrome" → Chrome
    else {
        if (Get-Cfg $Item 'noLocation' $false) { return '' }
        $abs = [string](Get-Cfg $Item 'location' '')
        if ($abs) { return [Environment]::ExpandEnvironmentVariables($abs) }
        $folder = [string](Get-Cfg $Item 'folder' '')
        if ($folder) { return (Join-Path $Root $folder) }
    }
    return (Join-Path $Root (Get-SafeFolderName -Name $Name -Fallback $Id))
}

# ---------- Локальные установщики (apps.local): exe/msi из папки проекта ----------

function Install-LocalApps {
    param($Cfg, [string]$InstallRoot = '')
    $list = @(Get-Cfg $Cfg 'local' @())
    if ($list.Count -eq 0) { return }
    $root = if ($Global:WDP_Root) { $Global:WDP_Root } else { (Get-Location).Path }

    Write-Host ''
    Write-Log "Локальные установщики ($($list.Count)):" 'STEP'
    foreach ($item in $list) {
        $name    = Get-Cfg $item 'name' '?'
        $rel     = Get-Cfg $item 'path' ''
        $detect  = [string](Get-Cfg $item 'detect' '')
        $note    = Get-Cfg $item 'note' ''
        if (-not (Get-Cfg $item 'enabled' $true)) { Write-Log "$name — пропуск (enabled=false)"; continue }
        if (-not $rel) { Write-Log "$name — не указан path" 'WARN'; continue }

        # {root} в args → папка установки; без заданной папки такие аргументы убираются
        $rawArgs = [string](Get-Cfg $item 'args' '')
        $iargs = @($rawArgs -split '\s+' | Where-Object { $_ })
        if ($InstallRoot) { $iargs = @($iargs | ForEach-Object { $_.Replace('{root}', $InstallRoot) }) }
        else              { $iargs = @($iargs | Where-Object { $_ -notlike '*{root}*' }) }

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

# ---------- Последние релизы с GitHub (apps.github) ----------

# {desktop} / {downloads} и переменные окружения в пути
function Expand-PathTokens {
    param([string]$Path)
    $p = $Path.Replace('{desktop}', [Environment]::GetFolderPath('Desktop'))
    $p = $p.Replace('{downloads}', (Join-Path $env:USERPROFILE 'Downloads'))
    return [Environment]::ExpandEnvironmentVariables($p)
}

# Имя архива без расширения: name-1.2.3.tar.gz → name-1.2.3
function Get-ArchiveBaseName {
    param([string]$FileName)
    return ($FileName -replace '(?i)\.(tar\.gz|tar\.xz|tar\.bz2|tgz|zip|rar|7z|tar)$', '')
}

# Чем распаковывать не-zip архивы, по порядку: UnRAR (WinRAR) → 7-Zip → встроенный tar.exe
function Get-ArchiveTools {
    $tools = New-Object System.Collections.Generic.List[object]
    $dirs  = @()
    $ap = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\WinRAR.exe' -ErrorAction SilentlyContinue
    if ($ap -and $ap.Path) { $dirs += $ap.Path }
    $dirs += "$env:ProgramFiles\WinRAR", "${env:ProgramFiles(x86)}\WinRAR"
    if ($Global:WDP_InstallRoot) { $dirs += (Join-Path $Global:WDP_InstallRoot 'WinRAR') }
    $unrar = $dirs | ForEach-Object { Join-Path $_ 'UnRAR.exe' } | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($unrar) { $tools.Add(@{ Name = 'WinRAR'; Exe = $unrar; Args = { param($a, $d) @('x', '-y', '-idq', $a, "$d\") } }) }

    $dirs = @()
    $sz = Get-ItemProperty 'HKLM:\SOFTWARE\7-Zip' -ErrorAction SilentlyContinue
    if ($sz -and $sz.Path) { $dirs += $sz.Path }
    $dirs += "$env:ProgramFiles\7-Zip", "${env:ProgramFiles(x86)}\7-Zip"
    if ($Global:WDP_InstallRoot) { $dirs += (Join-Path $Global:WDP_InstallRoot '7-Zip') }
    $7z = $dirs | ForEach-Object { Join-Path $_ '7z.exe' } | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($7z) { $tools.Add(@{ Name = '7-Zip'; Exe = $7z; Args = { param($a, $d) @('x', '-y', "-o$d", $a) } }) }

    $tar = Join-Path $env:SystemRoot 'System32\tar.exe'
    if (Test-Path $tar) { $tools.Add(@{ Name = 'tar (встроен в Windows)'; Exe = $tar; Args = { param($a, $d) @('-xf', $a, '-C', $d) } }) }
    return $tools
}

# Распаковывает архив в $Dest. Если внутри одна папка — она и становится $Dest (без двойной вложенности).
function Expand-AnyArchive {
    param([string]$Archive, [string]$Dest)
    $stage = "$Dest.__unpack"
    $done = $false

    if ($Archive -match '(?i)\.zip$') {
        try {
            if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
            Expand-Archive -Path $Archive -DestinationPath $stage -Force -ErrorAction Stop
            $done = $true
        } catch { Write-Log "Expand-Archive: $($_.Exception.Message)" 'WARN' }
    }
    if (-not $done) {
        foreach ($t in (Get-ArchiveTools)) {
            if (Test-Path $stage) { Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue }
            New-Item -ItemType Directory -Path $stage -Force | Out-Null
            $targs = & $t.Args $Archive $stage
            & $t.Exe @targs 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0 -and (Get-ChildItem $stage -Force | Select-Object -First 1)) {
                Write-Log "Распаковано через $($t.Name)"
                $done = $true; break
            }
            Write-Log "$($t.Name) не смог распаковать (код $LASTEXITCODE), пробую следующий способ" 'WARN'
        }
    }
    if (-not $done) { Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue; return $false }

    $items = @(Get-ChildItem $stage -Force)
    if ($items.Count -eq 1 -and $items[0].PSIsContainer) {
        Move-Item -Path $items[0].FullName -Destination $Dest
        Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
    } else {
        Rename-Item -Path $stage -NewName (Split-Path -Leaf $Dest)
    }
    return $true
}

function Install-GitHubReleases {
    param($Cfg)
    $list = @((Get-Cfg $Cfg 'github' @()) | Where-Object { Get-Cfg $_ 'enabled' $true })
    if ($list.Count -eq 0) { return }

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    $oldProgress = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'   # без этого Invoke-WebRequest в PS 5.1 качает в разы медленнее
    $headers = @{ 'User-Agent' = 'WindowsDoProgram'; 'Accept' = 'application/vnd.github+json' }

    Write-Host ''
    Write-Log "Последние релизы с GitHub ($($list.Count)):" 'STEP'
    foreach ($item in $list) {
        $repo    = [string](Get-Cfg $item 'repo' '')
        $name    = [string](Get-Cfg $item 'name' $repo)
        $mask    = [string](Get-Cfg $item 'asset' '*')
        $dest    = Expand-PathTokens ([string](Get-Cfg $item 'dest' '{desktop}'))
        $extract = [bool](Get-Cfg $item 'extract' $true)
        $keep    = [bool](Get-Cfg $item 'keepArchive' $false)
        $note    = [string](Get-Cfg $item 'note' '')
        if (-not $repo) { Write-Log "$name — не указан repo (владелец/репозиторий)" 'WARN'; continue }

        try {
            $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -Headers $headers -UseBasicParsing -ErrorAction Stop
        } catch { Write-Log "$name — не удалось получить последний релиз ${repo}: $($_.Exception.Message)" 'ERROR'; continue }

        $asset = @($rel.assets | Where-Object { $_.name -like $mask }) | Select-Object -First 1
        if (-not $asset) {
            Write-Log ("{0} — в релизе {1} нет файла по маске {2}. Есть: {3}" -f $name, $rel.tag_name, $mask, (($rel.assets | ForEach-Object { $_.name }) -join ', ')) 'ERROR'
            continue
        }

        $file   = Join-Path $dest $asset.name
        $target = Join-Path $dest (Get-ArchiveBaseName $asset.name)
        Write-Log ("{0} {1}: {2} ({3} МБ) → {4}" -f $name, $rel.tag_name, $asset.name, [math]::Round($asset.size / 1MB, 1), $dest)

        if ($extract -and (Test-Path $target)) { Write-Log "$name — эта версия уже есть: $target" 'OK'; continue }
        if (-not $extract -and (Test-Path $file)) { Write-Log "$name — эта версия уже скачана: $file" 'OK'; continue }

        if (Test-DryRun) {
            Write-Log "download $($asset.browser_download_url) → $file" 'DRY'
            if ($extract) { Write-Log "extract → $target" 'DRY' }
            continue
        }

        try {
            if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $file -Headers @{ 'User-Agent' = 'WindowsDoProgram' } -UseBasicParsing -ErrorAction Stop
        } catch { Write-Log "$name — ошибка загрузки: $($_.Exception.Message)" 'ERROR'; continue }
        Write-Log "Скачан: $file" 'OK'

        if ($extract) {
            if (Expand-AnyArchive -Archive $file -Dest $target) {
                Write-Log "$name распакован: $target" 'OK'
                if (-not $keep) { Remove-Item $file -Force -ErrorAction SilentlyContinue }
            } else {
                Write-Log "$name — не удалось распаковать, архив оставлен: $file. Установите WinRAR или 7-Zip либо поменяйте asset на *.zip" 'WARN'
            }
        }
        if ($note) { Write-Host ("      {0}" -f $note) -ForegroundColor Gray }
    }
    $ProgressPreference = $oldProgress
}

# ---------- Ручные шаги ----------

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

# ---------- Модуль ----------

function Invoke-AppsModule {
    param($Config)
    $cfg = Get-Cfg $Config 'apps'
    if (-not (Get-Cfg $cfg 'enabled' $true)) { Write-Log 'Модуль apps выключен в конфиге' 'WARN'; return }

    $installRoot = Initialize-InstallRoot -Spec (Get-Cfg $cfg 'installRoot' '') -Ask ([bool](Get-Cfg $cfg 'askInstallRoot' $true))
    $Global:WDP_InstallRoot = $installRoot

    # Порядок: winget (там WinRAR) → GitHub (.rar распаковывается WinRAR'ом) → с диска → ручные шаги
    Install-WingetApps -Cfg $cfg -InstallRoot $installRoot
    Install-GitHubReleases $cfg
    Install-LocalApps $cfg $installRoot
    Show-ManualSteps $cfg
}

function Install-WingetApps {
    param($Cfg, [string]$InstallRoot)
    $cfg = $Cfg; $installRoot = $InstallRoot

    $list = @(Get-Cfg $cfg 'winget' @())
    if ($list.Count -eq 0) { Write-Log 'Список winget пуст — пропуск'; return }

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Log 'winget не найден. Установите «Установщик приложений» из Microsoft Store и повторите.' 'ERROR'
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

        $loc = Get-AppInstallLocation -Item $item -Name $name -Id $id -Root $installRoot
        $locArgs = if ($loc) { @('--location', $loc) } else { @() }

        Write-Log "Установка: $name ($id)" 'STEP'
        $wargs = @('install','--id',$id,'-e','--silent','--accept-source-agreements','--accept-package-agreements','--disable-interactivity') + $srcArgs + $locArgs + $extra
        $code = Invoke-External 'winget' $wargs
        switch ($code) {
            0 {
                if ($loc -and -not (Test-DryRun)) {
                    if (Test-Path $loc) { Write-Log "$name установлен в $loc" 'OK' }
                    else { Write-Log "$name установлен (установщик не поддерживает выбор папки — стоит в месте по умолчанию)" 'OK' }
                } else { Write-Log "$name установлен" 'OK' }
                $ok++
            }
            -1978335189  { Write-Log "$name уже установлен (актуальная версия)" 'OK'; $skip++ }   # 0x8A15002B
            -1978335135  { Write-Log "$name уже установлен" 'OK'; $skip++ }                        # 0x8A150061
            -1978335138  {                                                                                # 0x8A15005E PINNED_CERTIFICATE_MISMATCH
                Write-Log "$name — ошибка сертификата источника winget (0x8A15005E). Обновите «Установщик приложений» в Microsoft Store или выполните: winget source remove msstore" 'ERROR'; $fail++
            }
            default      { Write-Log ("{0} — ошибка установки, код {1} (0x{2:X8})" -f $name, $code, ($code -band 0xFFFFFFFF)) 'ERROR'; $fail++ }
        }
    }
    Write-Log "Программы winget: установлено $ok, пропущено $skip, ошибок $fail" $(if ($fail) {'WARN'} else {'OK'})
}
