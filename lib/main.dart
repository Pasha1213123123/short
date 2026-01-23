import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import 'firebase_options.dart';
import 'l10n/app_localizations.dart';
import 'providers.dart';
import 'screens/upload_screen.dart';
import 'services/video_cache_manager.dart';
import 'utils/logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FlutterError.onError = (errorDetails) {
    FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      theme: ThemeData.dark().copyWith(
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'Roboto'),
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ru'),
        Locale('uk'),
      ],
      home: const ShortsPageView(),
    );
  }
}

class ShortsPageView extends ConsumerStatefulWidget {
  const ShortsPageView({super.key});
  @override
  ConsumerState<ShortsPageView> createState() => _ShortsPageViewState();
}

class _ShortsPageViewState extends ConsumerState<ShortsPageView> {
  late PageController _pageController;
  int _currentIndex = 0;

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final Stopwatch _watchTimeStopwatch = Stopwatch();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    _watchTimeStopwatch.start();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final videos = ref.read(shortVideosProvider);
      if (videos.isNotEmpty) {
        _logVideoView(videos[0]);
        ref.read(videoCacheManagerProvider).preload(_currentIndex, videos);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _watchTimeStopwatch.stop();
    super.dispose();
  }

  void _logVideoView(Movie movie) {
    _analytics.logEvent(
      name: 'video_viewed',
      parameters: {
        'video_id': movie.playbackId ?? 'unknown',
        'title': movie.title,
      },
    );
  }

  void _onPageChanged(int newIndex) {
    final videos = ref.read(shortVideosProvider);
    if (videos.isEmpty) return;

    _watchTimeStopwatch.stop();
    if (_currentIndex < videos.length) {
      final prevVideo = videos[_currentIndex];
      _analytics.logEvent(
        name: 'video_watch_time',
        parameters: {
          'video_id': prevVideo.playbackId ?? 'unknown',
          'duration_seconds': _watchTimeStopwatch.elapsed.inSeconds,
        },
      );
    }

    _analytics.logEvent(
      name: 'video_swiped',
      parameters: {
        'direction': newIndex > _currentIndex ? 'next' : 'previous',
        'from_index': _currentIndex,
        'to_index': newIndex,
      },
    );

    _watchTimeStopwatch.reset();
    _watchTimeStopwatch.start();

    if (newIndex < videos.length) {
      _logVideoView(videos[newIndex]);
    }

    setState(() => _currentIndex = newIndex);
    ref.read(videoCacheManagerProvider).preload(newIndex, videos);

    if (newIndex == videos.length - 1) {
      ref.read(shortVideosProvider.notifier).loadMoreVideos();
    }
  }

  @override
  Widget build(BuildContext context) {
    final videos = ref.watch(shortVideosProvider);
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 60.0),
        child: FloatingActionButton(
          heroTag: 'upload_fab',
          tooltip: loc.uploadVideo,
          onPressed: () async {
            final currentController = ref.read(currentVideoControllerProvider);
            if (currentController != null &&
                currentController.value.isPlaying) {
              await currentController.pause();
            }
            if (!context.mounted) return;

            await Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const UploadScreen()),
            );

            await Future.delayed(const Duration(milliseconds: 100));
            final freshController = ref.read(currentVideoControllerProvider);
            if (freshController != null && !freshController.value.isPlaying) {
              await freshController.play();
            }
          },
          backgroundColor: Colors.white,
          child: const Icon(Icons.add, color: Colors.black, size: 30),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
      backgroundColor: Colors.black,
      body: videos.isEmpty
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : RefreshIndicator(
              onRefresh: () => ref.read(shortVideosProvider.notifier).refresh(),
              color: Colors.white,
              backgroundColor: Colors.red,
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: videos.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  return ShortPlayerScreen(
                    key: ValueKey(videos[index].playbackId),
                    movie: videos[index],
                    index: index,
                    isCurrent: index == _currentIndex,
                  );
                },
              ),
            ),
    );
  }
}

class ShortPlayerScreen extends ConsumerStatefulWidget {
  final Movie movie;
  final int index;
  final bool isCurrent;
  const ShortPlayerScreen(
      {super.key,
      required this.movie,
      required this.index,
      required this.isCurrent});
  @override
  ConsumerState<ShortPlayerScreen> createState() => _ShortPlayerScreenState();
}

class _ShortPlayerScreenState extends ConsumerState<ShortPlayerScreen> {
  VideoPlayerController? _videoController;
  String? _videoError;
  bool _areControlsVisible = true;
  bool _isCenterIconVisible = false;
  Timer? _controlsVisibilityTimer;
  Timer? _iconVisibilityTimer;
  bool _wasPlayingBeforeScrub = false;

