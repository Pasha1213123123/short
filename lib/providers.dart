import 'dart:async';
import 'dart:convert';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import 'models/movie.dart';
import 'services/mux_api_service.dart';
import 'utils/logger.dart';

final muxApiServiceProvider = Provider<MuxApiService>((ref) {
  return MuxApiService();
});

// --- Провайдер Темы ---
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const String _themeKey = 'app_theme_mode';

  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? themeStr = prefs.getString(_themeKey);
      if (themeStr != null) {
        if (themeStr == 'light')
          state = ThemeMode.light;
        else if (themeStr == 'dark')
          state = ThemeMode.dark;
        else
          state = ThemeMode.system;
      }
    } catch (e) {
      logger.e('Error loading theme', error: e);
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      String val = 'system';
      if (mode == ThemeMode.light) val = 'light';
      if (mode == ThemeMode.dark) val = 'dark';
      await prefs.setString(_themeKey, val);
    } catch (e) {
      logger.e('Error saving theme', error: e);
    }
  }
}

// --- Провайдер Autoplay ---
final autoplayProvider = StateNotifierProvider<AutoplayNotifier, bool>((ref) {
  return AutoplayNotifier();
});

class AutoplayNotifier extends StateNotifier<bool> {
  static const String _autoplayKey = 'app_autoplay_enabled';

  AutoplayNotifier() : super(true) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = prefs.getBool(_autoplayKey) ?? true;
    } catch (e) {
      logger.e('Error loading autoplay setting', error: e);
    }
  }

  Future<void> setAutoplay(bool value) async {
    state = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoplayKey, value);
    } catch (e) {
      logger.e('Error saving autoplay setting', error: e);
    }
  }
}

final firebaseAnalyticsProvider = Provider<FirebaseAnalytics>((ref) {
  return FirebaseAnalytics.instance;
});

final firebaseCrashlyticsProvider = Provider<FirebaseCrashlytics>((ref) {
  return FirebaseCrashlytics.instance;
});

final firebasePerformanceProvider = Provider<FirebasePerformance>((ref) {
  return FirebasePerformance.instance;
});

final shortVideosProvider =
    StateNotifierProvider.autoDispose<ShortVideosNotifier, List<Movie>>((ref) {
  return ShortVideosNotifier(ref);
});

final currentVideoControllerProvider =
    StateProvider<VideoPlayerController?>((ref) => null);

final isAdShowingProvider = StateProvider<bool>((ref) => false);

final filterVisibilityProvider =
    StateProvider.autoDispose<bool>((ref) => false);

final likedVideosProvider =
    StateNotifierProvider<SetStringNotifier, Set<String>>((ref) {
  return SetStringNotifier('user_liked_videos');
});

final bookmarkedVideosProvider =
    StateNotifierProvider<SetStringNotifier, Set<String>>((ref) {
  return SetStringNotifier('user_bookmarked_videos');
});

class SetStringNotifier extends StateNotifier<Set<String>> {
  final String storageKey;

  SetStringNotifier(this.storageKey) : super({}) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? storedList = prefs.getStringList(storageKey);
      if (storedList != null) {
        state = storedList.toSet();
      }
    } catch (e) {
      logger.e('Ошибка загрузки $storageKey', error: e);
    }
  }

  Future<void> toggle(String id) async {
    if (state.contains(id)) {
      state = {...state}..remove(id);
    } else {
      state = {...state}..add(id);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(storageKey, state.toList());
    } catch (e) {
      logger.e('Ошибка сохранения $storageKey', error: e);
    }
  }

  bool contains(String id) => state.contains(id);
}

class ShortVideosNotifier extends StateNotifier<List<Movie>> {
  final Ref _ref;
  int _currentPage = 1;
  bool _isLoading = false;

  static const String _storageKey = 'cached_videos_feed';
  late final FirebaseAnalytics _analytics;

  ShortVideosNotifier(this._ref) : super([]) {
    _analytics = _ref.read(firebaseAnalyticsProvider);
    _init();
  }

  Future<void> _init() async {
    await _loadFromCache();
    await fetchInitialVideos();
  }

