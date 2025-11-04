import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../main.dart';

final videoCacheManagerProvider = Provider<VideoCacheManager>((ref) {
  final manager = VideoCacheManager();

  ref.onDispose(() => manager.dispose());
  return manager;
});

class VideoCacheManager {
  static const int _maxCacheSize = 5;

  final Map<String, VideoPlayerController> _cache = {};

  final Map<String, DateTime> _accessTimes = {};

  Future<VideoPlayerController> getOrCreateController(Movie movie) async {
    if (movie.playbackId == null) {
      throw Exception("Movie has no playbackId");
    }

    if (_cache.containsKey(movie.playbackId!)) {
      _accessTimes[movie.playbackId!] = DateTime.now();
      return _cache[movie.playbackId!]!;
    }

    if (_cache.length >= _maxCacheSize) {
      _cleanupLRU();
    }

    final controller = VideoPlayerController.networkUrl(movie.videoUrl);

    try {
      await controller.initialize();
      controller.setLooping(true);

      _cache[movie.playbackId!] = controller;
      _accessTimes[movie.playbackId!] = DateTime.now();

      return controller;
    } catch (e) {
      controller.dispose();
      throw Exception("Failed to initialize video controller: $e");
    }
  }

  void preload(int currentIndex, List<Movie> movies) {
    if (currentIndex + 1 < movies.length) {
      final nextMovie = movies[currentIndex + 1];
      if (nextMovie.playbackId != null &&
          !_cache.containsKey(nextMovie.playbackId!)) {
        getOrCreateController(nextMovie);
      }
    }

    if (currentIndex - 1 >= 0) {
      final prevMovie = movies[currentIndex - 1];
      if (prevMovie.playbackId != null &&
          !_cache.containsKey(prevMovie.playbackId!)) {
        getOrCreateController(prevMovie);
      }
    }
  }

  void _cleanupLRU() {
    if (_accessTimes.isEmpty) return;

    final oldestEntry = _accessTimes.entries
        .reduce((curr, next) => curr.value.isBefore(next.value) ? curr : next);

    final controllerToDispose = _cache.remove(oldestEntry.key);
    controllerToDispose?.dispose();
    _accessTimes.remove(oldestEntry.key);
  }

  void dispose() {
    for (final controller in _cache.values) {
      controller.dispose();
    }
    _cache.clear();
    _accessTimes.clear();
  }
}
