# Детальный план реализации MOVE_UPLOAD_TASK

Этот план описывает процесс переноса функционала загрузки видео из главного экрана в настройки.

## 1. Подготовка и изучение кода
- [ ] Найти блок `floatingActionButton` в `lib/screens/shorts_page_view.dart`.
- [ ] Изучить текущую логику паузы/возобновления плеера в этом блоке.

## 2. Удаление кнопки с главного экрана
- [ ] **Файл:** `lib/screens/shorts_page_view.dart`
- [ ] Удалить свойство `floatingActionButton` из `Scaffold`.
- [ ] Удалить свойство `floatingActionButtonLocation` из `Scaffold`.
- [ ] Убедиться, что `Padding` (если он был завязан на FAB) в ленте теперь корректен.

## 3. Добавление точки входа в настройках
- [ ] **Файл:** `lib/screens/settings_screen.dart`
- [ ] Добавить импорт `import 'upload_screen.dart';` (если его нет).
- [ ] Добавить импорт `import '../utils/constants.dart';` для использования задержек.
- [ ] В `ListView` добавить `ListTile`:
  ```dart
  ListTile(
    leading: Icon(Icons.video_call, color: colorScheme.primary),
    title: Text(loc.uploadVideo),
    trailing: const Icon(Icons.chevron_right),
    onTap: () async {
      // Логика управления плеером
    },
  ),
  ```

## 4. Перенос логики управления плеером
- [ ] Реализовать в `onTap` (SettingsScreen) следующую последовательность:
    1.  `final controller = ref.read(currentVideoControllerProvider);`
    2.  `if (controller != null && controller.value.isPlaying) await controller.pause();`
    3.  `await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UploadScreen()));`
    4.  `await Future.delayed(AppConstants.navigationDelay);`
    5.  `final freshController = ref.read(currentVideoControllerProvider);`
    6.  `if (freshController != null && !freshController.value.isPlaying) await freshController.play();`

## 5. Валидация
- [ ] Проверить отсутствие кнопки на главном экране.
- [ ] Проверить наличие пункта в настройках.
- [ ] Убедиться, что при переходе видео ставится на паузу и возобновляется при возврате.