  final List<String> _genres = [
    'All',
    'Action',
    'Adventure',
    'Comedy',
    'Drama',
    'Horror'
  ];
  String _selectedGenre = 'All';

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void dispose() {
    _controlsVisibilityTimer?.cancel();
    _iconVisibilityTimer?.cancel();
    if (widget.isCurrent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted)
          ref.read(currentVideoControllerProvider.notifier).state = null;
      });
    }
    super.dispose();
  }

  Future<void> _initializeController() async {
    try {
      final controller = await ref
          .read(videoCacheManagerProvider)
          .getOrCreateController(widget.movie);
      if (mounted) {
        setState(() => _videoController = controller);
        if (widget.isCurrent) {
          _startVideo();
          _showControlsAndStartTimer();
        }
      }
    } catch (e, stackTrace) {
      if (mounted)
        setState(() => _videoError = "Error loading video:\n${e.toString()}");
      logger.e('Failed to initialize video controller',
          error: e, stackTrace: stackTrace);
      FirebaseCrashlytics.instance
          .recordError(e, stackTrace, reason: 'Video Init Failed');
    }
  }

  void _startVideo() {
    if (_videoController == null) return;
    _videoController!.play();
    _startControlsTimeout();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted)
        ref.read(currentVideoControllerProvider.notifier).state =
            _videoController;
    });
  }

  void _playVideo() {
    _videoController?.play();
    _startControlsTimeout();
  }

  void _pauseVideo() {
    _videoController?.pause();
    _showControlsAndCancelTimer();
  }

  Future<void> _pauseAndResetVideo() async {
    if (_videoController == null) return;
    await _videoController!.pause();
    await _videoController!.seekTo(Duration.zero);
    _showControlsAndCancelTimer();
  }

  @override
  void didUpdateWidget(covariant ShortPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isCurrent != oldWidget.isCurrent) {
      widget.isCurrent ? _startVideo() : _pauseAndResetVideo();
    }
  }

  void _toggleCenterIconVisibility() {
    _iconVisibilityTimer?.cancel();
    if (mounted) {
      setState(() => _isCenterIconVisible = true);
      _iconVisibilityTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _isCenterIconVisible = false);
      });
    }
  }

  void _startControlsTimeout({Duration duration = const Duration(seconds: 3)}) {
    _controlsVisibilityTimer?.cancel();
    if (_videoController?.value.isPlaying ?? false) {
      _controlsVisibilityTimer = Timer(duration, () {
        if (mounted) setState(() => _areControlsVisible = false);
      });
    }
  }

  void _toggleControlsVisibility() {
    _controlsVisibilityTimer?.cancel();
    setState(() => _areControlsVisible = !_areControlsVisible);
    if (_areControlsVisible) _startControlsTimeout();
  }

  void _showControlsAndStartTimer() {
    if (mounted) {
      setState(() => _areControlsVisible = true);
      _startControlsTimeout();
    }
  }

  void _showControlsAndCancelTimer() {
    _controlsVisibilityTimer?.cancel();
    if (mounted && !_areControlsVisible)
      setState(() => _areControlsVisible = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackgroundVideoPlayer(),
          GestureDetector(
            onTap: () {
              if (_videoController == null ||
                  !_videoController!.value.isInitialized) return;
              _toggleCenterIconVisibility();
              if (_videoController!.value.isPlaying) {
                _pauseVideo();
              } else {
                if (mounted) setState(() => _areControlsVisible = true);
                _videoController!.play();
                _startControlsTimeout(duration: const Duration(seconds: 2));
              }
            },
            child: Container(color: Colors.transparent),
          ),
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _areControlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: Stack(
                children: [
                  _buildGradientOverlay(),
                  Positioned(
                    left: 16,
                    right: 90,
                    bottom: 60,
                    child: _buildBottomInfoPanel(),
                  ),
                ],
              ),
            ),
          ),
          _buildTopBar(),
          Positioned(right: 16, bottom: 60, child: _buildRightSideBar()),
          Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildInteractiveProgressBar()),
          _buildCenterControls(),
        ],
      ),
    );
  }

  Widget _buildCenterControls() {
    if (_videoController == null || _videoError != null)
      return const SizedBox.shrink();
    final IconData icon = _videoController!.value.isPlaying
        ? Icons.pause
        : Icons.play_arrow_rounded;
    return IgnorePointer(
      child: Center(
        child: AnimatedOpacity(
          opacity: _isCenterIconVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: Icon(icon, size: 80, color: Colors.white.withOpacity(0.85)),
        ),
      ),
    );
  }

  Widget _buildBackgroundVideoPlayer() {
    if (_videoError != null) {
      return Center(
        child: Container(
          color: Colors.red[900]!.withOpacity(0.8),
          padding: const EdgeInsets.all(32.0),
          child: Text(_videoError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      );
    }
    final bool isInitialized =
        _videoController != null && _videoController!.value.isInitialized;
    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: widget.movie.imageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(color: Colors.black),
          errorWidget: (context, url, error) => Container(color: Colors.black),
        ),
        if (isInitialized)
          Positioned.fill(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _videoController!.value.size.width,
                height: _videoController!.value.size.height,
                child: VideoPlayer(_videoController!),
              ),
            ),
          ),
        if (!isInitialized)
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(50)),
              child: const CircularProgressIndicator(color: Colors.white),
            ),
          ),
      ],
    );
  }

  Widget _buildInteractiveProgressBar() {
    if (_videoController == null || !_videoController!.value.isInitialized)
      return const SizedBox(height: 48);
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: _videoController!,
      builder: (context, value, child) {
        final double max = value.duration.inMilliseconds.toDouble();
        final double current = value.position.inMilliseconds.toDouble();
        if (max.isNaN || max.isInfinite || max <= 0)
          return const SizedBox(height: 48);
        return SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2.0,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
            activeTrackColor: Colors.red,
            inactiveTrackColor: Colors.white.withOpacity(0.3),
            thumbColor: Colors.red,
            overlayColor: Colors.red.withOpacity(0.2),
          ),
          child: Semantics(
            label: "Video progress",
            value: "${(current / max * 100).round()}%",
            child: Slider(
              value: current.clamp(0.0, max),
              min: 0.0,
              max: max,
              onChanged: (newValue) => _videoController!
                  .seekTo(Duration(milliseconds: newValue.round())),
              onChangeStart: (_) {
                _controlsVisibilityTimer?.cancel();
                _wasPlayingBeforeScrub = _videoController!.value.isPlaying;
                if (_wasPlayingBeforeScrub) _videoController!.pause();
              },
              onChangeEnd: (_) {
                if (_wasPlayingBeforeScrub) _videoController!.play();
                _startControlsTimeout();
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildGradientOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withOpacity(0.2),
              Colors.black.withOpacity(0.8)
            ],
            stops: const [0.5, 0.7, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final showFilters = ref.watch(filterVisibilityProvider);
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            children: [
              const SizedBox(width: 16),
              Container(
                decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8)),
                child: IconButton(
                    tooltip: "Filters",
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => ref
                        .read(filterVisibilityProvider.notifier)
                        .state = !showFilters),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: showFilters
                      ? SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                              children: _genres
                                  .map((g) => _buildFilterChip(g))
                                  .toList()))
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String genre) {
    final bool isSelected = _selectedGenre == genre;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Text(genre),
        selected: isSelected,
        onSelected: (selected) => setState(() => _selectedGenre = genre),
        backgroundColor: Colors.black.withOpacity(0.6),
        selectedColor: Colors.red,
        labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[300],
            fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
            side: BorderSide(
                color: isSelected ? Colors.red : Colors.transparent)),
      ),
    );
  }

  Widget _buildRightSideBar() {
    final loc = AppLocalizations.of(context)!;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildActionIcon(Icons.favorite_border, loc.like, 'video_liked'),
        const SizedBox(height: 20),
        _buildActionIcon(Icons.bookmark_border, loc.save, 'video_saved'),
        const SizedBox(height: 20),
        _buildActionIcon(Icons.share, loc.share, 'video_shared'),
      ],
    );
  }

  // Обновленный метод с трекингом
  Widget _buildActionIcon(IconData icon, String label, String analyticsEvent) {
    return InkWell(
      onTap: () {
        FirebaseAnalytics.instance.logEvent(
          name: analyticsEvent,
          parameters: {'video_id': widget.movie.playbackId ?? 'unknown'},
        );
        logger.i("Analytics Event: $analyticsEvent");

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('$label clicked!'),
              duration: const Duration(milliseconds: 500)),
        );
      },
      child: Semantics(
        button: true,
        label: label,
        child: Column(
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomInfoPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.movie.title,
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            maxLines: 3,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        Text(widget.movie.description,
            style:
                TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8)),
            maxLines: 3,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 20),
            const SizedBox(width: 4),
            Text(widget.movie.rating.toString(),
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(width: 16),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                    children: widget.movie.genres
                        .map((g) => _buildGenreTag(g))
                        .toList()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenreTag(String genre) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20)),
      child: Text(genre,
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
