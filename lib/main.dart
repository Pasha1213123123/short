import 'dart:async';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'firebase_options.dart';
import 'services/analytics_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final startTime = DateTime.now();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await AnalyticsService.initialize();

  final userId = "anonymous_${DateTime.now().millisecondsSinceEpoch}";
  await AnalyticsService.setUserId(userId);

  final startupTime = DateTime.now().difference(startTime).inMilliseconds;
  await AnalyticsService.logAppStartup(
    startupTime,
    "Android 11, RMX2063",
    "1.0.0",
  );

  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  final adsStart = DateTime.now();
  await MobileAds.instance.initialize();
  final adsInitTime = DateTime.now().difference(adsStart).inMilliseconds;
  await AnalyticsService.logAdsInitialization(adsInitTime, true);

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

class ShortModel {
  final String id;
  final String youtubeUrl;

  ShortModel({
    required this.id,
    required this.youtubeUrl,
  });
}

final shortsStateProvider = StateProvider<List<ShortModel>>((ref) => []);

final shortsLoaderProvider = FutureProvider<void>((ref) async {
  await Future.delayed(const Duration(seconds: 1));

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

class ShortsViewer extends ConsumerStatefulWidget {
  const ShortsViewer({super.key});

  @override
  ConsumerState<ShortsViewer> createState() => _ShortsViewerState();
}

class _ShortsViewerState extends ConsumerState<ShortsViewer> {
  final PageController _pageController = PageController();
  final Map<int, YoutubePlayerController> _controllers = {};
  int _currentPage = 0;
  InterstitialAd? _interstitialAd;

  late final String _sessionId;
  int _videosWatched = 0;
  int _adsShown = 0;
  late final DateTime _sessionStartTime;

  @override
  void initState() {
    super.initState();
    _loadInterstitialAd();

    _sessionId = "session_${DateTime.now().millisecondsSinceEpoch}";
    _sessionStartTime = DateTime.now();

    Future.microtask(() => ref.read(shortsLoaderProvider));

    AnalyticsService.logSessionStart(
      _sessionId,
      "anonymous_user",
      "1.0.0",
      "Android 11, RMX2063",
    );
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              AnalyticsService.logAdDismissed(
                  "interstitial", ad.adUnitId, 0, "close_button");
              ad.dispose();
              _loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
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
    final startTime = DateTime.now();
    _interstitialAd?.show();
    final loadTime =
        DateTime.now().difference(startTime).inMilliseconds / 1000.0;

    AnalyticsService.logAdShown(
      "interstitial",
      'ca-app-pub-3940256099942544/1033173712',
      _currentPage,
      _sessionId,
      loadTime,
    );
    _adsShown++;
  }

  void _onPageChanged(int page, List<ShortModel> shorts) {
    _controllers[_currentPage % shorts.length]?.pause();

    final prevPage = _currentPage;
    setState(() {
      _currentPage = page;
    });

    _controllers[page % shorts.length]?.play();

    if (page > prevPage) {
      AnalyticsService.logVideoSwipe(prevPage, page, "up", "normal");
    } else {
      AnalyticsService.logVideoSwipe(prevPage, page, "down", "normal");
    }

    final short = shorts[page % shorts.length];
    final videoId = YoutubePlayer.convertUrlToId(short.youtubeUrl);
    if (videoId != null) {
      AnalyticsService.logVideoStart(videoId, page, 30, _sessionId);
      _videosWatched++;
    }

    if (page % 3 == 0 && page != 0) {
      _showInterstitialAd();
    }
  }

  YoutubePlayerController _getControllerForIndex(
      int index, List<ShortModel> shorts) {
    final short = shorts[index % shorts.length];
    final videoId = YoutubePlayer.convertUrlToId(short.youtubeUrl);

    if (videoId == null) {
      throw Exception('Неверный YouTube URL: ${short.youtubeUrl}');
    }

    if (_controllers.containsKey(index % shorts.length)) {
      return _controllers[index % shorts.length]!;
    }

    final controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        loop: true,
      ),
    );

    _controllers[index % shorts.length] = controller;
    return controller;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _controllers.forEach((_, controller) => controller.dispose());
    _interstitialAd?.dispose();

    final duration = DateTime.now().difference(_sessionStartTime).inSeconds;
    AnalyticsService.logSessionEnd(
        _sessionId, duration, _videosWatched, _adsShown);

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shorts = ref.watch(shortsStateProvider);
    final loader = ref.watch(shortsLoaderProvider);

    const int totalCards = 30;

    return Scaffold(
      body: loader.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Ошибка загрузки: $err')),
        data: (_) {
          if (shorts.isEmpty) {
            return const Center(child: Text("Нет доступных видео."));
          }
          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: totalCards,
            onPageChanged: (page) => _onPageChanged(page, shorts),
            itemBuilder: (context, index) {
              try {
                final controller = _getControllerForIndex(index, shorts);
                return YoutubePlayerBuilder(
                  player: YoutubePlayer(controller: controller),
                  builder: (context, player) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        player,
                        Positioned(
                          bottom: 50,
                          left: 20,
                          child: Text(
                            'Шортс ${index + 1}',
                            style: const TextStyle(
                              fontSize: 24,
                              color: Colors.white,
                              shadows: [Shadow(blurRadius: 10)],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
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
