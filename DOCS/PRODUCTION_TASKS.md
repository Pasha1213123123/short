# 📋 ЗАДАЧИ ДЛЯ ПОДГОТОВКИ К ПРОДАКШЕНУ

## 🔴 КРИТИЧЕСКИЕ ЗАДАЧИ (БЛОКЕРЫ)

### Безопасность

- **SEC-001**: Переместить Mux API Token в переменные окружения
  - Файл: `lib/services/mux_config.dart`
  - Использовать `flutter_dotenv` или `--dart-define`
  - Создать `.env.example` с шаблоном
- **SEC-002**: Переместить Mux Secret Key в переменные окружения
  - Файл: `lib/services/mux_config.dart`
  - Никогда не коммитить в репозиторий
- **SEC-003**: Настроить переменные окружения для Firebase
  - Файл: `lib/firebase_options.dart`
  - Использовать remote config или environment variables
- **SEC-004**: Добавить `.env` в `.gitignore`
  - Убедиться, что секреты не попадут в репозиторий
- **SEC-005**: Удалить `usesCleartextTraffic="true"` из AndroidManifest
  - Файл: `android/app/src/main/AndroidManifest.xml`
  - Установить в `false` или удалить строку
- **SEC-006**: Настроить Network Security Config для Android
  - Создать `android/app/src/main/res/xml/network_security_config.xml`
  - Разрешить только HTTPS соединения

### Конфигурация приложения

- **CONF-001**: Изменить Application ID для Android
  - Файл: `android/app/build.gradle`
  - Текущий: `com.example.calkulator`
  - Новый: `com.yourcompany.shortmovieplayer` (или другой уникальный)
- **CONF-002**: Изменить Bundle Identifier для iOS
  - Файл: `ios/Runner.xcodeproj/project.pbxproj` и `ios/Runner/Info.plist`
  - Текущий: `com.example.calkulator`
  - Новый: `com.yourcompany.shortmovieplayer`
- **CONF-003**: Создать production signing config для Android
  - Файл: `android/app/build.gradle`
  - Создать keystore файл
  - Настроить signing configs для release
- **CONF-004**: Обновить app labels
  - Android: `android/app/src/main/AndroidManifest.xml`
  - iOS: `ios/Runner/Info.plist`
  - Текущий: "calkulator"
  - Новый: "Short Movie Player" или другое название
- **CONF-005**: Заменить test Ad Unit ID на production
  - Файл: `android/app/src/main/AndroidManifest.xml`
  - Текущий: `ca-app-pub-3940256099942544~3347511713` (test)
  - Заменить на реальный Ad Unit ID из AdMob
- **CONF-006**: Обновить версию приложения
  - Файл: `pubspec.yaml`
  - Текущий: `1.0.0+1`
  - Определить финальную версию для релиза

---

## 🟠 ВАЖНЫЕ ЗАДАЧИ

### Тестирование

- **TEST-001**: Написать unit тесты для `ShortVideosNotifier`
  - Тесты для `fetchInitialVideos()`
  - Тесты для `loadMoreVideos()`
  - Тесты для `refresh()`
  - Тесты для обработки ошибок
- **TEST-002**: Написать unit тесты для `VideoCacheManager`
  - Тесты для LRU кэша
  - Тесты для предзагрузки
  - Тесты для cleanup
- **TEST-003**: Написать unit тесты для `MuxApiService`
  - Моки для HTTP запросов
  - Тесты для успешных ответов
  - Тесты для обработки ошибок
- **TEST-004**: Написать widget тесты для `ShortsPageView`
  - Тесты для отображения списка
  - Тесты для свайпов
  - Тесты для pull-to-refresh
- **TEST-005**: Написать widget тесты для `ShortPlayerScreen`
  - Тесты для воспроизведения видео
  - Тесты для паузы/плей
  - Тесты для UI элементов
- **TEST-006**: Настроить CI/CD для автоматического запуска тестов
  - GitHub Actions или GitLab CI
  - Запуск тестов при каждом PR
- **TEST-007**: Достичь покрытия кода минимум 60%
  - Использовать `flutter test --coverage`
  - Анализировать отчеты покрытия

### Аналитика

- **ANALYTICS-001**: Добавить трекинг просмотров видео
  - Событие: `video_viewed`
  - Параметры: `video_id`, `title`, `duration`
- **ANALYTICS-002**: Добавить трекинг свайпов
  - Событие: `video_swiped`
  - Параметры: `direction`, `from_video_id`, `to_video_id`
- **ANALYTICS-003**: Добавить трекинг времени просмотра
  - Событие: `video_watch_time`
  - Параметры: `video_id`, `watch_time_seconds`
- **ANALYTICS-004**: Добавить трекинг ошибок загрузки
  - Событие: `video_load_error`
  - Параметры: `video_id`, `error_type`, `error_message`
- **ANALYTICS-005**: Добавить трекинг взаимодействий (Like, Save, Share)
  - События: `video_liked`, `video_saved`, `video_shared`
  - Параметры: `video_id`
- **ANALYTICS-006**: Настроить Firebase Performance Monitoring
  - Трекинг времени загрузки видео
  - Трекинг времени ответа API
  - Custom traces для ключевых операций

