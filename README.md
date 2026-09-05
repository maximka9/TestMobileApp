# SASAclicker

Мобильная 2D clicker/idle-игра про стримера SASAVOT. Версия **0.1.0**.
Выбирайте контент, проводите эфиры, разгоняйте хайп кликами, получайте монеты,
покупайте оборудование и реагируйте на события чата. Всё работает локально.

## Requirements

- **Godot 4.7.2 Standard**, GDScript; .NET не требуется.
- Windows/Linux/macOS для разработки; Android — основная мобильная платформа.
- Для APK: JDK 17, Android SDK и export templates той же версии Godot.
- [Официальная загрузка Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/).

## Run

Откройте `project.godot` через Import в Godot, затем нажмите **F6** для сцены
или **F5** для проекта. Главная сцена — `MainGame`.

В текущем рабочем каталоге `R:\Python\Sasavot` уже есть локальный Godot в
`.tools/godot/` (движок не включён в Git). Быстрый запуск из PowerShell:

```powershell
.\tools\run.ps1
```

Можно указать свой исполняемый файл:

```powershell
.\tools\run.ps1 -Godot 'C:\Tools\Godot\Godot_v4.7.2-stable_win64.exe'
```

На остальных платформах: `godot --path .`.

Игровой цикл:

1. Нажмите «Игры» или «Выбрать игру и начать эфир» и выберите контент.
2. Кликайте по комнате. Хайп повышает целевой онлайн; XP повышает уровень.
3. Раз в 5 секунд эфира начисляется доход. Первый микрофон стоит 10 монет.
4. Используйте «Мувы» / «Коллаб», принимайте или пропускайте события.
5. Покупайте улучшения. Завершите эфир и просмотрите статистику.
6. Нажмите «Продолжить». После перезапуска сохраняются деньги, уровень,
   XP, оборудование, общая статистика, выбранный контент и настройки.

Энергия восстанавливается между эфирами. В «Опциях» можно уменьшить анимацию
и вручную повторить сохранение после ошибки записи.

## Architecture

`app_bootstrap.gd` создаёт зависимости и управляет foreground-таймерами,
сохранением при паузе/выходе и диагностикой. Autoload и Service Locator отсутствуют.

- **Presentation:** `MainGameController`, `RoomView`, Containers/anchors.
  Контроллеры вызывают команды сервисов, не изменяя `PlayerState` напрямую.
- **Application:** `ClickHandler`, bootstrap и `SaveJobQueue`.
- **Domain:** типизированный `PlayerState`, Resources, `StreamService`,
  `EconomyService`, `ProgressionService`, `UpgradeService`, `MoveService`,
  `EventService`, `SaveService`. Логика использует RefCounted/Resource, не UI Nodes.
- **Infrastructure:** `FileSaveRepository`, `GameLogger`; зависимости передаются
  через конструкторы, контроллер сцены получает `configure()` после создания дерева.
- **Ports:** `SaveRepository`, `ILogger`, `RandomProvider`; тесты используют fake-адаптеры.

Состояния эфира: `OFFLINE → STREAMING → SUMMARY → OFFLINE`.
Статические `.tres` загружаются один раз. Для нового контента добавьте Resource
в `resources/stream_types/`; переписывать UI не нужно. Улучшения задают имя
характеристики и прибавку, обрабатываются общим алгоритмом.

Баланс находится в `GameConfig` и data Resources. `config/dev/` включает локальные
метрики FPS, времени кадра, записи, размера очереди и обработки событий;
`config/prod/` отключает диагностику. Длительное падение FPS пишет warning.
`GameMetrics.snapshot` можно использовать будущим telemetry adapter.

### Принятые решения по неоднозначностям ТЗ

- Энергия хранится как **0–100%**. Кресло даёт +10 единиц вместимости:
  расход мува равен `energy_cost / max_energy × 100`. Ограничение модели сохраняется.
- Порог XP округляется вверх до целого. Остаток переносится при каждом level up.
- Для онлайна есть внутренний дробный аккумулятор; видимое значение целое.
  Это предотвращает остановку роста из-за усечения после каждого `lerp`.
- `event_multiplier` контента усиливает положительный хайп и бонус онлайна
  обычных событий. События пива/коллаба используют обычный мув и его cooldown,
  поэтому не позволяют обойти ограничения.
- Множители разных временных эффектов перемножаются. Эффект одного события
  обновляет срок действия; не складывается сам с собой. Лучший ивент — принятый
  с наибольшим весом награды, определяемым в `StreamService`.
- Три попытки сохранения **всего**: первая после 250 мс, затем ожидания 500 и
  1000 мс при ошибках. После третьей ошибки автоматические попытки прекращаются
  до ручного повтора в «Опциях» или следующего запуска приложения.

## Persistence

Основной файл — `user://save.json`, версия формата 1. На Windows это обычно
`%APPDATA%/Godot/app_userdata/SASAclicker/save.json`.

Сохраняются версия, timestamp, level, XP, деньги, энергия, upgrades, статистика
и настройки. Частые запросы объединяются; есть периодический autosave и
немедленная запись при завершении эфира, паузе приложения и нормальном выходе.
Запись идёт в `.tmp`, затем заменяет основной файл. Перед заменой данные
сбрасываются на диск; проверяются ошибки открытия, записи и переименования.

