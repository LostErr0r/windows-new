# resources — файлы, которые ставятся с диска

Сюда кладётся всё, чего нет в winget. Пути прописаны в `config.json`.

```
resources\
├─ installers\   exe/msi установщики          → config.json: apps.local
├─ cursors\      схемы курсоров               → config.json: theme.cursors / theme.cursorsFolder
│   ├─ dark\cursor\Install.inf + *.cur/*.ani
│   └─ light\cursor\Install.inf + *.cur/*.ani
├─ themes\       темы Windows (.msstyles)     → config.json: theme.eject.folder
│   └─ EJECT\    UltraUXThemePatcher.exe, Eject Theme\Themes\Eject.theme + Eject\Eject.msstyles
└─ scripts\      bat/ps1 для ручного запуска  (Explorer config.bat — его настройки уже в config.json → explorer)
```

## Как добавить

**Установщик**: положите exe/msi в `installers\` и добавьте строку в `apps.local`:

```json
{ "name": "Программа", "path": "resources\\installers\\Setup.exe", "args": "/S", "detect": "Программа" }
```

Ключи тихой установки: NSIS `/S`, Inno Setup `/VERYSILENT /NORESTART`, InstallShield `/s /v"/qn"`, msi — ничего (скрипт сам добавит `/qn`).
`detect` — часть названия в «Установка и удаление программ»; если найдено, установка пропускается.

**Курсоры**: папка с `Install.inf` в формате «ПКМ → Установить» кладётся как `cursors\<имя>\cursor\`; в `config.json` → `theme.cursors` впишите `<имя>`.

**Тема**: новая тема — новая папка в `themes\` с тем же устройством, что у EJECT (`<Имя> Theme\Themes\<Имя>.theme` и `Themes\<Имя>\<Имя>.msstyles`). Пока модуль theme умеет только одну тему, путь к ней — `theme.eject.folder`.

**Скрипты**: `scripts\` — для bat/ps1, которые вы запускаете руками; скрипт Setup их не трогает.