### Обработка ошибок и логирование

- **LOG-001**: Установить пакет для логирования
  - Добавить `logger` в `pubspec.yaml`
  - Или использовать `dart:developer` log
- **LOG-002**: Заменить все `print()` на proper logging
  - Файлы: `lib/services/mux_api_service.dart`
  - Файлы: `lib/services/video_cache_manager.dart`
  - Файлы: `lib/main.dart`
- **LOG-003**: Настроить уровни логирования
  - Debug: только в development
  - Info: важные события
  - Warning: потенциальные проблемы
  - Error: ошибки с stack trace
- **LOG-004**: Добавить user-friendly error messages
  - Создать `lib/utils/error_messages.dart`
  - Локализованные сообщения об ошибках
  - Понятные сообщения для пользователей
- **LOG-005**: Реализовать retry механизм для API запросов
  - Добавить exponential backoff
  - Максимум 3 попытки
  - Логирование неудачных попыток
- **LOG-006**: Добавить offline mode handling
  - Определение состояния сети
  - Кэширование последних загруженных видео
  - Сообщение пользователю об отсутствии сети

### Документация

- **DOC-001**: Обновить README.md
  - Удалить упоминания YouTube player
  - Добавить информацию о Mux
  - Обновить список технологий
  - Добавить скриншоты
- **DOC-002**: Создать архитектурную документацию
  - Описание структуры проекта
  - Диаграммы компонентов
  - Потоки данных
- **DOC-003**: Добавить инструкции по настройке окружения
  - Установка зависимостей
  - Настройка переменных окружения
  - Настройка Firebase
  - Настройка Mux
- **DOC-004**: Добавить инструкции по сборке для продакшена
  - Android release build
  - iOS release build
  - Подписание приложений
- **DOC-005**: Создать CHANGELOG.md
  - Формат: Keep a Changelog
  - Задокументировать все изменения
- **DOC-006**: Добавить API документацию
  - Описание endpoints Mux API
  - Примеры запросов
  - Обработка ошибок

---

## 🟡 УЛУЧШЕНИЯ

### Производительность

**Примечание:** ✅ Кеширование видео контроллеров уже реализовано через `VideoCacheManager`:

- ✅ LRU кеш для VideoPlayerController (до 5 видео)
- ✅ Предзагрузка соседних видео
- ✅ Очередь предзагрузки с приоритетами
- **PERF-001**: Добавить кэширование метаданных видео
  - Использовать `shared_preferences` или `hive`
  - Кэшировать на 24 часа
  - **Статус:** НЕ реализовано - метаданные загружаются каждый раз
- **PERF-002**: Сделать размер кэша настраиваемым
  - Текущий: 5 видео (захардкожено в `VideoCacheManager._maxCacheSize`)
  - Добавить конфигурацию в settings
  - **Статус:** НЕ реализовано - размер фиксированный
- **PERF-003**: Добавить image caching для thumbnails
  - Использовать `cached_network_image`
  - Кэшировать превью изображения
  - **Статус:** НЕ реализовано - изображения загружаются каждый раз
- **PERF-004**: Оптимизировать размер APK/IPA
  - Анализ размера: `flutter build apk --analyze-size`
  - Удалить неиспользуемые ресурсы
  - Оптимизировать изображения
- **PERF-005**: Настроить ProGuard/R8 для Android
  - Файл: `android/app/proguard-rules.pro`
  - Минимизация и обфускация кода

### Пользовательский опыт

- **UX-001**: Улучшить loading states
  - Skeleton screens вместо CircularProgressIndicator
  - Плавные анимации загрузки
- **UX-002**: Добавить empty states
  - Когда нет видео
  - Когда нет результатов поиска
- **UX-003**: Улучшить error states
  - Retry кнопка
  - Понятные сообщения об ошибках
  - Иконки для разных типов ошибок
- **UX-004**: Реализовать функционал Like
  - Сохранение в локальное хранилище
  - Синхронизация с сервером (если есть backend)
- **UX-005**: Реализовать функционал Save
  - Сохранение списка избранных видео
  - Экран с сохраненными видео
- **UX-006**: Реализовать функционал Share
  - Нативный share dialog
  - Deep linking для видео
- **UX-007**: Реализовать фильтрацию по жанрам
  - Фильтрация списка видео
  - Сохранение выбранного фильтра
- **UX-008**: Добавить настройки
  - Качество видео (auto, 720p, 1080p)
  - Автоплей
  - Уведомления
- **UX-009**: Добавить haptic feedback
  - При свайпах
  - При взаимодействиях
- **UX-010**: Создать экран загрузки и редактирования видео
  - Экран загрузки видео в Mux
  - Выбор видео из галереи или камеры
  - Прогресс-бар загрузки
  - Форма редактирования метаданных (title, description, genres)
  - Сохранение метаданных в Mux через passthrough
  - Обновление существующих видео (редактирование метаданных)
  - Валидация полей формы
  - Обработка ошибок загрузки
  - Успешное уведомление после загрузки
  - **Статус:** НЕ реализовано - требуется новая функциональность
  - **Зависимости:** Расширение MuxApiService (UX-010-API)
