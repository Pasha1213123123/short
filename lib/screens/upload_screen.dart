import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../providers.dart';
import '../theme/app_theme.dart';
import '../utils/logger.dart';

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedVideo;

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final List<String> _selectedGenres = [];

  bool _isUploading = false;
  String? _statusMessage;

  Future<void> _pickVideo() async {
    final loc = AppLocalizations.of(context)!;
    try {
      final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        setState(() {
          _selectedVideo = File(video.path);
          _statusMessage = null;
        });
        logger.i('Video selected: ${video.path}');
      }
    } catch (e) {
      logger.e('Error picking video', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(loc.errorAccessGallery),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _uploadVideo() async {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (_selectedVideo == null) return;
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.errorEnterTitle),
          backgroundColor: theme.colorScheme.error,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _statusMessage = loc.statusPreparing;
    });

    final apiService = ref.read(muxApiServiceProvider);

    try {
      final uploadUrl = await apiService.createDirectUploadUrl(
        title: _titleController.text,
        description: _descController.text,
        genres: _selectedGenres,
      );

      if (uploadUrl != null) {
        setState(() => _statusMessage = loc.statusSending);
        await apiService.uploadVideoFile(uploadUrl, _selectedVideo!);

        setState(() => _statusMessage = loc.statusProcessing);

        if (mounted) {
          final successColor =
              theme.extension<AppColorsExtension>()?.success ?? Colors.green;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.successMessage),
              backgroundColor: successColor,
            ),
          );
          Navigator.pop(context);
        }
      }
    } catch (e) {
      setState(() => _statusMessage = "Error: $e");
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(loc.uploadVideo)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: _isUploading ? null : _pickVideo,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.onSurface.withOpacity(0.2),
                  ),
                ),
                child: _selectedVideo == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.video_library,
                              size: 50, color: colorScheme.primary),
                          const SizedBox(height: 10),
                          Text(loc.pickVideo,
                              style: TextStyle(color: colorScheme.onSurface)),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle,
                              size: 50,
                              color: theme
                                      .extension<AppColorsExtension>()
                                      ?.success ??
                                  Colors.green),
                          const SizedBox(height: 10),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              '${loc.videoSelected}\n${_selectedVideo!.path.split('/').last}',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: colorScheme.onSurface),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: loc.titleLabel,
              ),
              enabled: !_isUploading,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              decoration: InputDecoration(
                labelText: loc.descriptionLabel,
              ),
              maxLines: 3,
              enabled: !_isUploading,
            ),
            const SizedBox(height: 16),
            const Text("Select Genres:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            _buildGenreSelection(),
            const SizedBox(height: 24),
            if (_statusMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  _statusMessage!,
                  style: TextStyle(
                    color: _statusMessage!.contains("Error") ||
                            _statusMessage!.contains("Ошибка")
                        ? colorScheme.error
                        : colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            if (_isUploading)
              Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 10),
                  Text(loc.uploading,
                      style: TextStyle(color: colorScheme.onSurface)),
                ],
              )
            else
              ElevatedButton(
                onPressed: _selectedVideo == null ? null : _uploadVideo,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(loc.publishButton,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreSelection() {
    final allGenres = ref.watch(availableGenresProvider);
    // Исключаем 'All' и дефолтные 'Mux', 'API', если они не нужны как выбор
    final genresToSelect = allGenres
        .where((g) => g != 'All' && g != 'Mux' && g != 'API')
        .toList();

    // Если список пуст (например, при первом запуске), добавим дефолтные для выбора
    if (genresToSelect.isEmpty) {
      genresToSelect.addAll(['Action', 'Comedy', 'Drama', 'Horror', 'Sci-Fi']);
    }

    return Wrap(
      spacing: 8.0,
      runSpacing: 4.0,
      children: genresToSelect.map((genre) {
        final isSelected = _selectedGenres.contains(genre);
        return FilterChip(
          label: Text(genre),
          selected: isSelected,
          onSelected: _isUploading
              ? null
              : (bool selected) {
                  setState(() {
                    if (selected) {
                      _selectedGenres.add(genre);
                    } else {
                      _selectedGenres.remove(genre);
                    }
                  });
                },
        );
      }).toList(),
    );
  }
}
