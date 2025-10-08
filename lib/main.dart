import 'dart:async' show Timer;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'firebase_options.dart';
import 'services/analytics_service.dart';

// Класс конфигурации приложения
class AppConfig {
  static const int maxCacheSize = 7;
  static const Duration cacheTimeout = Duration(minutes: 10);
  static const int videosBetweenAds = 3;
  static const double cacheCleanupThreshold = 0.9;
  static const int preloadRange = 2;
  static const Duration analyticsBatchInterval = Duration(seconds: 5);
  static const String testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';
  static const int memoryCleanupThresholdMB = 250;
}

// Класс для пакетной отправки событий аналитики
class AnalyticsBatcher {
  final List<Map<String, dynamic>> _events = [];
  Timer? _timer;

  AnalyticsBatcher() {
    _timer =
        Timer.periodic(AppConfig.analyticsBatchInterval, (_) => _flushEvents());
  }

  void logEvent(String name, Map<String, dynamic> parameters) {
    if (_timer == null) return;
    _events.add({'name': name, 'parameters': parameters});
  }

  void _flushEvents() {
    if (_events.isNotEmpty) {
      final eventsCopy = List<Map<String, dynamic>>.from(_events);
      _events.clear();
      AnalyticsService.logBatchEvents(eventsCopy);
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _flushEvents();
  }

  void logCacheHit(String videoId) =>
      logEvent('cache_hit', {'video_id': videoId});
  void logCacheMiss(String videoId) =>
      logEvent('cache_miss', {'video_id': videoId});
  void logCacheCleanup(String reason, Object info) =>
      logEvent('cache_cleanup', {'reason': reason, 'info': info.toString()});
  void logPreload(String videoId) => logEvent('preload', {'video_id': videoId});
}

// Расширение для безопасной работы с контроллером YouTube
extension YoutubePlayerControllerExtension on YoutubePlayerController {
  void safePause() {
    if (value.isPlaying) {
      pause();
    }
  }

  void safePlay() {
    if (!value.isPlaying) {
      play();
    }
  }
}

// Менеджер для отслеживания состояния рекламы
class VideoPlayerStateManager {
  bool _isAdShowing = false;
  final String _sessionId;

  VideoPlayerStateManager(this._sessionId);

  bool get isAdShowing => _isAdShowing;

  void pauseForAd(YoutubePlayerController? controller, int currentPage) {
    if (controller != null) {
      AnalyticsService.logVideoPausedForAd(currentPage, _sessionId);
      controller.safePause();
    }
    _isAdShowing = true;
  }

  void resetAdState() {
    _isAdShowing = false;
  }
}

class ShortModel {
  final String id;
  final String youtubeUrl;
  ShortModel({required this.id, required this.youtubeUrl});
}

// ----------------------------------------------------
// ПРОВАЙДЕРЫ RIVERPOD (Управление состоянием и зависимостями)
// ----------------------------------------------------

final shortsViewerCurrentPageProvider = StateProvider<int>((ref) => 0);
final shortsViewerCurrentControllerProvider =
    StateProvider<YoutubePlayerController?>((ref) => null);

// Состояние сессии и рекламы
class AdSessionState {
  final int videosWatched;
  final int adsShown;
  final bool isAdShowing;
  final String sessionId;
  final VideoPlayerStateManager playerStateManager;

  AdSessionState({
    required this.videosWatched,
    required this.adsShown,
    required this.isAdShowing,
    required this.sessionId,
    required this.playerStateManager,
  });

  AdSessionState copyWith({
    int? videosWatched,
    int? adsShown,
    bool? isAdShowing,
  }) {
    return AdSessionState(
      videosWatched: videosWatched ?? this.videosWatched,
      adsShown: adsShown ?? this.adsShown,
      isAdShowing: isAdShowing ?? this.isAdShowing,
      sessionId: sessionId,
      playerStateManager: playerStateManager,
    );
  }
}

// Notifier для управления сессией и рекламой
class AdSessionNotifier extends StateNotifier<AdSessionState> {
  final Ref _ref;
  InterstitialAd? _interstitialAd;
  late final DateTime _sessionStartTime;

