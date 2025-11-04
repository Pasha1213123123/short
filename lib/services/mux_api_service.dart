import 'dart:convert';

import 'package:http/http.dart' as http;

import 'mux_config.dart';

class MuxApiService {
  Future<List<dynamic>> getVideos({int limit = 10, int page = 1}) async {
    final url =
        Uri.parse('${MuxConfig.videoApiUrl}/assets?limit=$limit&page=$page');

    try {
      final response = await http.get(url, headers: MuxConfig.headers);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final videos = data['data'] as List<dynamic>;

        if (videos.isNotEmpty) {
          print('--- Mux API Response Sample ---');
          print('Keys of the first video: ${(videos[0] as Map).keys.toList()}');
          print('Full first video object: ${videos[0]}');
          print('-----------------------------');
        }

        return videos;
      } else {
        throw Exception('Failed to load videos: ${response.body}');
      }
    } catch (e) {
      print('Error fetching videos from Mux: $e');
      throw Exception('Failed to load videos. Check your network connection.');
    }
  }
}