- **UX-010-API**: Расширить MuxApiService для загрузки и обновления видео
  - Метод `createDirectUpload()` - создание direct upload URL в Mux
  - Метод `uploadVideoToMux()` - загрузка видео файла через direct upload
  - Метод `updateAssetMetadata()` - обновление метаданных через passthrough
  - Метод `getUploadStatus()` - проверка статуса загрузки (pending, ready, errored)
  - Метод `deleteAsset()` - удаление видео (опционально)
  - Обработка multipart/form-data для загрузки
  - Обработка ошибок загрузки
  - **Статус:** НЕ реализовано - требуется расширение API сервиса
  - **Документация:** [https://docs.mux.com/api-reference#video/operation/create-direct-upload](https://docs.mux.com/api-reference#video/operation/create-direct-upload)
- **UX-010-DEPS**: Добавить зависимости для работы с файлами
  - `image_picker` - выбор видео из галереи/камеры
  - `file_picker` - альтернатива для выбора файлов
  - `path_provider` - получение путей для временных файлов
  - Проверка размера файла перед загрузкой
  - Валидация формата видео (mp4, mov, etc.)
  - **Статус:** НЕ реализовано - требуется установка пакетов

### Архитектура

- **ARCH-001**: Разделить код на модули
  - Создать `lib/models/movie.dart`
  - Переместить провайдеры в `lib/providers/`
  - Переместить экраны в `lib/screens/`
  - Создать `lib/widgets/` для переиспользуемых виджетов
- **ARCH-002**: Удалить дубликат Movie класса
  - Оставить только один в `lib/models/movie.dart`
  - Обновить импорты
- **ARCH-003**: Создать repository pattern
  - `lib/repositories/video_repository.dart`
  - Абстракция для работы с данными
- **ARCH-004**: Разбить большие виджеты
  - `ShortPlayerScreen` на меньшие компоненты
  - Вынести UI элементы в отдельные виджеты
- **ARCH-005**: Добавить dependency injection
  - Использовать Riverpod для DI
  - Четкое разделение зависимостей

### Линтинг и качество кода

- **LINT-001**: Включить базовые правила линтинга
  - Файл: `analysis_options.yaml`
  - Раскомментировать основные правила
- **LINT-002**: Настроить строгие правила
  - Включить strict mode
  - Настроить правила для продакшена
- **LINT-003**: Добавить pre-commit hooks
  - Проверка линтинга перед коммитом
  - Автоматическое форматирование
- **LINT-004**: Настроить автоматическое форматирование
  - `dart format .` в CI/CD
  - Проверка форматирования в PR

### Международная локализация

- **I18N-001**: Добавить flutter_localizations
  - В `pubspec.yaml`
  - В `MaterialApp`
- **I18N-002**: Вынести все строки в .arb файлы
  - `lib/l10n/app_en.arb`
  - `lib/l10n/app_ru.arb`
- **I18N-003**: Обновить все hardcoded строки
  - Заменить на `AppLocalizations.of(context)`

### Доступность

- **A11Y-001**: Добавить semantic labels
  - Для всех интерактивных элементов
  - Использовать `Semantics` widget
- **A11Y-002**: Протестировать с screen readers
  - TalkBack для Android
  - VoiceOver для iOS
- **A11Y-003**: Поддержать системные настройки
  - Увеличение шрифта
  - Высокий контраст

### CI/CD

- **CI-001**: Настроить GitHub Actions / GitLab CI
  - Создать `.github/workflows/ci.yml`
  - Или `.gitlab-ci.yml`
- **CI-002**: Автоматическая сборка
  - Android APK
  - iOS IPA (для macOS runners)
- **CI-003**: Автоматический запуск тестов
  - При каждом push
  - При создании PR
- **CI-004**: Автоматическая проверка линтинга
  - Запуск `flutter analyze`
  - Блокировка PR при ошибках
- **CI-005**: Автоматический деплой
  - TestFlight для iOS
  - Google Play Internal Testing для Android

### Мониторинг

- **MON-001**: Настроить алерты в Firebase Crashlytics
  - Email уведомления при критических ошибках
  - Slack/Telegram интеграция
- **MON-002**: Добавить custom metrics
  - Время загрузки видео
  - Процент успешных загрузок
  - Среднее время просмотра
- **MON-003**: Настроить мониторинг API
  - Response times
  - Error rates
  - Rate limiting
- **MON-004**: Мониторинг использования памяти
  - Трекинг утечек памяти
  - Оптимизация кэша

---

## 📊 ПРОГРЕСС

**Общий прогресс:** 0/103 задач выполнено

### По категориям:

- 🔴 Критические: 0/12
- 🟠 Важные: 0/30
- 🟡 Улучшения: 0/61 (добавлено: UX-010, UX-010-API, UX-010-DEPS)

---

## 📝 ЗАМЕТКИ

- Приоритизировать задачи по порядку: сначала критические, потом важные
- Можно работать параллельно над задачами из разных категорий
- Регулярно обновлять прогресс
- Отмечать выполненные задачи галочкой

---

**Последнее обновление:** 2026