  AdSessionNotifier(this._ref)
      : super(
          AdSessionState(
            videosWatched: 0,
            adsShown: 0,
            isAdShowing: false,
            sessionId: "session_${DateTime.now().millisecondsSinceEpoch}",
            playerStateManager: VideoPlayerStateManager(
                "session_${DateTime.now().millisecondsSinceEpoch}"),
          ),
        ) {
    _sessionStartTime = DateTime.now();

    Future.delayed(const Duration(milliseconds: 500), _loadInterstitialAd);

    AnalyticsService.logSessionStart(
        state.sessionId, "anonymous_user", "1.0.0", "Android");
  }

  void incrementVideoWatched() {
    state = state.copyWith(videosWatched: state.videosWatched + 1);
  }

  void pauseForAd(YoutubePlayerController? controller, int currentPage) {
    state.playerStateManager.pauseForAd(controller, currentPage);
    state = state.copyWith(isAdShowing: true);
  }

  void resetAdState() {
    state.playerStateManager.resetAdState();
    state = state.copyWith(isAdShowing: false);
  }

  void _loadInterstitialAd({int retryCount = 0}) async {
    if (retryCount >= 5) {
      if (kDebugMode)
        debugPrint("AdMob load failed 5 times. Stopping retries.");
      return;
    }
    final delay = Duration(
        milliseconds: (retryCount > 0 ? (1000 * (1 << (retryCount - 1))) : 0));
    await Future.delayed(delay);

    InterstitialAd.load(
      adUnitId: AppConfig.testInterstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (kDebugMode) debugPrint("AdMob LOADED successfully.");
          _interstitialAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              final currentPage = _ref.read(shortsViewerCurrentPageProvider);
              AnalyticsService.logAdShown(
                  "interstitial", ad.adUnitId, currentPage, state.sessionId, 0);
              state = state.copyWith(adsShown: state.adsShown + 1);
            },
            onAdDismissedFullScreenContent: (ad) {
              final controllerToPlay =
                  _ref.read(shortsViewerCurrentControllerProvider);
              final aggressivePlay =
                  _ref.read(shortsViewerAggressivePlayProvider);

              resetAdState();

              AnalyticsService.logAdDismissed(
                  "interstitial", ad.adUnitId, 0, "close_button");
              ad.dispose();

              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (controllerToPlay != null) {
                  aggressivePlay(controllerToPlay, shouldSeekToZero: false);
                }
              });

              state = state.copyWith(videosWatched: 0);
              if (kDebugMode)
                debugPrint("Video Watched Counter reset to 0 (Ad shown).");

              _loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              final controllerToPlay =
                  _ref.read(shortsViewerCurrentControllerProvider);
              final aggressivePlay =
                  _ref.read(shortsViewerAggressivePlayProvider);

              resetAdState();

              if (controllerToPlay != null) {
                aggressivePlay(controllerToPlay, shouldSeekToZero: false);
              }

              AnalyticsService.logAdLoadFailed("interstitial", ad.adUnitId,
                  error.code.toString(), error.message);
              ad.dispose();
              _loadInterstitialAd(retryCount: retryCount + 1);
            },
          );
        },
        onAdFailedToLoad: (error) {
          if (kDebugMode)
            debugPrint(
                "AdMob FAILED to load: ${error.code} / ${error.message}");
          _interstitialAd = null;
          AnalyticsService.logAdLoadFailed(
              "interstitial",
              AppConfig.testInterstitialAdUnitId,
              error.code.toString(),
              error.message);
          _loadInterstitialAd(retryCount: retryCount + 1);
        },
      ),
    );
  }

  void showInterstitialAd() {
    if (_interstitialAd == null) {
      if (kDebugMode) debugPrint("AdMob show SKIPPED: Ad is not ready.");
      return;
    }

    if (kDebugMode) debugPrint("AdMob SHOWING.");

    final currentController = _ref.read(shortsViewerCurrentControllerProvider);
    final currentPage = _ref.read(shortsViewerCurrentPageProvider);

    pauseForAd(currentController, currentPage);
    _interstitialAd?.show();
  }

  void sessionDispose() {
    _interstitialAd?.dispose();
    final duration = DateTime.now().difference(_sessionStartTime).inSeconds;
    AnalyticsService.logSessionEnd(
        state.sessionId, duration, state.videosWatched, state.adsShown);
  }
}

