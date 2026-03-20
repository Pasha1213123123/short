// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Short Movie Player';

  @override
  String get uploadVideo => 'Upload Video';

  @override
  String get pickVideo => 'Tap to pick video';

  @override
  String get videoSelected => 'Video selected';

  @override
  String get titleLabel => 'Title';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get publishButton => 'PUBLISH';

  @override
  String get uploading => 'Uploading...';

  @override
  String get successMessage =>
      'Video uploaded! It will appear in the feed shortly.';

  @override
  String get errorAccessGallery => 'Error accessing gallery';

  @override
  String get errorEnterTitle => 'Please enter a title';

  @override
  String get statusPreparing => 'Preparing upload...';

  @override
  String get statusSending => 'Sending video to server...';

  @override
  String get statusProcessing => 'Upload complete! Processing...';

  @override
  String get like => 'Like';

  @override
  String get save => 'Save';

  @override
  String get share => 'Share';

  @override
  String get selectGenres => 'Select Genres';
}
