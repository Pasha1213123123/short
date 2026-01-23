import 'dart:async';
import 'dart:convert';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:video_player/video_player.dart';

import 'services/mux_api_service.dart';
import 'utils/logger.dart';

// --- МОДЕЛЬ MOVIE ---
class Movie {
  final String title;
  final double rating;
  final String description;
  final List<String> genres;
  final String imageUrl;
  final String? playbackId;

  Movie({
    required this.title,
    required this.rating,
    required this.description,
    required this.genres,
    required this.imageUrl,
    this.playbackId,
  });

  Uri get videoUrl {
    if (playbackId != null) {
      return Uri.parse('https://stream.mux.com/$playbackId.m3u8');
    }
    return Uri.parse('assets/sample_video.mp4');
  }
}

// --- ПРОВАЙДЕРЫ ---

final muxApiServiceProvider = Provider<MuxApiService>((ref) {
  return MuxApiService();
});

final shortVideosProvider =
    StateNotifierProvider.autoDispose<ShortVideosNotifier, List<Movie>>((ref) {
  return ShortVideosNotifier(ref);
});

final currentVideoControllerProvider =
    StateProvider<VideoPlayerController?>((ref) => null);

final filterVisibilityProvider =
    StateProvider.autoDispose<bool>((ref) => false);

// --- ЛОГИКА ЗАГРУЗКИ ВИДЕО ---
class ShortVideosNotifier extends StateNotifier<List<Movie>> {
  final Ref _ref;
  int _currentPage = 1;
  bool _isLoading = false;

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  ShortVideosNotifier(this._ref) : super([]) {
    fetchInitialVideos();
  }

  Map<String, String> _extractMetadata(Map<String, dynamic> assetDetails) {
    String title = '';
    String description = '';
    final String assetId = assetDetails['id'] ?? 'unknown';

    final passthrough = assetDetails['passthrough'];
    if (passthrough is String && passthrough.isNotEmpty) {
      try {
        final decodedPassthrough =
            jsonDecode(passthrough) as Map<String, dynamic>;
        title = decodedPassthrough['title'] as String? ?? '';
        description = decodedPassthrough['description'] as String? ?? '';
      } catch (e) {
        logger.w('Could not parse "passthrough" for asset $assetId', error: e);
      }
    }

    if (title.isEmpty) {
      title = assetDetails['meta']?['title'] as String? ?? '';
    }
    if (description.isEmpty) {
      description = assetDetails['meta']?['description'] as String? ?? '';
    }

    if (title.isEmpty) {
      title = 'Untitled Video';
    }
    if (description.isEmpty) {
      description = 'Asset ID: $assetId';
    }

    return {'title': title, 'description': description};
  }

  Future<void> fetchInitialVideos() async {
    if (_isLoading) return;
    _isLoading = true;
    final apiService = _ref.read(muxApiServiceProvider);

    final Trace trace =
        FirebasePerformance.instance.newTrace('fetch_initial_feed');
    await trace.start();

    _currentPage = 1;

    try {
      final videoListJson = await apiService.getVideos(page: _currentPage);

      final List<Future<Map<String, dynamic>?>> detailFutures = [];
      for (var videoData in videoListJson) {
        final assetId = videoData['id'] as String?;
        final status = videoData['status'] as String?;

        if (assetId != null && status == 'ready') {
          detailFutures.add(apiService.getAssetDetails(assetId));
        }
      }

      final detailedAssets = await Future.wait(detailFutures);

      final List<Movie> movies = [];
      for (var assetDetails in detailedAssets) {
        if (assetDetails == null) continue;
        if (assetDetails['status'] != 'ready') continue;

        final playbackIds = assetDetails['playback_ids'] as List?;
        if (playbackIds != null && playbackIds.isNotEmpty) {
          final playbackId = playbackIds[0]['id'];
          final metadata = _extractMetadata(assetDetails);

          movies.add(Movie(
            title: metadata['title']!,
            description: metadata['description']!,
            playbackId: playbackId,
            rating: 4.5,
            genres: ['Mux', 'API'],
            imageUrl:
                'https://image.mux.com/$playbackId/thumbnail.jpg?width=200',
          ));
        }
      }

      if (mounted) {
        state = movies.reversed.toList();
        _currentPage++;

        await trace.stop();

        _analytics.logEvent(
          name: 'feed_loaded',
          parameters: {
            'count': movies.length,
            'page': 1,
          },
        );
      }
    } catch (e, stackTrace) {
      await trace.stop();

      logger.e('Failed to fetch initial videos',
          error: e, stackTrace: stackTrace);

      FirebaseCrashlytics.instance.recordError(e, stackTrace,
          reason: 'Failed to fetch initial videos with details');

      _analytics.logEvent(
          name: 'video_load_error', parameters: {'error': e.toString()});
    } finally {
      _isLoading = false;
    }
  }

  Future<void> loadMoreVideos() async {
    if (_isLoading) return;
    _isLoading = true;
    final apiService = _ref.read(muxApiServiceProvider);

    final Trace trace =
        FirebasePerformance.instance.newTrace('load_more_videos');
    await trace.start();

    try {
      final videoListJson = await apiService.getVideos(page: _currentPage);

      if (videoListJson.isEmpty) {
        _isLoading = false;
        await trace.stop();
        return;
      }

      final List<Future<Map<String, dynamic>?>> detailFutures = [];
      for (var videoData in videoListJson) {
        final assetId = videoData['id'] as String?;
        final status = videoData['status'] as String?;
        if (assetId != null && status == 'ready') {
          detailFutures.add(apiService.getAssetDetails(assetId));
        }
      }

      final detailedAssets = await Future.wait(detailFutures);
      final List<Movie> newMovies = [];

      for (var assetDetails in detailedAssets) {
        if (assetDetails == null) continue;
        if (assetDetails['status'] != 'ready') continue;

        final playbackIds = assetDetails['playback_ids'] as List?;
        if (playbackIds != null && playbackIds.isNotEmpty) {
          final playbackId = playbackIds[0]['id'];
          final metadata = _extractMetadata(assetDetails);

          newMovies.add(Movie(
            title: metadata['title']!,
            description: metadata['description']!,
            playbackId: playbackId,
            rating: 4.5,
            genres: ['Mux', 'API'],
            imageUrl:
                'https://image.mux.com/$playbackId/thumbnail.jpg?width=200',
          ));
        }
      }

      if (mounted) {
        state = [...state, ...newMovies.reversed];
        _currentPage++;

        await trace.stop();

        _analytics.logEvent(
          name: 'load_more_success',
          parameters: {
            'count': newMovies.length,
            'page': _currentPage,
          },
        );
      }
    } catch (e, stackTrace) {
      await trace.stop();
      logger.e('Failed to load more videos', error: e, stackTrace: stackTrace);
      FirebaseCrashlytics.instance
          .recordError(e, stackTrace, reason: 'Failed to load more videos');
    } finally {
      _isLoading = false;
    }
  }

  Future<bool> refresh() async {
    if (_isLoading) return false;
    await fetchInitialVideos();
    return true;
  }
}