final adSessionNotifierProvider =
    StateNotifierProvider<AdSessionNotifier, AdSessionState>((ref) {
  final notifier = AdSessionNotifier(ref);
  ref.onDispose(() {
    notifier.sessionDispose();
  });
  return notifier;
});

final isAdShowingProvider =
    Provider<bool>((ref) => ref.watch(adSessionNotifierProvider).isAdShowing);
final adsShownProvider =
    Provider<int>((ref) => ref.watch(adSessionNotifierProvider).adsShown);
final videosWatchedProvider =
    Provider<int>((ref) => ref.watch(adSessionNotifierProvider).videosWatched);
final adSessionIdProvider =
    Provider<String>((ref) => ref.watch(adSessionNotifierProvider).sessionId);

final shortsViewerAggressivePlayProvider = Provider<
    Future<void> Function(YoutubePlayerController controller,
        {bool shouldSeekToZero})>((ref) {
  return (YoutubePlayerController controller,
          {bool shouldSeekToZero = false}) =>
      _playVideoWhenReady(ref, controller, shouldSeekToZero: shouldSeekToZero);
});

Future<void> _playVideoWhenReady(Ref ref, YoutubePlayerController controller,
    {bool shouldSeekToZero = false}) async {
  final currentPage = ref.read(shortsViewerCurrentPageProvider);
  final isAdShowing = ref.read(isAdShowingProvider);

  while (!controller.value.isReady) {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  if (isAdShowing) return;

  if (shouldSeekToZero) {
    controller.seekTo(Duration.zero);
  }

  controller.unMute();
  controller.play();

  int attempts = 0;
  Timer? retryTimer;

  retryTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
    final currentWidgetPage = ref.read(shortsViewerCurrentPageProvider);
    final currentAdState = ref.read(isAdShowingProvider);

    if (currentWidgetPage != currentPage || currentAdState) {
      timer.cancel();
      return;
    }

    if (controller.value.isPlaying && controller.value.volume > 0) {
      timer.cancel();
      return;
    }

    if (attempts < 3) {
      if (kDebugMode)
        debugPrint("Video Launch Retry (via Provider): $attempts");
      controller.unMute();
      controller.play();
      attempts++;
    } else {
      timer.cancel();
      if (kDebugMode)
        debugPrint("Video Launch Failed after 3 retries (via Provider).");
    }
  });
}

final analyticsBatcherProvider = Provider<AnalyticsBatcher>((ref) {
  final batcher = AnalyticsBatcher();
  ref.onDispose(() {
    batcher.dispose();
  });
  return batcher;
});

// ----------------------------------------------------
// Менеджер кэша
// ----------------------------------------------------
final videoCacheManagerProvider = Provider<VideoCacheManager>((ref) {
  final analyticsBatcher = ref.watch(analyticsBatcherProvider);
  final cacheManager = VideoCacheManager(analyticsBatcher);
  ref.onDispose(() {
    cacheManager.clearAll();
  });
  return cacheManager;
});

final shortsStateProvider = StateProvider<List<ShortModel>>((ref) => []);

final videoPreloaderProvider = Provider<VideoPreloader>((ref) {
  final cacheManager = ref.watch(videoCacheManagerProvider);
  final shorts = ref.watch(shortsStateProvider);
  return VideoPreloader(cacheManager, shorts);
});

const MethodChannel _memoryChannel = MethodChannel('com.example.app/memory');

