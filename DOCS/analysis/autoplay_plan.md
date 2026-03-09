# Детальный план реализации AUTOPLAY_NEXT_VIDEO_TASK

Этот план описывает пошаговое внедрение функции автоматического перехода к следующему видео.

## 1. Исследование и подготовка
- [ ] Изучить `lib/screens/short_player_screen.dart` для определения места инициализации `VideoPlayerController`.
- [ ] Проверить текущую логику зацикливания видео (looping).

## 2. Управление состоянием (State Management)
- [ ] **Файл:** `lib/providers.dart`
- [ ] Создать `AutoplayNotifier` (на базе `StateNotifier`).
- [ ] Реализовать сохранение/загрузку флага `autoplay` через `SharedPreferences`.
- [ ] Создать `autoplayProvider`.

## 3. Интеграция с настройками
- [ ] **Файл:** `lib/screens/settings_screen.dart`
- [ ] Заменить статический `SwitchListTile` на динамический, использующий `ref.watch(autoplayProvider)`.
- [ ] Реализовать метод `onChanged`, сохраняющий новое состояние.

## 4. Детектирование окончания видео
- [ ] **Файл:** `lib/screens/short_player_screen.dart`
- [ ] Добавить `VoidCallback? onVideoFinished` в конструктор виджета.
- [ ] В `initState` или месте инициализации контроллера добавить слушателя `_videoListener`.
- [ ] В `_videoListener` добавить логику: если `position == duration`, вызывать `widget.onVideoFinished?.call()`.
- [ ] **Важно:** Учитывать флаг `isAutoplayEnabled`. Если он `false`, контроллер должен просто зацикливаться (`setLooping(true)`).

## 5. Программный переход (Auto-swipe)
- [ ] **Файл:** `lib/screens/shorts_page_view.dart`
- [ ] Передать в `ShortPlayerScreen` колбэк:
  ```dart
  onVideoFinished: () {
    if (ref.read(autoplayProvider)) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  ```
- [ ] Проверить граничные условия (последнее видео в списке).

## 6. Валидация
- [ ] Проверить, что при выключенном Autoplay видео зацикливается.
- [ ] Проверить, что при включенном Autoplay происходит плавный переход.
- [ ] Убедиться, что настройка сохраняется после перезапуска приложения.
