# ============================================================
#  Common.ps1 — общие функции (лог, реестр, службы, dry-run)
# ============================================================

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('INFO','OK','WARN','ERROR','STEP','DRY')][string]$Level = 'INFO'
    )
    $ts   = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$ts] [$Level] $Message"
    $color = switch ($Level) {
        'OK'    { 'Green' }
        'WARN'  { 'Yellow' }
        'ERROR' { 'Red' }
        'STEP'  { 'Cyan' }
        'DRY'   { 'Magenta' }
        default { 'Gray' }
    }
    Write-Host $line -ForegroundColor $color
    if ($Global:WDP_LogFile) {
        try { Add-Content -Path $Global:WDP_LogFile -Value $line -Encoding UTF8 } catch {}
    }
}

function Test-DryRun { return [bool]$Global:WDP_DryRun }

# Безопасное чтение поля из конфига со значением по умолчанию
function Get-Cfg {
    param($Object, [string]$Name, $Default = $null)
    if ($null -eq $Object) { return $Default }
    $p = $Object.PSObject.Properties[$Name]
    if ($null -eq $p -or $null -eq $p.Value) { return $Default }
    return $p.Value
}

function Invoke-Step {
    param([string]$Name, [scriptblock]$Action)
    Write-Log $Name 'STEP'
    try { & $Action }
    catch { Write-Log "Ошибка в шаге '$Name': $($_.Exception.Message)" 'ERROR' }
}

# ---------- Реестр ----------
function Set-RegValue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Value,
        [ValidateSet('DWord','QWord','String','ExpandString','Binary','MultiString')][string]$Type = 'DWord'
    )
    if (Test-DryRun) { Write-Log "reg set  $Path\$Name = $Value ($Type)" 'DRY'; return }
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
        Write-Log "reg set  $Path\$Name = $Value" 'OK'
    } catch {
        Write-Log "reg set  $Path\$Name — ошибка: $($_.Exception.Message)" 'ERROR'
    }
}

function Remove-RegValue {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Name)
    if (Test-DryRun) { Write-Log "reg del  $Path\$Name" 'DRY'; return }
    if (Test-Path $Path) {
        Remove-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        Write-Log "reg del  $Path\$Name" 'OK'
    }
}

function Remove-RegKey {
    param([Parameter(Mandatory)][string]$Path)
    if (Test-DryRun) { Write-Log "reg delkey $Path" 'DRY'; return }
    if (Test-Path $Path) {
        Remove-Item -Path $Path -Recurse -Force -ErrorAction SilentlyContinue
        Write-Log "reg delkey $Path" 'OK'
    }
}

# ---------- Службы и задачи ----------
function Disable-ServiceSafe {
    param([Parameter(Mandatory)][string]$Name)
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if (-not $svc) { Write-Log "Служба $Name не найдена — пропуск" 'WARN'; return }
    if (Test-DryRun) { Write-Log "service disable $Name" 'DRY'; return }
    try {
        Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
        Set-Service -Name $Name -StartupType Disabled -ErrorAction Stop
        Write-Log "Служба $Name остановлена и отключена" 'OK'
    } catch { Write-Log "Служба $Name — ошибка: $($_.Exception.Message)" 'ERROR' }
}

function Disable-TaskSafe {
    param([Parameter(Mandatory)][string]$FullPath)   # например "\Microsoft\Windows\Feedback\Siuf\DmClient"
    $idx  = $FullPath.LastIndexOf('\')
    $path = $FullPath.Substring(0, $idx + 1)
    $name = $FullPath.Substring($idx + 1)
    $task = Get-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction SilentlyContinue
    if (-not $task) { Write-Log "Задача $FullPath не найдена — пропуск" 'WARN'; return }
    if (Test-DryRun) { Write-Log "task disable $FullPath" 'DRY'; return }
    try {
        $task | Disable-ScheduledTask -ErrorAction Stop | Out-Null
        Write-Log "Задача $FullPath отключена" 'OK'
    } catch { Write-Log "Задача $FullPath — ошибка: $($_.Exception.Message)" 'ERROR' }
}

# ---------- Внешние команды ----------
function Invoke-External {
    param([Parameter(Mandatory)][string]$FilePath, [string[]]$ArgumentList = @())
    $cmdline = "$FilePath $($ArgumentList -join ' ')"
    if (Test-DryRun) { Write-Log "run  $cmdline" 'DRY'; return 0 }
    Write-Log "run  $cmdline"
    & $FilePath @ArgumentList 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    return $LASTEXITCODE
}

function Restart-Explorer {
    if (Test-DryRun) { Write-Log "restart explorer.exe" 'DRY'; return }
    Write-Log 'Перезапуск Проводника...'
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
}

function New-RestorePointSafe {
    param([string]$Description = 'WindowsDoProgram')
    if (Test-DryRun) { Write-Log "restore point '$Description'" 'DRY'; return }
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        # Снимаем ограничение «одна точка в 24 часа»
        $srKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
        $old = (Get-ItemProperty -Path $srKey -Name SystemRestorePointCreationFrequency -ErrorAction SilentlyContinue).SystemRestorePointCreationFrequency
        New-ItemProperty -Path $srKey -Name SystemRestorePointCreationFrequency -Value 0 -PropertyType DWord -Force | Out-Null
        Checkpoint-Computer -Description $Description -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        if ($null -ne $old) { Set-ItemProperty -Path $srKey -Name SystemRestorePointCreationFrequency -Value $old }
        else { Remove-ItemProperty -Path $srKey -Name SystemRestorePointCreationFrequency -ErrorAction SilentlyContinue }
        Write-Log "Точка восстановления '$Description' создана" 'OK'
    } catch {
        Write-Log "Не удалось создать точку восстановления: $($_.Exception.Message)" 'WARN'
    }
}