final memoryMonitorProvider = Provider<MemoryMonitor>((ref) {
  final cacheManager = ref.watch(videoCacheManagerProvider);
  final monitor = MemoryMonitor(cacheManager);

  monitor.start(const Duration(seconds: 30));

  ref.onDispose(() {
    monitor.stop();
  });

  return monitor;
});

// ----------------------------------------------------
// Класс для мониторинга памяти (фоллбэк-логика)
// ----------------------------------------------------
class MemoryMonitor {
  final VideoCacheManager cacheManager;
  Timer? _timer;

  MemoryMonitor(this.cacheManager);

  void start(Duration checkInterval) {
    _timer ??= Timer.periodic(checkInterval, (_) => _check());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _check() async {
    final int currentSize = cacheManager.currentSize();
    final int maxSize = VideoCacheManager.maxCacheSize;

    final int cleanupThreshold =
        (maxSize * AppConfig.cacheCleanupThreshold).ceil();

    if (currentSize > cleanupThreshold) {
      cacheManager.cleanupLRU(targetSize: cleanupThreshold);
      AnalyticsService.logCacheCleanup(
          "cache_size_threshold_triggered_fallback",
          "current=$currentSize max=$maxSize target=$cleanupThreshold");
    }
  }
}

// ----------------------------------------------------
// Класс для кэшированного видео
// ----------------------------------------------------
class CachedVideo {
  final String videoId;
  final YoutubePlayerController controller;
  final DateTime createdAt;
  DateTime lastAccessed;
  int accessCount;

  CachedVideo({
    required this.videoId,
    required this.controller,
  })  : createdAt = DateTime.now(),
        lastAccessed = DateTime.now(),
        accessCount = 1;

  bool isExpired(Duration timeout) =>
      DateTime.now().difference(createdAt) > timeout;

  void touch() {
    lastAccessed = DateTime.now();
    accessCount++;
  }
}

// ----------------------------------------------------
// Менеджер кэша
// ----------------------------------------------------
class VideoCacheManager {
  static const int maxCacheSize = AppConfig.maxCacheSize;
  static const Duration cacheTimeout = AppConfig.cacheTimeout;
  final Map<String, CachedVideo> _cache = {};

  int _disposeCounter = 0;
  int get disposeCounter => _disposeCounter;

  final AnalyticsBatcher _analytics;

  VideoCacheManager(this._analytics);

  void _logCacheState(String operation) {
    if (kDebugMode) {
      debugPrint('''
[Cache Diagnostics] $operation
  Size: ${_cache.length}/$maxCacheSize
  Keys: ${_cache.keys.toList()}
''');
    }
  }

  YoutubePlayerController? getController(String videoId) {
    final cached = _cache[videoId];
    if (cached != null) {
      _logCacheState('GET($videoId): HIT');
      return cached.controller;
    }
    _logCacheState('GET($videoId): MISS');
    return null;
  }

  // Получение или создание контроллера с проверкой на "живой" статус
  YoutubePlayerController getOrCreate(
      String videoId, YoutubePlayerController Function() creator) {
    final cached = _cache[videoId];

    if (cached != null) {
      if (!cached.isExpired(cacheTimeout)) {
        if (cached.controller.hasListeners == false) {
          _disposeAndRemoveKey(videoId, reason: "controller_listeners_lost");
          _analytics.logCacheCleanup("controller_listeners_lost", videoId);
        } else {
          cached.touch();
          _analytics.logCacheHit(videoId);
          _logCacheState('GET_OR_CREATE($videoId): HIT/TOUCH');
          return cached.controller;
        }
      } else {
        _disposeAndRemoveKey(videoId, reason: "expired");
        _analytics.logCacheCleanup("expired", videoId);
      }
    }

    _analytics.logCacheMiss(videoId);
    _logCacheState('GET_OR_CREATE($videoId): MISS/RECREATE');
    if (_cache.length >= maxCacheSize) {
      cleanupLRU(targetSize: maxCacheSize - 1);
    }

    final controller = creator();
    _cache[videoId] = CachedVideo(
      videoId: videoId,
      controller: controller,
    );
    _logCacheState('GET_OR_CREATE($videoId): CREATED');
    return controller;
  }

