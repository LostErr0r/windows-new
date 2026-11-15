# WindowsDoProgram

[Русский](README.ru.md) | **English**

A post-install setup script for Windows 10/11. Everything it does is described in a single `config.json`: edit it once, then after every clean install run `Run.bat` and get the same configured system — apps, privacy, Explorer, cursors, theme.

## Features

- **Apps** — install via winget, silent install of exe/msi from disk, a list of things to install by hand (with links).
- **Privacy** — telemetry, advertising ID, activity history, Cortana, Bing in Start, Copilot, Recall.
- **Debloat** — remove built-in apps (Xbox, Bing, Teams, Clipchamp, Solitaire, …; they come back from Microsoft Store). OneDrive optional.
- **Explorer & taskbar** — file extensions, hidden files, classic context menu, compact view, navigation pane, widgets, search, seconds in clock, Start "Recommended".
- **Appearance** — cursor scheme and a third-party `.msstyles` theme (with UltraUXThemePatcher).
- **System** — power plan, display/sleep timeouts, long paths, clipboard history, Sticky Keys, developer mode, time zone.
- **Pick what you want** — every module opens a checklist: tick only what you need and run.
- **Safe** — restore point before changes, DryRun mode, a log for every run.

## Layout

```
WindowsDoProgram\
├─ Run.bat            double-click to start (asks for admin rights itself)
├─ Setup.ps1          main script: menu, config loading, module runner
├─ config.json        ALL settings — edit this file
├─ modules\
│   ├─ Common.ps1     shared helpers: log, registry, services, dry-run
│   ├─ Menu.ps1       checklist: pick items inside a module
│   ├─ Apps.ps1       install apps via winget and from disk
│   ├─ Privacy.ps1    telemetry, ads, Cortana, Copilot, Recall
│   ├─ Debloat.ps1    remove built-in apps, OneDrive
│   ├─ Explorer.ps1   Explorer, taskbar, dark theme, Start menu
│   ├─ Theme.ps1      cursors and theme from resources
│   └─ System.ps1     power plan, sleep, long paths, clipboard, etc.
├─ resources\         things installed from disk rather than winget (see resources\README.md)
│   ├─ installers\        exe/msi — installed silently by the apps module
│   ├─ cursors\           cursor schemes (dark / light)
│   ├─ themes\EJECT\      EJECT theme + UltraUXThemePatcher + Themes Fix.reg
│   └─ scripts\           bat files for manual use
└─ logs\              a log for every run
```

## Quick start

1. Copy the folder to a USB stick or cloud storage so it survives reinstalls.
2. After installing Windows, double-click `Run.bat`. A menu appears:

```
[1] Run EVERYTHING from config.json (no questions)
[2] Install apps
[3] Privacy and telemetry
[4] Remove built-in apps
[5] Explorer, taskbar, appearance
[6] Appearance: cursors and EJECT theme
[7] System: power and settings
[D] Toggle check mode (DryRun)
[C] Open config.json in Notepad
[L] Open the logs folder
[0] Exit
```

- **[1]** runs everything from the config without asking.
- **[2]–[7]** open the module's checklist (see below).
- **[D]** — check mode: the script only prints what it would do, tagged `[DRY]`, and changes nothing.
- **[C]** — open `config.json` in Notepad. **[L]** — open the logs folder.

The menu itself is in Russian; module names above are translated for reference.

### Picking items inside a module

Checkboxes start out as written in `config.json`:

```
   Install apps
   -- via winget --
   [x]   1. Firefox (Russian)  (Mozilla.Firefox.ru)      [x]  14. Everything  (voidtools.Everything)
   [x]   2. Telegram  (Telegram.TelegramDesktop)         [ ]  15. KeePassXC  (KeePassXCTeam.KeePassXC)
   ...
   Selected: 24 of 27
   [A] all   [N] none   [I] invert   [S] RUN selected   [0] back
   Input: 15, 20-23
```

- Type a number (or several separated by commas, or a range `5-12`) to toggle an item.
- Items with a value (cursors `dark`/`light`, power plan `high`/`balanced`/`ultimate`, taskbar search) cycle through their options when you enter the number again; the last position is "don't change".
- `[-]` items are not set in `config.json` (e.g. time zone) — put a value in the config and they become available.
- `S` runs the module with only the ticked items. The selection applies to one run; `config.json` is not modified.

### Without the menu, from PowerShell

```powershell
.\Setup.ps1 -All                       # everything from the config
.\Setup.ps1 -Modules privacy,explorer  # only selected modules
.\Setup.ps1 -All -DryRun               # show what would be done, change nothing
.\Setup.ps1 -All -NoRestorePoint       # skip the restore point
.\Setup.ps1 -ConfigPath D:\my.json     # another config file
```

