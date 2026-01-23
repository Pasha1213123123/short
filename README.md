# Short Movie Player

Приложение для просмотра коротких видео (аналог TikTok/Shorts), построенное на Flutter с использованием **Mux Data API** для стриминга контента.

## 🛠 Технологии

*   **Flutter** (Dart)
*   **State Management:** Riverpod
*   **Video Streaming:** Mux API (HLS)
*   **Video Player:** video_player + caching logic
*   **Backend/Analytics:** Firebase (Core, Crashlytics, Analytics)
*   **Utils:** flutter_dotenv (безопасность), logger (логирование)

## 🚀 Начало работы

### Предварительные требования
*   Flutter SDK >= 3.2.0
*   Аккаунт Mux (для получения API ключей)
*   Аккаунт Firebase

### Настройка окружения (DOC-003)

1.  **Клонируйте репозиторий.**
2.  **Создайте файл `.env`** в корне проекта (используйте `.env.example` как шаблон):
    ```properties
    MUX_API_TOKEN=ВАШ_ТОКЕН
    MUX_SECRET_KEY=ВАШ_СЕКРЕТНЫЙ_КЛЮЧ
    ```
3.  **Установите зависимости:**
    ```bash
    flutter pub get
    ```

### Запуск
```bash
flutter run
🏗 Архитектура (DOC-002)
Проект следует принципам Clean Architecture в упрощенном виде:
lib/services/:
MuxApiService: Отвечает за HTTP-запросы к Mux.
VideoCacheManager: Умное кэширование и предзагрузка (Preload) следующего/предыдущего видео для мгновенного воспроизведения.
lib/utils/:
Централизованное логирование (logger.dart) и сообщения об ошибках.
lib/main.dart:
Содержит UI, модели (Movie) и State Management (ShortVideosNotifier).
Поток данных
Приложение стартует -> загружает .env.
ShortVideosNotifier запрашивает список видео через MuxApiService.
Для каждого видео запрашиваются детали (Playback ID, Metadata).
VideoCacheManager получает список и начинает предзагрузку видео (текущее + 1 вперед + 1 назад).
📡 Mux API (DOC-006)
Приложение использует следующие эндпоинты:
GET /video/v1/assets: Получение списка видео (пагинация поддерживается).
GET /video/v1/assets/{ASSET_ID}: Получение playback_id и метаданных.
Обработка ошибок включает логирование в консоль и отправку критических ошибок в Firebase Crashlytics.
code
Code
---

### 2. Файл `CHANGELOG.md` (Выполняет DOC-005)

Этот файл помогает отслеживать историю изменений. Создайте файл с именем `CHANGELOG.md` в корне.

```markdown
# Changelog

Все изменения в проекте Short Movie Player будут задокументированы в этом файле.



### Добавлено
- **Безопасность:** Интеграция `flutter_dotenv`. Секретные ключи (Mux Token/Secret) вынесены из кода в файл `.env`.
- **Логирование:** Внедрен пакет `logger`. Добавлены уровни логирования (Info, Debug, Error).
- **Архитектура:** Создана папка `utils` для вспомогательных классов.
- **Обработка ошибок:** Создан файл `error_messages.dart` для централизованного хранения текстов ошибок.

### Изменено
- **API Service:** Полный рефакторинг `MuxApiService`. Замена `print` на профессиональный логгер.
- **Cache Manager:** Оптимизация логирования в `VideoCacheManager`.
- **Конфигурация:** Обновлено имя приложения (Android/iOS) на "Short Movie Player".
- **Безопасность Android:** Удален `usesCleartextTraffic`, добавлен `network_security_config.xml` (только HTTPS).


- Исправлена уязвимость хранения API ключей в системе контроля версий.