  void cleanupLRU({int? targetSize}) {
    if (_cache.isEmpty) return;

    final target = targetSize ?? (maxCacheSize - 1);
    final toRemove = _cache.length - target;

    if (toRemove <= 0) return;

    final sorted = _cache.entries.toList()
      ..sort((a, b) => a.value.lastAccessed.compareTo(b.value.lastAccessed));

    for (int i = 0; i < toRemove && i < sorted.length; i++) {
      _disposeAndRemoveKey(sorted[i].key, reason: "LRU eviction");
      _analytics.logCacheCleanup("LRU eviction", sorted[i].key);
    }
    _logCacheState('CLEANUP_LRU: Removed $toRemove elements');
  }

  void clearAll() {
    for (var key in _cache.keys.toList()) {
      _disposeAndRemoveKey(key, reason: "clear_all");
    }
    _analytics.logCacheCleanup("clear_all", "manual");
  }

  void removeController(String videoId) {
    if (_cache.containsKey(videoId)) {
      _disposeAndRemoveKey(videoId, reason: "manual_remove_on_swipe");
      _analytics.logCacheCleanup("manual_remove_on_swipe", videoId);
    }
  }

  void _disposeAndRemoveKey(String key, {String reason = "manual"}) {
    try {
      _cache[key]?.controller.dispose();
    } catch (e, st) {
      AnalyticsService.logError(e, st, context: "_disposeAndRemoveKey");
    }
    _cache.remove(key);
    _disposeCounter++;
    _logCacheState('DISPOSE_AND_REMOVE($key) reason: $reason');
  }

  int currentSize() => _cache.length;
}

// ----------------------------------------------------
// Класс для предзагрузки видео
// ----------------------------------------------------
class VideoPreloader {
  final List<ShortModel> _shorts;
  final VideoCacheManager _cacheManager;

  VideoPreloader(this._cacheManager, this._shorts);

  YoutubePlayerController _createController(String videoId) {
    return YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: true,
        hideControls: true,
        controlsVisibleAtStart: false,
        hideThumbnail: true,
        loop: true,
        disableDragSeek: true,
        forceHD: true,
        enableCaption: false,
      ),
    );
  }

  void preloadAround(int currentIndex) {
    final int start = currentIndex - AppConfig.preloadRange;
    final int end = currentIndex + AppConfig.preloadRange;

    for (int i = start; i <= end; i++) {
      if (i >= 0 && i < _shorts.length) {
        final short = _shorts[i];
        final videoId = YoutubePlayer.convertUrlToId(short.youtubeUrl);
        if (videoId != null) {
          _cacheManager._analytics.logPreload(videoId);
          _cacheManager.getOrCreate(videoId, () => _createController(videoId));
        }
      }
    }
  }

  YoutubePlayerController getControllerForIndex(int index) {
    if (_shorts.isEmpty) {
      throw StateError('Список видео пуст. Невозможно получить контроллер.');
    }
    if (index < 0 || index >= _shorts.length) {
      throw RangeError(
          'Индекс $index вне диапазона [0, ${_shorts.length - 1}]');
    }
    final short = _shorts[index];
    if (short.youtubeUrl.isEmpty) {
      throw FormatException('URL видео в модели не может быть пустым.');
    }
    final videoId = YoutubePlayer.convertUrlToId(short.youtubeUrl);
    if (videoId == null) {
      throw FormatException('Некорректный YouTube URL: ${short.youtubeUrl}');
    }

    return _cacheManager.getOrCreate(videoId, () => _createController(videoId));
  }
}

