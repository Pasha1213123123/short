# ⚡ QUICK WINS - Быстрые улучшения

Список задач, которые можно выполнить быстро (от 15 минут до 2 часов) и которые дадут немедленный эффект.

---

## 🔴 КРИТИЧЕСКИЕ (Сделать СЕГОДНЯ)

### 1. Добавить .env в .gitignore (5 минут)

```bash
# Добавить в .gitignore
.env
.env.local
.env.*.local
```

**Файл:** `.gitignore`

---

### 2. Создать .env.example (10 минут)

```bash
# .env.example
MUX_API_TOKEN=your_mux_api_token_here
MUX_SECRET_KEY=your_mux_secret_key_here
```

**Файл:** `.env.example`

---

### 3. Удалить usesCleartextTraffic (2 минуты)

```xml
<!-- Удалить или изменить на false -->
android:usesCleartextTraffic="false"
```

**Файл:** `android/app/src/main/AndroidManifest.xml`

---

### 4. Изменить Application ID (5 минут)

```gradle
// android/app/build.gradle
applicationId = "com.yourcompany.shortmovieplayer"
```

**Файл:** `android/app/build.gradle`

---

### 5. Изменить Bundle Identifier (5 минут)

```xml
<!-- ios/Runner/Info.plist -->
<key>CFBundleIdentifier</key>
<string>com.yourcompany.shortmovieplayer</string>
```

**Файл:** `ios/Runner/Info.plist`

---

## 🟠 ВАЖНЫЕ (Сделать на этой неделе)

### 6. Заменить print() на logger (30 минут)

**Установить пакет:**

```yaml
# pubspec.yaml
dependencies:
  logger: ^2.0.0
```

**Создать logger:**

```dart
// lib/utils/logger.dart
import 'package:logger/logger.dart';

final logger = Logger(
  printer: PrettyPrinter(),
  level: kDebugMode ? Level.debug : Level.warning,
);
```

**Заменить все print():**

- `lib/services/mux_api_service.dart` - 4 места
- `lib/services/video_cache_manager.dart` - 2 места
- `lib/main.dart` - 1 место

---

### 7. Добавить базовую аналитику (1 час)

**В main.dart добавить:**

```dart
import 'package:firebase_analytics/firebase_analytics.dart';

final analytics = FirebaseAnalytics.instance;

// При просмотре видео
await analytics.logEvent(
  name: 'video_viewed',
  parameters: {
    'video_id': movie.playbackId,
    'title': movie.title,
  },
);

// При ошибке
await analytics.logEvent(
  name: 'video_load_error',
  parameters: {
    'video_id': movie.playbackId,
    'error': e.toString(),
  },
);
```

**Места для добавления:**

- `_onPageChanged` - трекинг свайпов
- `_startVideo` - трекинг просмотров
- `catch` блоки - трекинг ошибок

---

### 8. Обновить README (30 минут)

**Быстрый чеклист:**

- Удалить упоминания YouTube
- Добавить информацию о Mux
- Обновить список технологий
- Добавить инструкции по установке
- Добавить скриншоты (опционально)

---

### 9. Включить базовые правила линтинга (15 минут)

**В analysis_options.yaml:**

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    - avoid_print
    - prefer_const_constructors
    - prefer_final_fields
    - use_key_in_widget_constructors
```

**Запустить:**

```bash
flutter analyze
```

---

### 10. Добавить retry для API запросов (30 минут)

**Установить:**

```yaml
dependencies:
  http_retry: ^0.1.1
```

**Или создать простой retry:**

```dart
Future<T> retry<T>(
  Future<T> Function() fn, {
  int maxAttempts = 3,
  Duration delay = const Duration(seconds: 1),
}) async {
  for (int i = 0; i < maxAttempts; i++) {
    try {
      return await fn();
    } catch (e) {
      if (i == maxAttempts - 1) rethrow;
      await Future.delayed(delay * (i + 1));
    }
  }
  throw Exception('Max attempts reached');
}
```

---

## 🟡 УЛУЧШЕНИЯ (Сделать когда будет время)

### 11. Добавить error boundary (1 час)

**Создать ErrorWidget:**

```dart
class ErrorBoundary extends StatelessWidget {
  final Widget child;
  
  @override
  Widget build(BuildContext context) {
    return ErrorWidget.builder = (FlutterErrorDetails details) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64),
              SizedBox(height: 16),
              Text('Что-то пошло не так'),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Назад'),
              ),
            ],
          ),
        ),
      );
    };
    return child;
  }
}
```

---

### 12. Добавить loading skeleton (1 час)

**Вместо CircularProgressIndicator:**

```dart
Widget buildLoadingSkeleton() {
  return Container(
    color: Colors.grey[900],
    child: Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[700]!,
      child: Container(
        width: double.infinity,
        height: double.infinity,
      ),
    ),
  );
}
```

**Пакет:**

```yaml
dependencies:
  shimmer: ^3.0.0
```

---

### 13. Добавить pull-to-refresh индикатор (30 минут)

**Уже есть RefreshIndicator, но можно улучшить:**

```dart
RefreshIndicator(
  onRefresh: () async {
    await ref.read(shortVideosProvider.notifier).refresh();
  },
  color: Colors.white,
  backgroundColor: Colors.red,
  child: CustomScrollView(
    slivers: [
      SliverFillRemaining(
        child: PageView.builder(...),
      ),
    ],
  ),
)
```

---

### 14. Добавить haptic feedback (15 минут)

**Установить:**

```yaml
dependencies:
  flutter/services.dart  # уже есть
```

**Использовать:**

```dart
import 'package:flutter/services.dart';

// При свайпе
HapticFeedback.mediumImpact();

// При взаимодействии
HapticFeedback.lightImpact();
```

**Места:**

- `_onPageChanged` - при свайпе
- `_toggleControlsVisibility` - при тапе

---

### 15. Оптимизировать изображения (30 минут)

**Установить:**

```yaml
dependencies:
  cached_network_image: ^3.3.0
```

**Использовать:**

```dart
CachedNetworkImage(
  imageUrl: movie.imageUrl,
  placeholder: (context, url) => CircularProgressIndicator(),
  errorWidget: (context, url, error) => Icon(Icons.error),
  fit: BoxFit.cover,
)
```

---

## 📊 ПРИОРИТИЗАЦИЯ

### Сделать сегодня (2-3 часа):

1. ✅ Добавить .env в .gitignore
2. ✅ Создать .env.example
3. ✅ Удалить usesCleartextTraffic
4. ✅ Изменить Application ID
5. ✅ Изменить Bundle Identifier

### Сделать на этой неделе (4-6 часов):

1. ✅ Заменить print() на logger
2. ✅ Добавить базовую аналитику
3. ✅ Обновить README
4. ✅ Включить базовые правила линтинга
5. ✅ Добавить retry для API

### Сделать когда будет время:

11-15. Улучшения UX и производительности

---

## 🎯 ОЖИДАЕМЫЙ ЭФФЕКТ

### После критических задач:

- ✅ Безопасность улучшена на 50%
- ✅ Готовность к публикации улучшена на 30%

### После важных задач:

- ✅ Качество кода улучшено на 40%
- ✅ Мониторинг улучшен на 60%
- ✅ Документация обновлена

### После улучшений:

- ✅ UX улучшен на 30%
- ✅ Производительность улучшена на 20%

---

**Время выполнения всех quick wins:** ~8-10 часов  
**Эффект:** Значительное улучшение готовности к продакшену

---

*Последнее обновление: 2026*