Modules: `apps`, `privacy`, `debloat`, `explorer`, `theme`, `system`.

## Configuring config.json

- Lines starting with `//` and trailing `//` comments are ignored.
- `true` — apply, `false` — skip. Every module has its own `"enabled"`.
- A trailing comma after the last list element is allowed.

### Apps via winget

Find the package ID:

```powershell
winget search "chrome"
```

Add it to `apps.winget`:

```json
"winget": [
  "Google.Chrome",
  { "id": "7zip.7zip", "name": "7-Zip" },
  { "id": "Microsoft.VisualStudioCode", "args": "--scope machine" },
  { "id": "Discord.Discord", "enabled": false }
]
```

Already installed apps are skipped.

### Installers from disk

`apps.local` — exe/msi files in `resources\installers`, installed silently:

```json
"local": [
  { "name": "MiniBin", "path": "resources\\installers\\MiniBin-6.1.1.1-Setup.exe", "args": "/S", "detect": "MiniBin" }
]
```

- `args` — silent-install switches: NSIS `/S`, Inno Setup `/VERYSILENT /NORESTART`; for msi the script adds `/qn` itself.
- `detect` — part of the name in "Apps & features", or a file path (`%ProgramFiles(x86)%\...`). If found, the install is skipped.

### Apps not in winget

`apps.manual` — things to install by hand. At the end of the module the script prints this list and, if `openManualLinks: true`, opens the links in the browser.

```json
"manual": [
  { "name": "Ocypus Digital", "url": "https://www.ocypus.com/download", "note": "download and install" }
]
```

### Removing built-in apps

See what is installed:

```powershell
Get-AppxPackage | Select-Object Name | Sort-Object Name
```

Add the name to `debloat.apps`. Wildcards are supported, e.g. `"*Xbox*"`. Removing the Xbox packages breaks sign-in for Microsoft Store games that need an Xbox account — if you play those, remove them from the list.

### Cursors and theme (theme module)

```json
"theme": {
  "enabled": true,
  "cursors": "dark",                    // "dark" | "light" | "" — a folder in resources\cursors
  "cursorsFolder": "resources\\cursors",
  "eject": { "enabled": true, "folder": "resources\\themes\\EJECT",
             "patchUxTheme": true, "themesFix": true, "themesService": true, "apply": true }
}
```

- **Cursors** are copied to `C:\Windows\Cursors\<scheme>`, the scheme is written to the registry and applied immediately (same as right-click → Install on `Install.inf`).
- **Theme** is a third-party `.msstyles`; Windows refuses it without a patch. The script silently installs `UltraUXThemePatcher.exe`, copies the theme to `C:\Windows\Resources\Themes`, applies `Themes Fix.reg` (so the theme does not touch icons, cursors or wallpaper) and enables the Themes service.
- If the patcher was just installed, **a reboot is required**; the theme is applied automatically at next logon. If the patcher was already present, the theme is applied right away.
- UltraUXThemePatcher modifies system files; a major Windows update may undo the patch — just run the `theme` module again.

### Explorer

Keys in the `explorer` section match the checklist items. Everything "Apply All" did in `resources\scripts\Explorer config.bat` is here: `compactView`, `hideStatusBar`, `hideHomeInNavPane`, `hideGalleryInNavPane`, `hideNetworkInNavPane`, `showRecycleBinInNavPane`, `hideDesktopRecycleBin`, `hideRecentFilesInExplorer`, `classicContextMenu`, `openExplorerToThisPC`.

## Safety

- A restore point is created before changes (disable with `createRestorePoint: false` or `-NoRestorePoint`).
- `-DryRun` prints every action tagged `[DRY]` without touching the system.
- The script does not disable Defender, UAC or Windows Update. From the internet it installs only what winget provides; from disk only files in `resources`.
- Removed built-in apps can be reinstalled from Microsoft Store.
- Every run writes a log to `logs\`.

## What applies after a reboot

Telemetry, power plan and most settings apply immediately. Theme, context menu and taskbar — after Explorer restarts (done automatically). Long paths, developer mode, verbose logon, UltraUXThemePatcher and the EJECT theme — after a reboot.

## Requirements

- Windows 10 / 11, PowerShell 5.1 (built in).
- winget ("App Installer" from Microsoft Store) — for the `apps` module.
- Administrator rights — `Run.bat` asks for them itself.

## Third-party components in resources

- **W11 Cursors Concept** — [Jepri Creations](https://www.deviantart.com/jepricreations). Free to share with attribution.
- **UltraUXThemePatcher** — [Manuel Hoefs](https://mhoefs.eu/software_uxtheme.php). Free utility.
- **MiniBin** — [e-sushi](https://e-sushi.net/minibin/). Free tray recycle bin.
- **EJECT theme** — a third-party Windows 11 theme; the author is credited inside the theme.
