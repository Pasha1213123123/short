import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

import '../utils/error_messages.dart';
import '../utils/logger.dart';
import 'mux_config.dart';

class MuxApiService {
  static const int _maxRetries = 3;

  Future<T> _executeWithRetry<T>(
      Future<T> Function() operation, String operationName) async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      logger.w('Попытка запроса без интернета: $operationName');
      throw const SocketException(AppErrorMessages.noInternet);
    }

    int attempt = 0;
    while (true) {
      try {
        attempt++;
        return await operation();
      } catch (e) {
        if (attempt > _maxRetries ||
            (e is http.ClientException == false &&
                e is SocketException == false)) {
          logger.e(
              'Окончательный сбой операции "$operationName" после $attempt попыток.',
              error: e);
          rethrow;
        }

        final delaySeconds = pow(2, attempt - 1).toInt();
        logger.w(
            'Ошибка в "$operationName". Попытка $attempt/$_maxRetries. Повтор через $delaySeconds сек...');

        await Future.delayed(Duration(seconds: delaySeconds));
      }
    }
  }

  Future<List<dynamic>> getVideos({int limit = 10, int page = 1}) async {
    return _executeWithRetry(() async {
      final url =
          Uri.parse('${MuxConfig.videoApiUrl}/assets?limit=$limit&page=$page');

      logger.i('Запрос видео (Page $page)...');
      final response = await http.get(url, headers: MuxConfig.headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] as List<dynamic>;
      } else {
        throw Exception(
            '${AppErrorMessages.muxFetchError}: ${response.statusCode}');
      }
    }, 'getVideos');
  }

  Future<Map<String, dynamic>?> getAssetDetails(String assetId) async {
    try {
      return await _executeWithRetry(() async {
        final url = Uri.parse('${MuxConfig.videoApiUrl}/assets/$assetId');
        final response = await http.get(url, headers: MuxConfig.headers);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['data'] as Map<String, dynamic>;
        } else {
          logger.w(
              'Детали видео не найдены ($assetId). Status: ${response.statusCode}');
          return null;
        }
      }, 'getAssetDetails');
    } catch (e) {
      return null;
    }
  }

  Future<String?> createDirectUploadUrl({
    required String title,
    required String description,
  }) async {
    return _executeWithRetry(() async {
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

      final response =
          await http.post(url, headers: MuxConfig.headers, body: body);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['data']['url'] as String;
      } else {
        throw Exception('Ошибка создания Upload URL: ${response.body}');
      }
    }, 'createDirectUploadUrl');
  }

  Future<void> uploadVideoFile(String uploadUrl, File videoFile) async {
    return _executeWithRetry(() async {
      logger.i('Отправка файла (${await videoFile.length()} байт)...');

      final response = await http.put(
        Uri.parse(uploadUrl),
        body: await videoFile.readAsBytes(),
      );

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception(
            'Ошибка загрузки файла. Status: ${response.statusCode}');
      }
    }, 'uploadVideoFile');
  }

  Future<bool> deleteAsset(String assetId) async {
    try {
      return await _executeWithRetry(() async {
        final url = Uri.parse('${MuxConfig.videoApiUrl}/assets/$assetId');
        final response = await http.delete(url, headers: MuxConfig.headers);

        if (response.statusCode == 204) {
          return true;
        } else {
          throw Exception('Ошибка удаления: ${response.statusCode}');
        }
      }, 'deleteAsset');
    } catch (e) {
      return false;
    }
  }
}
