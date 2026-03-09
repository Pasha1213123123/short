# 📱 Фиксировать ориентацию только портретно

Отдельная задача по фиксации ориентации приложения в портретном режиме.

---

## Задача

**ORIENT-001**: Фиксировать ориентацию только портретно

- **Описание:** Приложение должно работать только в портретной ориентации. Альбомная ориентация должна быть отключена.
- **Платформы:** Android, iOS
- **Приоритет:** Улучшение (UX)

### Реализация

**Android**

- Файл: `android/app/src/main/AndroidManifest.xml`
- В `<activity>` добавить или изменить:
  - `android:screenOrientation="portrait"`
- Либо в `MainActivity` (Kotlin/Java): вызвать `requestedOrientation(ActivityInfo.SCREEN_ORIENTATION_PORTRAIT)`.

**iOS**

- Файл: `ios/Runner/Info.plist`
- Указать только портретные ориентации в `UISupportedInterfaceOrientations` (удалить `UIInterfaceOrientationLandscapeLeft`, `UIInterfaceOrientationLandscapeRight`).
- Либо в Xcode: Target → General → Deployment Info → снять галочки с Landscape Left/Right.

**Flutter (если нужна программная фиксация)**

- Пакет: `services` из Flutter SDK — `SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])` в `main()` перед `runApp()`.

### Статус

- [ ] Не выполнено

---

**Последнее обновление:** 2026