Неизвестная версия, невалидные типы/диапазоны и испорченный JSON приводят к
безопасному новому состоянию и сообщению пользователю. Если возможно,
оригинал копируется в `save.json.damaged-<timestamp>.bak`.

Эфир, открытая карточка, cooldowns и временные бонусы не восстанавливаются после
закрытия процесса. Повторный запуск начинается в комнате. Offline income нет;
свёрнутое приложение не продолжает таймер эфира. Принудительное завершение ОС
может потерять изменения, ещё ожидающие записи.

## Testing

Используется небольшой исполняемый в самом Godot test runner на `SceneTree`,
без внешних addon-зависимостей. Это осознанное отклонение от предпочтения GdUnit4:
совместимость подтверждается запуском тестов именно на Godot 4.7.2.
Ошибки проверок дают ненулевой exit code. GDScript warnings трактуются как ошибки.

```powershell
.\tools\test.ps1
# Дополнительно настоящий рендерер и скриншоты (нужна графическая сессия):
.\tools\test.ps1 -Visual
```

Либо напрямую:

```text
godot --headless --editor --path . --quit
godot --headless --path . --script tests/test_runner.gd
godot --path . --script tests/visual_smoke.gd --resolution 360x640
```

Проверяются экономика, XP и переходы состояний, все улучшения и мувы, лимиты,
нехватка ресурсов, seeded RNG, события, сериализация, реальные файловые операции,
повреждённые сохранения, coalescing/retry и полный игровой цикл с нулевого баланса.
Тесты сцены используют отдельный репозиторий, не затрагивая пользовательский save.
`test.ps1` дополнительно запускает **два отдельных процесса**, чтобы подтвердить
сохранение прогресса после перезапуска.

`visual_smoke.gd` проверяет размеры 360×640, 360×800, 540×960 и 720×1280,
границы контролов, реальное событие мыши через viewport и формирует PNG в
`build/checks/`. Итог проверки см. [docs/verification.md](docs/verification.md).

## Android

Профиль `Android` подготовлен в `export_presets.cfg`:

- Package: `com.maximka9.sasaclicker`.
- Portrait, логическое разрешение 360×640, viewport/expand/integer, nearest.
- ARMv7 + ARM64, без разрешения Internet.
- Mouse-from-touch позволяет использовать тот же путь обработки нажатий.
- Safe-area отступы основной панели вычисляются из `DisplayServer`.

В проверенном Windows-окружении найден JDK 17, но **Android SDK отсутствует**:
нет стандартной папки SDK, `adb` и `sdkmanager`. APK не собран. SDK автоматически
не устанавливался. Редактор может сообщить `Unable to open Android 'build-tools'
directory.` при проверке Android-профиля; запуск игры от этого не зависит.

Для сборки:

1. Установите Android SDK из Android Studio либо официальных command-line tools.
2. Установите необходимые пакеты по
   [инструкции Godot для Android](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html):
   platform-tools, build-tools 35.0.1, platform android-35, command-line tools;
   при использовании Gradle также NDK 28.1.13356709 и CMake 3.10.2.4988404.
3. В Godot **Editor Settings → Export → Android** укажите Java SDK Path и
   Android SDK Path. Через **Manage Export Templates** установите templates 4.7.2.
4. Создайте `build/android`, выберите профиль Android и **Export Project → Debug**,
   либо выполните:

```powershell
New-Item -ItemType Directory -Force build/android
godot --headless --path . --export-debug Android build/android/sasaclicker-debug.apk
```

5. На подключённом тестовом устройстве:

```text
adb install -r build/android/sasaclicker-debug.apk
adb shell am start -n com.maximka9.sasaclicker/com.godot.game.GodotApp
```

Проверьте ориентацию, одиночные и быстрые touch-нажатия, вырезы экрана,
сворачивание/возврат и восстановление прогресса после перезапуска.
Ключи подписи и пароли храните вне репозитория; используйте локальные настройки
или поддерживаемые Godot переменные окружения. Release signing не настроен.
Для iOS потребуется macOS и Xcode; сборка iOS в этом MVP не выполнялась.

## Project structure

```text
project.godot / export_presets.cfg
config/dev, config/prod       — конфигурация окружений
src/app                      — composition root и lifecycle
src/core                     — config, result, logging, metrics, save queue
src/domain/models            — PlayerState и data Resource classes
src/domain/services          — игровая логика и save codec
src/domain/repositories      — persistence port
src/features/stream          — ClickHandler, MainGame, UI и пиксельная комната
src/infrastructure           — файловое сохранение и локальные логи
resources                    — 3 стрима, 5 upgrades, 2 мува, 5 событий
assets/icons                 — оригинальная SVG-иконка
tests                        — runner, fakes, restart probe, visual smoke
tools                        — PowerShell запуск и проверки
docs                         — результаты проверки
```

## Known limitations

- Android APK и проверка на физическом телефоне ожидают установки SDK/templates.
  60 FPS на Android — цель, а не подтверждённый результат desktop-тестов.
- Комната — оригинальные временные pixel placeholders, нарисованные кодом;
  портрет стримера условный. Звука и финального набора спрайтов пока нет.
- Баланс исходный, без длительного плейтеста. Улучшения ограничены 30 уровнями.
- Интерфейс пока только на русском; длинные списки прокручиваются.
- Нет backend, аккаунтов, Twitch API, рекламы, платежей, облака или телеметрии.

Следующие версии используют Semantic Versioning.
