# Проверка SASAclicker 0.2.0

Дата: 2026-09-07. Godot 4.7.2.stable.official.ed1daf0bf, Windows x64,
Compatibility, NVIDIA GeForce RTX 3060.

- Импорт: PASS, 0 parser errors, 0 GDScript warnings.
- Тесты: **119 passed, 0 failed**, включая 99 исходных.
- Сохранение и загрузка в отдельных процессах: **PASS / PASS**.
- Visual smoke: **0 failures**. Разрешения: 360×640, 360×800, 375×812,
  390×844, 393×852, 412×915, 540×960, 720×1280, 1080×2400.
- Проверены границы UI, модальные окна, кнопки ≥48, отсутствие внешних полос,
  смоделированная safe area, touch и подавление эмулированной мыши.
- Пул feedback: 16 элементов; после истечения времени активных 0;
  500 кликов не увеличивают число узлов.
- Desktop: 60 FPS, frame 2.301 ms, static memory 40 022 947 bytes, 154 узла.
- Android APK: **PASS**, версия 0.2.0 (2), portrait, подпись проверена.
  Подробности: [Android verification](android_verification.md).

Проверены лимиты upgrades по собственной конфигурации, отказ bootstrap при
неверном родителе/ресурсе, восстановление сохранений и полный игровой цикл.
PNG OFFLINE/LIVE/high hype, модальных окон, summary и всех разрешений,
JSON измерений и логи: `build/checks/v0.2/` (не входят в Git).
Тестовые сохранения изолированы от обычного прогресса.

## Повторный запуск

```powershell
.\tools\test.ps1 -Visual
.\tools\android-build.ps1
```

JDK 17, Android SDK и templates установлены в `.tools/`.
Android-устройство и эмулятор не подключены: установка, touch, safe area,
background/resume, сохранения и FPS на телефоне **не проверены**.
Desktop-измерения не являются результатами Android. iOS не собирался.
