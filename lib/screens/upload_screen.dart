import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

// ИСПРАВЛЕННЫЕ ИМПОРТЫ
import '../l10n/app_localizations.dart';
import '../providers.dart'; // Теперь берем провайдеры отсюда
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.errorAccessGallery)),
      );
    }
  }

  Future<void> _uploadVideo() async {
    final loc = AppLocalizations.of(context)!;
    if (_selectedVideo == null) return;
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.errorEnterTitle)),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _statusMessage = loc.statusPreparing;
    });

    final apiService = ref.read(muxApiServiceProvider);

    try {
      // 1. Получаем ссылку
      final uploadUrl = await apiService.createDirectUploadUrl(
        title: _titleController.text,
        description: _descController.text,
      );

      if (uploadUrl != null) {
        // 2. Загружаем файл
        setState(() => _statusMessage = loc.statusSending);
        await apiService.uploadVideoFile(uploadUrl, _selectedVideo!);

        // 3. Успех
        setState(() => _statusMessage = loc.statusProcessing);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.successMessage),
              backgroundColor: Colors.green,
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

    return Scaffold(
      appBar: AppBar(title: Text(loc.uploadVideo)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Область выбора видео
            GestureDetector(
              onTap: _isUploading ? null : _pickVideo,
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[700]!),
                ),
                child: _selectedVideo == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.video_library,
                              size: 50, color: Colors.white),
                          const SizedBox(height: 10),
                          Text(loc.pickVideo,
                              style: const TextStyle(color: Colors.white)),
                        ],
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle,
                              size: 50, color: Colors.green),
                          const SizedBox(height: 10),
                          Text(
                            '${loc.videoSelected}\n${_selectedVideo!.path.split('/').last}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 20),

            // Поля ввода
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: loc.titleLabel,
                border: const OutlineInputBorder(),
                filled: true,
              ),
              enabled: !_isUploading,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              decoration: InputDecoration(
                labelText: loc.descriptionLabel,
                border: const OutlineInputBorder(),
                filled: true,
              ),
              maxLines: 3,
              enabled: !_isUploading,
            ),
            const SizedBox(height: 24),

            // Статус и Кнопка
            if (_statusMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  _statusMessage!,
                  style: TextStyle(
                    color: _statusMessage!.contains("Error") ||
                            _statusMessage!.contains("Ошибка")
                        ? Colors.red
                        : Colors.blue,
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
                  Text(loc.uploading),
                ],
              )
            else
              ElevatedButton(
                onPressed: _selectedVideo == null ? null : _uploadVideo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(loc.publishButton,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ),
          ],
        ),
      ),
    );
  }
}
