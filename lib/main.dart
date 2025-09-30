import 'dart:async' show Timer;
import 'dart:math' show Random;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'firebase_options.dart';
import 'services/analytics_service.dart';

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

class VideoPlayerStateManager {
  bool _isAdShowing = false;
  final String _sessionId;

  VideoPlayerStateManager(this._sessionId);

  bool get isAdShowing => _isAdShowing;

  void pauseForAd(YoutubePlayerController? controller, int currentPage) {
    if (controller != null) {
      controller.safePause();
      AnalyticsService.logVideoPausedForAd(currentPage, _sessionId);
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

class VideoCacheManager {
  static const int maxCacheSize = 5;
  static const Duration cacheTimeout = Duration(minutes: 10);
  final Map<String, CachedVideo> _cache = {};

  YoutubePlayerController? getController(String videoId) {
    final cached = _cache[videoId];
    if (cached != null) {
      cached.touch();
      return cached.controller;
    }
    return null;
  }

  YoutubePlayerController getOrCreate(
      String videoId, YoutubePlayerController Function() creator) {
    if (_cache.containsKey(videoId)) {
      final cached = _cache[videoId]!;
      cached.touch();
      AnalyticsService.logCacheHit(videoId);
      return cached.controller;
    }
    AnalyticsService.logCacheMiss(videoId);
    if (_cache.length >= maxCacheSize) {
      cleanupLRU();
    }
    final controller = creator();
    _cache[videoId] = CachedVideo(
      videoId: videoId,
      controller: controller,
    );
    return controller;
  }

  void cleanupLRU() {
    if (_cache.isEmpty) return;
    final sorted = _cache.entries.toList()
      ..sort((a, b) => a.value.lastAccessed.compareTo(b.value.lastAccessed));
    if (sorted.isNotEmpty) {
      final toRemoveKey = sorted.first.key;
      _disposeAndRemoveKey(toRemoveKey);
      AnalyticsService.logCacheCleanup("LRU eviction", toRemoveKey);
    }
  }

  void clearAll() {
    for (var key in _cache.keys.toList()) {
      _disposeAndRemoveKey(key);
    }
    AnalyticsService.logCacheCleanup("clear_all", "manual");
  }

  void _disposeAndRemoveKey(String key) {
    try {
      _cache[key]?.controller.dispose();
    } catch (e, st) {
      AnalyticsService.logError(e, st, context: "_disposeAndRemoveKey");
    }
    _cache.remove(key);
  }

  int currentSize() => _cache.length;
}

class MemoryMonitor {
  static const int memoryThresholdMB = 150;
  static const Duration checkInterval = Duration(seconds: 30);
  final VideoCacheManager cacheManager;
  Timer? _timer;

  MemoryMonitor(this.cacheManager);

  void start() {
    _timer ??= Timer.periodic(checkInterval, (_) => _check());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _check() {
    final used = Random().nextInt(250);
    AnalyticsService.logMemoryUsage(used);
    if (used > memoryThresholdMB) {
      cacheManager.cleanupLRU();
      AnalyticsService.logCacheCleanup(
          "memory_threshold_triggered", "used=$used MB");
    }
  }
}

final shortsStateProvider = StateProvider<List<ShortModel>>((ref) => []);

final shortsLoaderProvider = FutureProvider<void>((ref) async {
  await Future.delayed(const Duration(milliseconds: 500));
  final loaded = [
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
  if (ref.read(shortsStateProvider).isEmpty) {
    ref.read(shortsStateProvider.notifier).state = loaded;
  }
});

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

class ShortsViewer extends ConsumerStatefulWidget {
  const ShortsViewer({super.key});
  @override
  ConsumerState<ShortsViewer> createState() => _ShortsViewerState();
}

class _ShortsViewerState extends ConsumerState<ShortsViewer>
    with WidgetsBindingObserver {
  final PageController _pageController = PageController();
  final VideoCacheManager _cacheManager = VideoCacheManager();
  late final MemoryMonitor _memoryMonitor;
  late final VideoPlayerStateManager _playerStateManager;

  int _currentPage = 0;
  InterstitialAd? _interstitialAd;

  late final String _sessionId;
  int _videosWatched = 0;
  int _adsShown = 0;
  late final DateTime _sessionStartTime;

  @override
  void initState() {
    super.initState();
    _sessionId = "session_${DateTime.now().millisecondsSinceEpoch}";
    _sessionStartTime = DateTime.now();
    _memoryMonitor = MemoryMonitor(_cacheManager)..start();
    _playerStateManager = VideoPlayerStateManager(_sessionId);
    WidgetsBinding.instance.addObserver(this);
    _loadInterstitialAd();
    Future.microtask(() => ref.refresh(shortsLoaderProvider));
    AnalyticsService.logSessionStart(
        _sessionId, "anonymous_user", "1.0.0", "Android");
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _memoryMonitor.stop();
    _cacheManager.clearAll();
    _interstitialAd?.dispose();
    final duration = DateTime.now().difference(_sessionStartTime).inSeconds;
    AnalyticsService.logSessionEnd(
        _sessionId, duration, _videosWatched, _adsShown);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final controller = _currentController;
    if (controller == null) return;

    if (state == AppLifecycleState.paused) {
      if (controller.value.isPlaying) controller.pause();
    } else if (state == AppLifecycleState.resumed &&
        !_playerStateManager.isAdShowing) {
      if (controller.value.position > Duration.zero) {
        controller.play();
      }
    }
  }

  YoutubePlayerController? get _currentController {
    final shorts = ref.read(shortsStateProvider);
    if (shorts.isEmpty || _currentPage >= shorts.length) return null;
    final short = shorts[_currentPage % shorts.length];
    final videoId = YoutubePlayer.convertUrlToId(short.youtubeUrl);
    return videoId != null ? _cacheManager.getController(videoId) : null;
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              AnalyticsService.logAdShown(
                  "interstitial", ad.adUnitId, _currentPage, _sessionId, 0);
              _adsShown++;
            },
            onAdDismissedFullScreenContent: (ad) {
              final controllerToPlay = _currentController;
              if (controllerToPlay != null) {
                _playVideoWhenReady(_currentPage, controllerToPlay);
              }
              setState(() {
                _playerStateManager.resetAdState();
              });

              AnalyticsService.logAdDismissed(
                  "interstitial", ad.adUnitId, 0, "close_button");
              ad.dispose();
              _loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              final controllerToPlay = _currentController;
              if (controllerToPlay != null) {
                _playVideoWhenReady(_currentPage, controllerToPlay);
              }
              setState(() {
                _playerStateManager.resetAdState();
              });

              AnalyticsService.logAdLoadFailed("interstitial", ad.adUnitId,
                  error.code.toString(), error.message);
              ad.dispose();
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          AnalyticsService.logAdLoadFailed(
              "interstitial",
              'ca-app-pub-3940256099942544/1033173712',
              error.code.toString(),
              error.message);
        },
      ),
    );
  }

  void _showInterstitialAd() {
    if (_interstitialAd == null) {
      final controller =
          _getControllerForIndex(_currentPage, ref.read(shortsStateProvider));
      _playVideoWhenReady(_currentPage, controller);
      return;
    }
    setState(() {
      _playerStateManager.pauseForAd(_currentController, _currentPage);
    });
    _interstitialAd?.show();
  }

  YoutubePlayerController _getControllerForIndex(
      int index, List<ShortModel> shorts) {
    final short = shorts[index % shorts.length];
    final videoId = YoutubePlayer.convertUrlToId(short.youtubeUrl);
    if (videoId == null) {
      throw Exception('Неверный YouTube URL: ${short.youtubeUrl}');
    }

    return _cacheManager.getOrCreate(
      videoId,
      () => YoutubePlayerController(
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
        ),
      ),
    );
  }

  Future<void> _playVideoWhenReady(
      int page, YoutubePlayerController controller) async {
    while (!controller.value.isReady && mounted) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (_currentPage == page && !_playerStateManager.isAdShowing && mounted) {
      controller.seekTo(Duration.zero);
      await Future.delayed(const Duration(milliseconds: 50));
      controller.play();
      await Future.delayed(const Duration(milliseconds: 50));
      if (mounted) {
        controller.unMute();
      }
    }
  }

  void _onPageChanged(int page, List<ShortModel> shorts) {
    if (_playerStateManager.isAdShowing) return;

    final prevPageIndex = _currentPage;
    final prevShort = shorts[prevPageIndex % shorts.length];
    final prevVideoId = YoutubePlayer.convertUrlToId(prevShort.youtubeUrl);
    if (prevVideoId != null) {
      final prevController = _cacheManager.getController(prevVideoId);
      if (prevController != null && prevController.value.isPlaying) {
        prevController.pause();
      }
    }

    setState(() => _currentPage = page);
    _videosWatched++;

    if (_videosWatched > 0 && _videosWatched % 3 == 0) {
      _showInterstitialAd();
      return;
    }

    final currentController = _getControllerForIndex(page, shorts);
    _playVideoWhenReady(page, currentController);
  }

  @override
  Widget build(BuildContext context) {
    final shorts = ref.watch(shortsStateProvider);
    final loader = ref.watch(shortsLoaderProvider);

    const int totalCards = 30;
    return Scaffold(
      backgroundColor: Colors.black,
      body: loader.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Ошибка загрузки: $err')),
        data: (_) {
          if (shorts.isEmpty) {
            return const Center(child: Text("Нет доступных видео."));
          }

          if (_cacheManager.currentSize() == 0 && shorts.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                final controller = _getControllerForIndex(0, shorts);
                _playVideoWhenReady(0, controller);
              }
            });
          }

          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            padEnds: false,
            physics: _playerStateManager.isAdShowing
                ? const NeverScrollableScrollPhysics()
                : const ClampingScrollPhysics(),
            itemCount: totalCards,
            onPageChanged: (page) => _onPageChanged(page, shorts),
            itemBuilder: (context, index) {
              try {
                final controller = _getControllerForIndex(index, shorts);
                return ShortsPlayerPage(
                  key: ValueKey('short_$index\_${controller.initialVideoId}'),
                  controller: controller,
                  pageIndex: index,
                  totalShorts: shorts.length,
                  isCurrentPage: index == _currentPage,
                  isAdShowing: _playerStateManager.isAdShowing,
                );
              } catch (e, st) {
                AnalyticsService.logError(e, st, context: "build_short_item");
                return Center(child: Text('Ошибка загрузки видео: $e'));
              }
            },
          );
        },
      ),
    );
  }
}

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
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_playerStateListener);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_playerStateListener);
    _controlsTimer?.cancel();
    super.dispose();
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
                Positioned(
                  bottom: 50,
                  left: 20,
                  child: Text(
                    'Шортс ${widget.pageIndex % widget.totalShorts + 1}',
                    style: const TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                        shadows: [Shadow(blurRadius: 10)]),
                  ),
                ),
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
