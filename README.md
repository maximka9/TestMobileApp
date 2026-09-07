# SASAclicker

Мобильная 2D clicker/idle-игра про стримера SASAVOT. Версия **0.2.0**.
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

1. Нажмите «Игры» или «Начать эфир» и выберите контент.
2. Кликайте по комнате. Хайп повышает целевой онлайн; XP повышает уровень.
3. Раз в 5 секунд эфира начисляется доход. Первый микрофон стоит 10 монет.
4. Используйте «Мувы» / «Коллаб», принимайте или пропускайте события.
5. Покупайте улучшения. Завершите эфир и просмотрите статистику.
6. Нажмите «Продолжить». После перезапуска сохраняются деньги, уровень,
   XP, оборудование, общая статистика, выбранный контент и настройки.

Энергия восстанавливается между эфирами. Кнопка «•••» открывает настройки: можно уменьшить анимацию
и вручную повторить сохранение после ошибки записи.

## Visual design

- **Red/black SASA room:** почти чёрная комната, бордовые стены, красная подсветка,
  холодный свет мониторов. Слои комнаты находятся в `room_view.tscn`.
- **Pixel-art character reference:** оригинальный подробный спрайт по предоставленному
  фото: коричневые волосы, тёмные брови, чёрные наушники и свободная белая футболка.
  Фото используется только как ориентир и не включено в игровые assets.
- **Friday 13 homage:** собственная пиксельная интерпретация хоккейной маски и числа 13.
- **Firefighter reference:** оригинальная рамка с пожарным шлемом и надписью «ПОЖАРНЫЙ».
- Четыре кадра персонажа, click reaction и подсветка при высоком хайпе;
  `reduced_motion` отключает сильные движения. Чат ограничен небольшой очередью,
  новые сообщения появляются снизу; скорость зависит от хайпа.
- Статический интерфейс редактируется в `main_game.tscn`, цвета и StyleBox —
  в `resources/themes/sasa_theme.tres`. Энергия остаётся зелёной, ошибки красными.
- Floating feedback переиспользует 16 Label. Каждый клик не создаёт новый Label/Tween.
- `viewport + expand + fractional`, nearest и pixel snapping заполняют экран на
  некратных разрешениях. Компромисс: физические размеры отдельных пикселей при
  дробном масштабе могут отличаться на один экранный пиксель. [Документация Godot](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html).

## Architecture

`app_bootstrap.gd` создаёт зависимости и управляет foreground-таймерами,
сохранением при паузе/выходе и диагностикой. Autoload и Service Locator отсутствуют.

- **Presentation:** статические `main_game.tscn` и `room_view.tscn`,
  `MainGameController`, `RoomView`, `FloatingTextPool`, Containers/anchors.
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
В 0.2 добавлены строгий лимит конкретного upgrade, отказ bootstrap при неверных
зависимостях, инстанцирование новой комнаты, нативный touch без дублирования мышью
и ограниченный пул feedback.
Тесты сцены используют отдельный репозиторий, не затрагивая пользовательский save.
`test.ps1` дополнительно запускает **два отдельных процесса**, чтобы подтвердить
сохранение прогресса после перезапуска.

`visual_smoke.gd` проверяет 360×640, 360×800, 375×812, 390×844, 393×852,
412×915, 540×960, 720×1280 и 1080×2400. Проверяются границы контролов,
размеры кнопок ≥48, модальные окна, смоделированные safe-area отступы,
фактический масштаб viewport и ввод touch/mouse. PNG и измерения находятся в
`build/checks/v0.2/`. Итог проверки — [docs/verification.md](docs/verification.md).

## Android

Профиль `Android` подготовлен в `export_presets.cfg`:

- Package: `com.maximka9.sasaclicker`.
- Portrait, логическое разрешение 360×640, viewport/expand/fractional, nearest.
- ARMv7 + ARM64, без разрешения Internet.
- `InputEventScreenTouch` обрабатывается явно. Mouse events с
  `InputEvent.DEVICE_ID_EMULATION` игнорируются комнатой; обычная мышь работает.
- Safe-area отступы основной панели и модальных окон вычисляются из `DisplayServer`.

Для версии 0.2 установлены локальные OpenJDK 17, Android SDK/platform-tools и
Godot 4.7.2 export templates. Инструменты, настройки экспортера и debug-ключ
находятся внутри игнорируемой `.tools/`; в Git они не входят.
Воспроизводимая сборка — `tools/android-build.ps1`; текущие версии инструментов,
проверка manifest и сведения о подключённых устройствах описаны в
[Android verification](docs/android_verification.md).

```powershell
.\tools\android-build.ps1
```

Проверка 2026-09-07:

| Проверка | Результат |
| --- | --- |
| APK 0.2.0 (2), подпись, portrait | PASS — `build/android/sasaclicker-debug.apk` |
| Устройство / версия Android | Не подключено / не определена |
| Touch / safe area | Автотесты PASS; на телефоне не проверены |
| Сохранение после перезапуска | Desktop PASS; на телефоне не проверено |
| FPS | Desktop 60; на телефоне не измерен |

Для сборки:

1. Установите Android SDK из Android Studio либо официальных command-line tools.
2. Установите необходимые пакеты по
   [инструкции Godot для Android](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html):
   platform-tools, build-tools 36.1.0, platform android-36, command-line tools;
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
src/features/stream          — ClickHandler, статические сцены, UI и пул feedback
src/infrastructure           — файловое сохранение и локальные логи
resources                    — 3 стрима, 5 upgrades, 2 мува, 5 событий
assets/characters, room       — оригинальные небольшие PNG-спрайты
assets/icons                 — оригинальная SVG-иконка
resources/themes             — централизованная красно-чёрная тема
tests                        — runner, fakes, restart probe, visual smoke
tools                        — PowerShell запуск и проверки
docs                         — результаты проверки
```

## Known limitations

- Проверка на физическом телефоне требует подключённого и авторизованного adb-устройства.
  Desktop FPS и автоматические input-тесты не заменяют измерения на Android.
- Персонаж и декорации — оригинальная стилизация по референсу. Звука пока нет.
- Баланс исходный, без длительного плейтеста. Улучшения ограничены 30 уровнями.
- Интерфейс пока только на русском; длинные списки прокручиваются.
- Нет backend, аккаунтов, Twitch API, рекламы, платежей, облака или телеметрии.

Следующие версии используют Semantic Versioning.

## Социальные механики (0.4, фаза 3)

Репутация и отношения доступны через «Опции → Профиль и отношения».
Помощь и резкий ответ в событиях сообщества меняют игровые оценки.
Значения отношений, совместимость и вероятности принятия коллабов — вымышленные
игровые механики. Они не являются утверждениями о реальных людях и не предсказывают
их поведение. Авторы текущих социальных событий также вымышлены.
Движок коллабораций добавляется в следующей фазе.
