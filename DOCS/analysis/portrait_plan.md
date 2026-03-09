# Детальный план реализации PORTRAIT_ORIENTATION_TASK

Этот план описывает фиксацию приложения в портретной ориентации на всех поддерживаемых платформах.

## 1. Программная фиксация во Flutter (Универсально)
- [ ] **Файл:** `lib/main.dart`
- [ ] Импортировать `package:flutter/services.dart`.
- [ ] В методе `main()` вызвать `WidgetsFlutterBinding.ensureInitialized()`.
- [ ] Установить предпочтительную ориентацию:
  ```dart
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown, // Опционально
  ]);
  ```
- [ ] Обернуть `runApp()` в вызов метода, чтобы ориентация применилась до запуска UI.

## 2. Конфигурация для Android
- [ ] **Файл:** `android/app/src/main/AndroidManifest.xml`
- [ ] Найти тег `<activity>` для `MainActivity`.
- [ ] Добавить атрибут: `android:screenOrientation="portrait"`.
- [ ] Это предотвратит поворот экрана на уровне системы еще до загрузки Flutter.

## 3. Конфигурация для iOS
- [ ] **Файл:** `ios/Runner/Info.plist`
- [ ] Найти ключ `UISupportedInterfaceOrientations`.
- [ ] Удалить значения:
    *   `UIInterfaceOrientationLandscapeLeft`
    *   `UIInterfaceOrientationLandscapeRight`
- [ ] Оставить только `UIInterfaceOrientationPortrait`.
- [ ] Повторить то же самое для `UISupportedInterfaceOrientations~ipad`, если требуется фиксация и для планшетов.

## 4. Валидация
- [ ] Запустить приложение на симуляторе/реальном устройстве.
- [ ] Повернуть устройство в альбомный режим.
- [ ] Убедиться, что интерфейс не меняет ориентацию и остается в портретном режиме.
- [ ] Проверить экран видеоплеера отдельно (так как часто плееры пытаются перехватить управление ориентацией).