// ----------------------------------------------------
// Репозиторий для получения данных (имитация API)
// ----------------------------------------------------
class VideoRepository {
  Future<List<ShortModel>> fetchVideos() async {
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      return _getDefaultVideos();
    } catch (e) {
      if (kDebugMode) {
        debugPrint("API fetch failed, falling back to local defaults: $e");
      }
      return _getDefaultVideos();
    }
  }

  List<ShortModel> _getDefaultVideos() {
    return [
      ShortModel(
          id: '1', youtubeUrl: 'https://www.youtube.com/shorts/M2ca8XUSy-E'),
      ShortModel(
          id: '2', youtubeUrl: 'https://www.youtube.com/shorts/052o6oWuHYQ'),
      ShortModel(
          id: '3', youtubeUrl: 'https://www.youtube.com/shorts/CotKFP4R_jY'),
      ShortModel(
          id: '4', youtubeUrl: 'https://www.youtube.com/shorts/euibKb3WUqo'),
      ShortModel(
          id: '5', youtubeUrl: 'https://www.youtube.com/shorts/P5dpiwGBo-s'),
      ShortModel(
          id: '6', youtubeUrl: 'https://www.youtube.com/shorts/bumNXv4pOro'),
    ];
  }
}

final videoRepositoryProvider = Provider((ref) => VideoRepository());

final shortsLoaderProvider = FutureProvider<void>((ref) async {
  final repo = ref.watch(videoRepositoryProvider);

  try {
    final loaded = await repo.fetchVideos();
    if (ref.read(shortsStateProvider).isEmpty) {
      ref.read(shortsStateProvider.notifier).state = loaded;
    }
  } catch (e) {
    throw Exception('Ошибка загрузки видео: $e');
  }
});

// ----------------------------------------------------
// Главная точка входа
// ----------------------------------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await AnalyticsService.initialize();
  final userId = "anonymous_${DateTime.now().millisecondsSinceEpoch}";
  await AnalyticsService.setUserId(userId);

  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  await MobileAds.instance.initialize();
  runApp(const ProviderScope(child: MyApp()));
}

