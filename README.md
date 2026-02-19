1. Центральная конфигурация темы (lib/theme/app_theme.dart)
Требование	Статус	Комментарий
Создать модуль конфигурации	✅	Файл создан.
Определить палитру (фон, поверхность, акцент, текст)	✅	Определены _primaryColor, _darkBackground и т.д.
Определить цвета состояний (успех, ошибка, предупреждение)	✅	Исправлено. Используется AppColorsExtension с полями success и warning. Error есть в ColorScheme.
Собрать ThemeData для Light/Dark	✅	Сконфигурированы обе темы.
Настроить ThemeData компоненты (sliderTheme, chipTheme и др.)	✅	Все компоненты настроены внутри app_theme.dart.
2. Подключение темы (lib/main.dart)
Требование	Статус	Комментарий
Использовать тему в main.dart	✅	Подключены theme, darkTheme и themeMode из провайдера.
Шрифт Roboto через конфигурацию	✅	Используется textTheme.apply(fontFamily: 'Roboto') внутри темы.
3. Замена «жёстких» цветов (upload_screen.dart, main.dart)
Требование	Статус	Комментарий
Scaffold.backgroundColor из темы	✅	Берется автоматически из ThemeData.
Фоны оверлеев, чипов, кнопок	✅	Используются colorScheme.surface, primary и т.д.
SliderTheme из темы	✅	Виджеты Slider в коде очищены от стилей, берут стиль из AppTheme.
SnackBar (успех/ошибка)	✅	Исправлено. Вместо Colors.green используется extension<AppColorsExtension>()!.success.
Поля ввода (InputDecoration)	✅	Стиль вынесен в inputDecorationTheme.
4. Фоны экранов и виджетов (short_player_screen.dart, shorts_page_view.dart)
Требование	Статус	Комментарий
Фон основного экрана и загрузки	✅	Используются цвета темы.
Градиенты как именованные объекты	✅	Исправлено. Градиент вынесен в AppTheme.videoOverlayGradient.
Убрать хардкод цветов (Colors.amber и т.д.)	✅	Исправлено. Для звезд рейтинга и закладок используется extension<AppColorsExtension>()!.warning.
Исключение: Оставить Colors.* где осознанно	✅	Оставлен Colors.black для фона видео и Colors.white для текста поверх видео (так как видео всегда темное, текст должен быть белым в любой теме). Это соответствует требованию "осознанности".
5. Переключение темы (settings_screen.dart, providers.dart)
Требование	Статус	Комментарий
Хранить выбор пользователя	✅	Реализовано в ThemeModeNotifier (SharedPrefs).
Переключать тему в UI	✅	Реализовано в SettingsScreen.