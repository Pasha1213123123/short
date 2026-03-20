// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Short Movie Player';

  @override
  String get uploadVideo => 'Загрузить видео';

  @override
  String get pickVideo => 'Нажмите, чтобы выбрать видео';

  @override
  String get videoSelected => 'Видео выбрано';

  @override
  String get titleLabel => 'Название';

  @override
  String get descriptionLabel => 'Описание';

  @override
  String get publishButton => 'ОПУБЛИКОВАТЬ';

  @override
  String get uploading => 'Загрузка...';

  @override
  String get successMessage =>
      'Видео загружено! Оно появится в ленте через минуту.';

  @override
  String get errorAccessGallery => 'Ошибка доступа к галерее';

  @override
  String get errorEnterTitle => 'Пожалуйста, введите название';

  @override
  String get statusPreparing => 'Подготовка к загрузке...';

  @override
  String get statusSending => 'Отправка видео на сервер...';

  @override
  String get statusProcessing => 'Загрузка завершена! Обработка...';

  @override
  String get like => 'Нравится';

  @override
  String get save => 'Сохр.';

  @override
  String get share => 'Поделиться';

  @override
  String get selectGenres => 'Выберите жанры';
}
