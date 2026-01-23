import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../utils/error_messages.dart';
import '../utils/logger.dart';
import 'mux_config.dart';

class MuxApiService {
  Future<List<dynamic>> getVideos({int limit = 10, int page = 1}) async {
    final url =
        Uri.parse('${MuxConfig.videoApiUrl}/assets?limit=$limit&page=$page');

    try {
      logger.i('Запрос видео от Mux: Страница $page, Лимит $limit');

      final response = await http.get(url, headers: MuxConfig.headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final videos = data['data'] as List<dynamic>;
        return videos;
      } else {
        logger.e(
            '${AppErrorMessages.muxFetchError} Status: ${response.statusCode}, Body: ${response.body}');
        throw Exception('${AppErrorMessages.muxFetchError}: ${response.body}');
      }
    } catch (e, stackTrace) {
      logger.e(AppErrorMessages.muxFetchError,
          error: e, stackTrace: stackTrace);
      throw Exception(AppErrorMessages.networkError);
    }
  }

  Future<Map<String, dynamic>?> getAssetDetails(String assetId) async {
    final url = Uri.parse('${MuxConfig.videoApiUrl}/assets/$assetId');

    try {
      final response = await http.get(url, headers: MuxConfig.headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] as Map<String, dynamic>;
      } else {
        logger.w(
            'Не удалось загрузить детали для asset $assetId. Status: ${response.statusCode}');
        return null;
      }
    } catch (e, stackTrace) {
      logger.e('Ошибка получения деталей для $assetId',
          error: e, stackTrace: stackTrace);
      return null;
    }
  }

  // --- ЗАГРУЗКА ВИДЕО  ---

  Future<String?> createDirectUploadUrl({
    required String title,
    required String description,
  }) async {
    final url = Uri.parse('${MuxConfig.videoApiUrl}/uploads');

    final passthroughData = jsonEncode({
      'title': title,
      'description': description,
    });

    final body = jsonEncode({
      "new_asset_settings": {
        "playback_policy": ["public"],
        "passthrough": passthroughData,
      },
      "cors_origin": "*",
    });

    try {
      logger.i('Создание URL для загрузки видео: $title');
      final response =
          await http.post(url, headers: MuxConfig.headers, body: body);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final uploadUrl = data['data']['url'] as String;
        final uploadId = data['data']['id'] as String;
        logger.d('Upload URL создан. ID: $uploadId');
        return uploadUrl;
      } else {
        logger.e('Ошибка создания Upload URL: ${response.body}');
        throw Exception('Не удалось начать загрузку.');
      }
    } catch (e, st) {
      logger.e('Ошибка API при создании загрузки', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// 2. Загружаем файл по полученному URL
  Future<void> uploadVideoFile(String uploadUrl, File videoFile) async {
    try {
      logger.i('Начало отправки файла в Mux...');

      final bytes = await videoFile.readAsBytes();

      final response = await http.put(
        Uri.parse(uploadUrl),
        body: bytes,
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        logger.i('Файл успешно отправлен в Mux!');
      } else {
        throw Exception(
            'Ошибка загрузки файла. Status: ${response.statusCode}');
      }
    } catch (e, st) {
      logger.e('Ошибка при отправке файла', error: e, stackTrace: st);
      rethrow;
    }
  }
}