  Map<String, dynamic> _extractMetadata(Map<String, dynamic> assetDetails) {
    String title = '';
    String description = '';
    List<String> genres = [];
    final String assetId = assetDetails['id'] ?? 'unknown';

    final passthrough = assetDetails['passthrough'];
    if (passthrough is String && passthrough.isNotEmpty) {
      try {
        final decodedPassthrough =
            jsonDecode(passthrough) as Map<String, dynamic>;
        title = decodedPassthrough['title'] as String? ?? '';
        description = decodedPassthrough['description'] as String? ?? '';
        final rawGenres = decodedPassthrough['genres'];
        if (rawGenres is List) {
          genres = rawGenres.map((e) => e.toString()).toList();
        }
      } catch (e) {
        logger.w('Could not parse "passthrough" for asset $assetId', error: e);
      }
    }

    if (title.isEmpty) title = assetDetails['meta']?['title'] as String? ?? '';
    if (description.isEmpty)
      description = assetDetails['meta']?['description'] as String? ?? '';
    if (title.isEmpty) title = 'Untitled Video';
    if (description.isEmpty) description = 'Asset ID: $assetId';

    return {
      'title': title,
      'description': description,
      'genres': genres.isEmpty ? ['Mux', 'API'] : genres,
    };
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final List<dynamic> decoded = jsonDecode(jsonString);
        final cachedMovies = decoded.map((e) => Movie.fromMap(e)).toList();
        if (cachedMovies.isNotEmpty) {
          state = cachedMovies;
        }
      }
    } catch (e) {
      logger.e('Ошибка чтения кэша', error: e);
    }
  }

  Future<void> _saveToCache(List<Movie> movies) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final videosToCache = movies.take(20).map((e) => e.toMap()).toList();
      await prefs.setString(_storageKey, jsonEncode(videosToCache));
    } catch (e) {
      logger.e('Ошибка записи кэша', error: e);
    }
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
            genres: metadata['genres'] as List<String>,
            imageUrl:
                'https://image.mux.com/$playbackId/thumbnail.jpg?width=200',
          ));
        }
      }

      if (mounted) {
        state = movies.reversed.toList();
        _currentPage++;
        _saveToCache(state);

        trace.putAttribute('result', 'success');
        await trace.stop();

        _analytics.logEvent(
            name: 'feed_loaded', parameters: {'count': movies.length});
      }
    } catch (e, stackTrace) {
      trace.putAttribute('result', 'error');
      await trace.stop();
      logger.e('Failed to fetch initial videos',
          error: e, stackTrace: stackTrace);

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
    final Trace trace = FirebasePerformance.instance.newTrace('load_more_feed');
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
            genres: metadata['genres'] as List<String>? ?? [],
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
            name: 'load_more_success', parameters: {'count': newMovies.length});
      }
    } catch (e, stackTrace) {
      await trace.stop();
      logger.e('Failed to load more videos', error: e, stackTrace: stackTrace);
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

enum FeedStatus { initial, loading, success, error, empty }

final feedStatusProvider =
    StateProvider<FeedStatus>((ref) => FeedStatus.initial);

final selectedGenresProvider = StateProvider.autoDispose<Set<String>>((ref) => {});

final availableGenresProvider = Provider.autoDispose<List<String>>((ref) {
  final allVideos = ref.watch(shortVideosProvider);
  final Set<String> genres = {'All'};
  for (var video in allVideos) {
    genres.addAll(video.genres);
  }
  final list = genres.toList();
  // Сортировка: 'All' всегда первый, остальные по алфавиту
  final all = list.removeAt(list.indexOf('All'));
  list.sort();
  return [all, ...list];
});

final filteredVideosProvider = Provider.autoDispose<List<Movie>>((ref) {
  final allVideos = ref.watch(shortVideosProvider);
  final selectedGenres = ref.watch(selectedGenresProvider);

  if (selectedGenres.isEmpty) return allVideos;
  return allVideos
      .where((v) => v.genres.any((g) => selectedGenres.contains(g)))
      .toList();
});
