import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../main.dart';

final videoCacheManagerProvider = Provider<VideoCacheManager>((ref) {
  final manager = VideoCacheManager();

  ref.onDispose(() => manager.dispose());
  return manager;
});

class _PreloadTask {
  final Movie movie;
  final int priority;
  _PreloadTask(this.movie, this.priority);
}

class VideoCacheManager {
  static const int _maxCacheSize = 5;
  static const int _maxConcurrentPreloads = 1;

  final Map<String, VideoPlayerController> _cache = {};
  final Map<String, DateTime> _accessTimes = {};

  final Map<String, Completer<VideoPlayerController>> _initializing = {};

  final Queue<_PreloadTask> _preloadQueue = Queue();
  final Set<String> _preloading = {};
  bool _isProcessingQueue = false;

  Future<VideoPlayerController> getOrCreateController(Movie movie) async {
    if (movie.playbackId == null) {
      throw Exception("Movie has no playbackId");
    }
    final playbackId = movie.playbackId!;

    if (_cache.containsKey(playbackId)) {
      _accessTimes[playbackId] = DateTime.now();
      return _cache[playbackId]!;
    }

    if (_initializing.containsKey(playbackId)) {
      return _initializing[playbackId]!.future;
    }

    final completer = Completer<VideoPlayerController>();
    _initializing[playbackId] = completer;

    try {
      if (_cache.length >= _maxCacheSize) {
        _cleanupLRU();
      }

      final controller = VideoPlayerController.networkUrl(movie.videoUrl);
      await controller.initialize();
      controller.setLooping(true);

      _cache[playbackId] = controller;
      _accessTimes[playbackId] = DateTime.now();

      completer.complete(controller);
      return controller;
    } catch (e) {
      completer.completeError(e);
      throw Exception("Failed to initialize video controller: $e");
    } finally {
      _initializing.remove(playbackId);
    }
  }

  void preload(int currentIndex, List<Movie> movies) {
    _addTaskToQueue(currentIndex + 1, movies, isHighPriority: true);

    _addTaskToQueue(currentIndex - 1, movies, isHighPriority: false);

    _processPreloadQueue();
  }

  void _addTaskToQueue(int index, List<Movie> movies,
      {required bool isHighPriority}) {
    if (index >= 0 && index < movies.length) {
      final movie = movies[index];

      if (movie.playbackId != null &&
          !_cache.containsKey(movie.playbackId!) &&
          !_initializing.containsKey(movie.playbackId!) &&
          !_preloading.contains(movie.playbackId!) &&
          !_preloadQueue
              .any((task) => task.movie.playbackId == movie.playbackId)) {
        final task = _PreloadTask(movie, isHighPriority ? 1 : 0);
        if (isHighPriority) {
          _preloadQueue.addFirst(task);
        } else {
          _preloadQueue.addLast(task);
        }
      }
    }
  }

  Future<void> _processPreloadQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    try {
      while (_preloadQueue.isNotEmpty &&
          _preloading.length < _maxConcurrentPreloads) {
        final task = _preloadQueue.removeFirst();
        final playbackId = task.movie.playbackId;

        if (playbackId == null ||
            _cache.containsKey(playbackId) ||
            _initializing.containsKey(playbackId)) {
          continue;
        }

        _preloading.add(playbackId);
        try {
          await getOrCreateController(task.movie);
        } catch (e) {
          print('Preload failed for ${playbackId}: $e');
        } finally {
          _preloading.remove(playbackId);
        }
      }
    } finally {
      _isProcessingQueue = false;

      if (_preloadQueue.isNotEmpty) {
        _processPreloadQueue();
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
    print("Cache cleanup: removed controller for ${oldestEntry.key}");
  }

  @override
  void dispose() {
    _preloadQueue.clear();
    _preloading.clear();

    for (final completer in _initializing.values) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('CacheManager was disposed'));
      }
    }
    _initializing.clear();

    for (final controller in _cache.values) {
      controller.dispose();
    }
    _cache.clear();
    _accessTimes.clear();
  }
}
