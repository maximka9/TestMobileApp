# SASAclicker

Current version: **0.7.0**.

Follower-driven audience, incoming collaborations and 120-second candidate rotation;
achievement tree supports drag, touch and Shift+wheel without visible scrollbars.
Organic stream followers, automatic locations, viewer-scaled chat and accelerated
stream time. Save schema 10 remains compatible. See [0.7 verification](docs/v0.7-verification.md).

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
- Усталость растёт во время эфира, между эфирами снижается на 2 за полную минуту.
  Множители хайпа и целевого онлайна раздельные; онлайн изменяется плавно.
- Комната и кухня переключаются отдельными сценами. Город пока «СКОРО».
- YOUNG/CURRENT/SUCCESSFUL изображают одного SASAVOT во всех локациях.
- Короткие ролики расходуют источник подходящей темы; FAIL создаёт отдельный
  источник фейла. Расход сохраняется после перезапуска.
- Репутация, игровые отношения и коллаборации с **473 реальными профилями**.
  Требование каталога — **400+ подтверждённых профилей**, без заполнителей.
- Дерево достижений, косплей, аквариум, интерьер и переезд.
- Чёткий кириллический UI-шрифт, отдельный декоративный шрифт, nearest pixel-art.

## Persistence

`user://save.json`, схема **9**. Миграция поддерживает схемы 1–8.
Сохраняются экономика, карьера, источники, отношения, достижения, локация,
timestamp и остаток неполной минуты отдыха. Запись атомарная с ограниченными
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
