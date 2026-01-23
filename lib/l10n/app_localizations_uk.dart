// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appTitle => 'Short Movie Player';

  @override
  String get uploadVideo => 'Завантажити відео';

  @override
  String get pickVideo => 'Натисніть, щоб вибрати відео';

  @override
  String get videoSelected => 'Відео вибрано';

  @override
  String get titleLabel => 'Назва';

  @override
  String get descriptionLabel => 'Опис';

  @override
  String get publishButton => 'ОПУБЛІКУВАТИ';

  @override
  String get uploading => 'Завантаження...';

  @override
  String get successMessage =>
      'Відео завантажено! Воно з\'явиться у стрічці за хвилину.';

  @override
  String get errorAccessGallery => 'Помилка доступу до галереї';

  @override
  String get errorEnterTitle => 'Будь ласка, введіть назву';

  @override
  String get statusPreparing => 'Підготовка до завантаження...';

  @override
  String get statusSending => 'Відправка відео на сервер...';

  @override
  String get statusProcessing => 'Завантаження завершено! Обробка...';

  @override
  String get like => 'Вподобати';

  @override
  String get save => 'Зберегти';

  @override
  String get share => 'Поділитися';
}