// ----------------------------------------------------
// Основной виджет приложения
// ----------------------------------------------------
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Shorts Demo',
      theme: ThemeData.dark(),
      home: const ShortsViewer(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ----------------------------------------------------
// Основной контейнер-вьюер
// ----------------------------------------------------
class ShortsViewer extends ConsumerStatefulWidget {
  const ShortsViewer({super.key});
  @override
  ConsumerState<ShortsViewer> createState() => _ShortsViewerState();
}

class _ShortsViewerState extends ConsumerState<ShortsViewer>
    with WidgetsBindingObserver {
  final PageController _pageController = PageController();

  int _currentPage = 0;
  bool _initialVideoPlayed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.read(shortsLoaderProvider.future);

    ref.read(shortsViewerCurrentPageProvider.notifier).state = 0;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final controller = _currentController;
    if (controller == null) return;

    final isAdShowing = ref.read(isAdShowingProvider);
    final aggressivePlay = ref.read(shortsViewerAggressivePlayProvider);

    if (state == AppLifecycleState.paused) {
      if (controller.value.isPlaying) controller.pause();
    } else if (state == AppLifecycleState.resumed && !isAdShowing) {
      if (controller.value.position > Duration.zero) {
        aggressivePlay(controller, shouldSeekToZero: false);
      }
    }
  }

  YoutubePlayerController? get _currentController {
    return ref.read(shortsViewerCurrentControllerProvider);
  }

  // Логика смены страницы и счетчика видео
  void _onPageChanged(int page, List<ShortModel> shorts) {
    final isAdShowing = ref.read(isAdShowingProvider);
    if (isAdShowing) return;

    final prevPageIndex = _currentPage;
    final preloader = ref.read(videoPreloaderProvider);
    final adNotifier = ref.read(adSessionNotifierProvider.notifier);
    final aggressivePlay = ref.read(shortsViewerAggressivePlayProvider);

    // 1. Обновление состояния (СИНХРОННО)
    setState(() => _currentPage = page);
    ref.read(shortsViewerCurrentPageProvider.notifier).state = page;

    if (page != prevPageIndex) {
      adNotifier.incrementVideoWatched();
    }

    // 2. АСИНХРОННАЯ ОБРАБОТКА
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final videosWatched = ref.read(videosWatchedProvider);
      if (videosWatched > 0 &&
          videosWatched % AppConfig.videosBetweenAds == 0) {
        adNotifier.showInterstitialAd();
        return;
      }

      final currentController = preloader.getControllerForIndex(page);
      ref.read(shortsViewerCurrentControllerProvider.notifier).state =
          currentController;

      aggressivePlay(currentController, shouldSeekToZero: true);

      preloader.preloadAround(page);
    });
  }

  Widget _buildErrorWidget(dynamic error, int index) {
    return VideoErrorView(
      errorMessage: 'Не удалось загрузить видео №${index + 1}',
      details: error.toString().split(':')[0],
      onRetry: () {
        setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(memoryMonitorProvider);

    final shorts = ref.watch(shortsStateProvider);
    final loader = ref.watch(shortsLoaderProvider);

    final cacheManager = ref.read(videoCacheManagerProvider);
    final preloader = ref.read(videoPreloaderProvider);
    final isAdShowing = ref.watch(isAdShowingProvider);
    final aggressivePlay = ref.read(shortsViewerAggressivePlayProvider);

    final disposeKey = cacheManager.disposeCounter;

    return Scaffold(
      backgroundColor: Colors.black,
      body: loader.when(
        loading: () => _buildLoadingState(context),
        error: (err, _) => _buildLoadingErrorState(err),
        data: (_) {
          if (shorts.isEmpty) {
            return const Center(child: Text("Нет доступных видео."));
          }

          if (shorts.isNotEmpty && !_initialVideoPlayed) {
            _initialVideoPlayed = true;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                final adNotifier = ref.read(adSessionNotifierProvider.notifier);

                adNotifier.incrementVideoWatched();
                if (kDebugMode)
                  debugPrint("Video Watched Counter initialized to 1.");

                final initialController = preloader.getControllerForIndex(0);
                ref.read(shortsViewerCurrentControllerProvider.notifier).state =
                    initialController;

                aggressivePlay(initialController, shouldSeekToZero: true);
                preloader.preloadAround(0);
              }
            });
          }

          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            padEnds: false,
            physics: isAdShowing
                ? const NeverScrollableScrollPhysics()
                : const ClampingScrollPhysics(),
            itemCount: shorts.length,
            onPageChanged: (page) => _onPageChanged(page, shorts),
            itemBuilder: (context, index) {
              try {
                final controller = preloader.getControllerForIndex(index);

                return ShortsPlayerPage(
                  key: ValueKey(
                      'short_$index\_${controller.initialVideoId}\_$disposeKey'),
                  controller: controller,
                  isCurrentPage: index == _currentPage,
                  pageIndex: index,
                  totalShorts: shorts.length,
                  isAdShowing: isAdShowing,
                );
              } catch (e, st) {
                AnalyticsService.logError(e, st, context: "build_short_item");
                return _buildErrorWidget(e, index);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Загружаем видео...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingErrorState(Object error) {
    return Center(
      child: VideoErrorView(
        errorMessage: 'Ошибка загрузки данных',
        details:
            'Не удалось получить список видео. Детали: ${error.toString().split(':')[0]}',
        onRetry: () => ref.refresh(shortsLoaderProvider),
      ),
    );
  }
}

// ----------------------------------------------------
// Виджет для отображения ошибки
// ----------------------------------------------------
class VideoErrorView extends StatelessWidget {
  final String errorMessage;
  final String details;
  final VoidCallback onRetry;

  const VideoErrorView({
    super.key,
    required this.errorMessage,
    required this.details,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 64, color: Colors.redAccent),
              const SizedBox(height: 16),
              Text(
                errorMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Детали: $details',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить загрузку'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------
// Виджет проигрывателя
// ----------------------------------------------------
class ShortsPlayerPage extends StatefulWidget {
  final YoutubePlayerController controller;
  final int pageIndex;
  final int totalShorts;
  final bool isCurrentPage;
  final bool isAdShowing;

  const ShortsPlayerPage({
    super.key,
    required this.controller,
    required this.pageIndex,
    required this.totalShorts,
    required this.isCurrentPage,
    required this.isAdShowing,
  });

  @override
  State<ShortsPlayerPage> createState() => _ShortsPlayerPageState();
}

class _ShortsPlayerPageState extends State<ShortsPlayerPage>
    with AutomaticKeepAliveClientMixin {
  bool _isPlayerVisible = false;
  bool _showControls = false;
  Timer? _controlsTimer;

  @override
  bool get wantKeepAlive => false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_playerStateListener);
    _attemptAggressivePlay();
  }

  @override
  void didUpdateWidget(covariant ShortsPlayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller.removeListener(_playerStateListener);
      widget.controller.addListener(_playerStateListener);
      _isPlayerVisible = false;
    }

    if (widget.isCurrentPage &&
        (widget.controller != oldWidget.controller ||
            !oldWidget.isCurrentPage)) {
      _attemptAggressivePlay();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_playerStateListener);
    _controlsTimer?.cancel();
    super.dispose();
  }

  void _attemptAggressivePlay() {
    if (!widget.isCurrentPage || widget.isAdShowing || !mounted) return;

    int attempts = 0;
    Timer? retryTimer;
    final controller = widget.controller;

    retryTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted || !widget.isCurrentPage || widget.isAdShowing) {
        timer.cancel();
        return;
      }

      if (controller.value.isPlaying) {
        timer.cancel();
        return;
      }

      if (attempts < 3) {
        if (kDebugMode) debugPrint("Video Player Retry (Internal): $attempts");
        controller.unMute();
        controller.play();
        attempts++;
      } else {
        timer.cancel();
        if (kDebugMode)
          debugPrint("Video Player Launch Failed after 3 retries (Internal).");
      }
    });
  }

  void _playerStateListener() {
    if (mounted &&
        (widget.controller.value.playerState == PlayerState.playing ||
            widget.controller.value.playerState == PlayerState.paused)) {
      if (!_isPlayerVisible) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isPlayerVisible = true;
            });
          }
        });
      }
    }
  }

  void _togglePlaying() {
    final controller = widget.controller;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
      _attemptAggressivePlay();
    }
    setState(() {
      _showControls = true;
    });
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Container(
      color: Colors.black,
      child: YoutubePlayerBuilder(
        player: YoutubePlayer(
          controller: widget.controller,
          showVideoProgressIndicator: false,
          progressColors: const ProgressBarColors(
            playedColor: Colors.transparent,
            handleColor: Colors.transparent,
            bufferedColor: Colors.transparent,
            backgroundColor: Colors.transparent,
          ),
        ),
        builder: (context, player) {
          return GestureDetector(
            onTap: _togglePlaying,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: AspectRatio(
                    aspectRatio: 9 / 16,
                    child: player,
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 90,
                  child: Container(color: Colors.black),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 50,
                  child: Container(color: Colors.black),
                ),
                Positioned.fill(
                  child: Container(color: Colors.transparent),
                ),
                if (!_isPlayerVisible)
                  Positioned.fill(
                    child: Image.network(
                      YoutubePlayer.getThumbnail(
                        videoId: widget.controller.initialVideoId,
                        quality: ThumbnailQuality.high,
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                if (_showControls)
                  Center(
                    child: Icon(
                      widget.controller.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                      color: Colors.white.withOpacity(0.8),
                      size: 80.0,
                    ),
                  ),
                if (widget.isCurrentPage &&
                    widget.controller.value.playerState ==
                        PlayerState.buffering &&
                    !_isPlayerVisible)
                  const CircularProgressIndicator(color: Colors.white),
                if (widget.isCurrentPage && widget.isAdShowing)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: const Center(
                      child: Text('Реклама',
                          style: TextStyle(color: Colors.white, fontSize: 22)),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
