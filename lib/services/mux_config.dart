import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';

class MuxConfig {
  static final String apiToken = dotenv.env['MUX_API_TOKEN'] ?? '';

  static final String secretKey = dotenv.env['MUX_SECRET_KEY'] ?? '';

  static const String videoApiUrl = 'https://api.mux.com/video/v1';

  static Map<String, String> get headers {
    if (apiToken.isEmpty || secretKey.isEmpty) {
      print('ОШИБКА: Ключи Mux API не найдены в .env файле!');
    }

    return {
      'Authorization':
          'Basic ${base64Encode(utf8.encode('$apiToken:$secretKey'))}',
      'Content-Type': 'application/json',
    };
  }
}
