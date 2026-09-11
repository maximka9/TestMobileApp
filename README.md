# SASAclicker

Current version: **0.11.0 — Visual Identity Update**.

Version 0.11 adds bundled streamer avatars, illustrated events and achievements,
distinct action-button variants, and a streamer-facing desktop composition. All
visual resources are local and have deterministic fallbacks; the save schema and
game balance are unchanged.

Avatars are real Twitch channel images bundled for 412 profiles (all six featured
creators included); 62 missing images use a neutral placeholder. No runtime network
request is needed. See [0.11 verification and sources](docs/v0.11-verification.md).

Follower-driven audience, incoming collaborations and 60-second candidate rotation;
the tenth slot features one of six creators. Achievement tree supports 60–180% zoom,
Fit, Ctrl+wheel, pinch and drag, with queued unlock notifications.
Organic stream followers, automatic locations, viewer-scaled chat and accelerated
stream time. Save schema 12 preserves legacy progression and records completed IRL
collaborations. Settings include a double-confirmed progress reset that preserves
user preferences. See [0.10 audit](docs/v0.10-audit.md),
[0.10.1 verification and Android smoke](docs/v0.10.1-verification.md) and [catalog sources](docs/v0.10-catalog.md).

## Gameplay systems

See [docs/gameplay_metrics.md](docs/gameplay_metrics.md).

Мобильная 2D clicker/idle-игра про SASAVOT. Актуальная рабочая версия находится
в `main`; переключать ветку после обычного clone не нужно.

## Requirements

- Godot **4.7.2 Standard**, без .NET.
- Python 3 для offline-тестов импортера; сторонние Python-пакеты для проверки не нужны.
- Графическая сессия для visual smoke. Windows PowerShell для скриптов `tools/`.
- Для APK отдельно нужны JDK 17, Android SDK и export templates той же версии Godot.

## Run

Клонируйте репозиторий, импортируйте `project.godot` в Godot и нажмите F5.
Из PowerShell:

```powershell
.\tools\run.ps1 -Godot 'C:\Tools\Godot\Godot_v4.7.2-stable_win64.exe'
```

Если движок лежит в `.tools/godot/`, путь можно не указывать. На других
платформах: `godot --path .`. Движок и SDK не включены в Git.

## Tests

```powershell
# Полная проверка, включая импорт, parser, миграцию и visual smoke:
.\tools\verify.ps1
# Только проверки стабилизации и затронутых систем:
.\tools\verify.ps1 -Targeted
# Для окружения без графической сессии (не заменяет visual acceptance):
.\tools\verify.ps1 -SkipVisual
```

Свой движок задаётся параметром `-Godot`. Любая ошибка процесса, parser или
assertion завершает verify с ненулевым кодом. `-NegativeControl` намеренно
возвращает `1`, проверяя сам harness; временный failing-script удаляется.
`tools/test.ps1` сохранён как совместимый вход в тот же verify.
Тесты не используют пользовательские сохранения. PNG и логи — в `build/checks/`.

## Android build

Профиль `Android` находится в `export_presets.cfg`; package —
`com.maximka9.sasaclicker`, ARMv7/ARM64, portrait, без Internet permission.
После локальной настройки SDK/templates используйте `tools/android-build.ps1`.
Проверка физического устройства отложена; desktop smoke её не заменяет.

## Architecture

`AppBootstrap` создаёт зависимости. Поток: UI → handlers/controllers → services
→ PlayerState/data. Игровая логика находится в `src/domain`, файловое сохранение
— в `src/infrastructure`, сцены/представление — в `src/features/stream`.
`GameConfig` хранит баланс; `.tres` — определения контента, сцен и достижений.
Нет runtime service locator, backend или сетевого импорта.

## Current features

- Эфиры Just Chatting, Dota, IRL и Cooking; хайп, онлайн, монеты и XP.
- При хайпе >=95 клики дают x1.15 XP; дробная часть накапливается в сессии.
- Усталость растёт во время эфира, между эфирами непрерывно снижается на 10 за реальную минуту.
  Множители хайпа и целевого онлайна раздельные; онлайн изменяется плавно.
- Комната, кухня и город IRL переключаются автоматически по формату эфира.
- YOUNG/CURRENT/SUCCESSFUL изображают одного SASAVOT во всех локациях.
- Короткие ролики расходуют источник подходящей темы; FAIL создаёт отдельный
  источник фейла. Расход сохраняется после перезапуска.
- Репутация, игровые отношения и коллаборации с **474 реальными профилями**.
  Требование каталога — **400+ подтверждённых профилей**, без заполнителей.
- Дерево достижений, косплей, аквариум, интерьер и переезд.
- Чёткий кириллический UI-шрифт, отдельный декоративный шрифт, nearest pixel-art.

## Persistence

`user://save.json`, схема **12**. Миграция поддерживает схемы 1–11.
Сохраняются экономика, карьера, источники, отношения, достижения, локация,
timestamp и запланированные коллаборации. Запись атомарная с ограниченными
повторами; повреждённый файл по возможности сохраняется в backup.

Незавершённый эфир при запуске сбрасывается в OFFLINE без наград и без
восстановления усталости за закрытое приложение. Новый отдых начинается после
загрузки. Для обычного offline-save интервал ограничен 8 часами, откат часов
не даёт восстановления. Денежного offline income нет.

## Known limitations

- Нет звука, backend, аккаунтов, платежей, облачных сохранений и сетевой игры.
- Интерфейс на русском; баланс ещё требует длительного плейтеста.
- Каталог — статический публичный снимок. Шансы/отношения являются игровыми.
  Неизвестные Twitch user IDs не выдуманы; verified IDs можно получить через
  developer-only Helix importer при наличии собственных credentials.
- Только CURRENT имеет четыре кадра; две другие стадии реагируют масштабом.
- Обработка исходных спрайтов в `tools/prepare_career_sprites.py` требует Pillow
  только при повторной подготовке artwork; игре и verify он не нужен.

Подробности: [контент и источники](docs/v0.5-content.md),
[assets](docs/v0.5-assets.md), [стабилизация](docs/v0.5.1-verification.md),
[история версий](CHANGELOG.md).
