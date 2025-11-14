import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:video_player/video_player.dart';

import 'firebase_options.dart';
import 'services/mux_api_service.dart';
import 'services/video_cache_manager.dart';

// --- МОДЕЛИ ---
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

// --- ПРОВАЙДЕРЫ RIVERPOD ---
final muxApiServiceProvider = Provider<MuxApiService>((ref) {
  return MuxApiService();
});

final shortVideosProvider =
    StateNotifierProvider.autoDispose<ShortVideosNotifier, List<Movie>>((ref) {
  return ShortVideosNotifier(ref);
});

class ShortVideosNotifier extends StateNotifier<List<Movie>> {
  final Ref _ref;
  int _currentPage = 1;
  bool _isLoading = false;

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
        print('Could not parse "passthrough" for asset $assetId: $e');
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

    try {
      final videoListJson = await apiService.getVideos(page: 1);

      final List<Future<Map<String, dynamic>?>> detailFutures = [];
      for (var videoData in videoListJson) {
        final assetId = videoData['id'] as String?;
        if (assetId != null) {
          detailFutures.add(apiService.getAssetDetails(assetId));
        }
      }

      final detailedAssets = await Future.wait(detailFutures);

      final List<Movie> movies = [];
      for (var assetDetails in detailedAssets) {
        if (assetDetails == null) continue;

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
        _currentPage = 2;
      }
    } catch (e, stackTrace) {
      FirebaseCrashlytics.instance.recordError(e, stackTrace,
          reason: 'Failed to fetch initial videos with details');
    } finally {
      _isLoading = false;
    }
  }

  Future<void> loadMoreVideos() async {
    // TODO: Implement loading of older videos when the database grows larger
  }

  Future<bool> refresh() async {
    if (_isLoading) return false;
    await fetchInitialVideos();
    return true;
  }
}

final currentVideoControllerProvider =
    StateProvider.autoDispose<VideoPlayerController?>((ref) => null);

final filterVisibilityProvider =
    StateProvider.autoDispose<bool>((ref) => false);

// --- UI ЧАСТЬ ---
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Short Movie Player',
      theme: ThemeData.dark().copyWith(
        textTheme: ThemeData.dark().textTheme.apply(
              fontFamily: 'Roboto',
            ),
      ),
      home: const ShortsPageView(),
    );
  }
}

// --- ЭКРАН С ПРОКРУТКОЙ (PageView) ---
class ShortsPageView extends ConsumerStatefulWidget {
  const ShortsPageView({super.key});
  @override
  ConsumerState<ShortsPageView> createState() => _ShortsPageViewState();
}

class _ShortsPageViewState extends ConsumerState<ShortsPageView> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final videos = ref.read(shortVideosProvider);
      if (videos.isNotEmpty) {
        ref.read(videoCacheManagerProvider).preload(_currentIndex, videos);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int newIndex) {
    setState(() {
      _currentIndex = newIndex;
    });

    final videoList = ref.read(shortVideosProvider);
    if (videoList.isEmpty) return;

    ref.read(videoCacheManagerProvider).preload(newIndex, videoList);

    if (newIndex == videoList.length - 1) {
      ref.read(shortVideosProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final videos = ref.watch(shortVideosProvider);
    if (videos.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => ref.read(shortVideosProvider.notifier).refresh(),
      color: Colors.white,
      backgroundColor: Colors.red,
      child: Scaffold(
        body: PageView.builder(
          controller: _pageController,
          scrollDirection: Axis.vertical,
          itemCount: videos.length,
          onPageChanged: _onPageChanged,
          itemBuilder: (context, index) {
            final movie = videos[index];
            return ShortPlayerScreen(
              key: ValueKey(movie.playbackId),
              movie: movie,
              index: index,
              isCurrent: index == _currentIndex,
            );
          },
        ),
      ),
    );
  }
}

// --- ЭКРАН ПЛЕЕРА КОРОТКИХ ВИДЕО ---
class ShortPlayerScreen extends ConsumerStatefulWidget {
  final Movie movie;
  final int index;
  final bool isCurrent;

  const ShortPlayerScreen({
    super.key,
    required this.movie,
    required this.index,
    required this.isCurrent,
  });

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

  String _selectedGenre = 'All';
  final List<String> _genres = [
    'All',
    'Action',
    'Adventure',
    'Comedy',
    'Drama',
    'Horror'
  ];

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void dispose() {
    _controlsVisibilityTimer?.cancel();
    _iconVisibilityTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeController() async {
    try {
      final controller = await ref
          .read(videoCacheManagerProvider)
          .getOrCreateController(widget.movie);

      if (mounted) {
        setState(() {
          _videoController = controller;
        });
        if (widget.isCurrent) {
          _startVideo();
          _showControlsAndStartTimer();
        }
      }
    } catch (e, stackTrace) {
      if (mounted) {
        setState(() {
          _videoError = "Ошибка загрузки видео:\n${e.toString()}";
        });
        FirebaseCrashlytics.instance.recordError(e, stackTrace,
            reason:
                'Failed to initialize video controller for ${widget.movie.playbackId}');
      }
    }
  }

  // --- Методы управления состоянием плеера ---

  void _startVideo() {
    if (_videoController == null) return;
    _videoController!.play();
    _startControlsTimeout();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(currentVideoControllerProvider.notifier).state =
            _videoController;
      }
    });
  }

  void _playVideo() {
    if (_videoController == null) return;
    _videoController!.play();
    _startControlsTimeout();
  }

  void _pauseVideo() {
    if (_videoController == null) return;
    _videoController!.pause();
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
      if (widget.isCurrent) {
        _startVideo();
      } else {
        _pauseAndResetVideo();
      }
    }
  }

  // --- Методы управления видимостью UI ---

  void _toggleCenterIconVisibility() {
    _iconVisibilityTimer?.cancel();
    if (mounted) {
      setState(() {
        _isCenterIconVisible = true;
      });
      _iconVisibilityTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _isCenterIconVisible = false;
          });
        }
      });
    }
  }

  void _startControlsTimeout({Duration duration = const Duration(seconds: 3)}) {
    _controlsVisibilityTimer?.cancel();
    if (_videoController?.value.isPlaying ?? false) {
      _controlsVisibilityTimer = Timer(duration, () {
        if (mounted) {
          setState(() {
            _areControlsVisible = false;
          });
        }
      });
    }
  }

  void _toggleControlsVisibility() {
    _controlsVisibilityTimer?.cancel();
    setState(() {
      _areControlsVisible = !_areControlsVisible;
    });
    if (_areControlsVisible) {
      _startControlsTimeout();
    }
  }

  void _showControlsAndStartTimer() {
    if (mounted) {
      setState(() {
        _areControlsVisible = true;
      });
      _startControlsTimeout();
    }
  }

  void _showControlsAndCancelTimer() {
    _controlsVisibilityTimer?.cancel();
    if (mounted && !_areControlsVisible) {
      setState(() {
        _areControlsVisible = true;
      });
    }
  }

  // --- МЕТОДЫ ПОСТРОЕНИЯ UI (BUILD METHODS) ---

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

              final isPlaying = _videoController!.value.isPlaying;
              if (isPlaying) {
                _pauseVideo();
              } else {
                if (mounted) {
                  setState(() {
                    _areControlsVisible = true;
                  });
                }
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
          Positioned(
            right: 16,
            bottom: 60,
            child: _buildRightSideBar(),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildInteractiveProgressBar(),
          ),
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
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text(_videoError!,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
          ),
        ),
      );
    }

    if (_videoController == null || !_videoController!.value.isInitialized) {
      return Center(
        child: Container(
          color: Colors.black,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white54),
              const SizedBox(height: 16),
              Text('Загрузка видео ${widget.index + 1}: ${widget.movie.title}',
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center)
            ],
          ),
        ),
      );
    }

    return Positioned.fill(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _videoController!.value.size.width,
          height: _videoController!.value.size.height,
          child: VideoPlayer(_videoController!),
        ),
      ),
    );
  }

  Widget _buildInteractiveProgressBar() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const SizedBox(height: 48);
    }
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: _videoController!,
      builder: (context, value, child) {
        final double max = value.duration.inMilliseconds.toDouble();
        final double current = value.position.inMilliseconds.toDouble();
        if (max.isNaN || max.isInfinite || max <= 0) {
          return const SizedBox(height: 48);
        }
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
          child: Slider(
            value: current.clamp(0.0, max),
            min: 0.0,
            max: max,
            onChanged: (newValue) {
              final newPosition = Duration(milliseconds: newValue.round());
              _videoController!.seekTo(newPosition);
            },
            onChangeStart: (newValue) {
              _controlsVisibilityTimer?.cancel();
              _wasPlayingBeforeScrub = _videoController!.value.isPlaying;
              if (_wasPlayingBeforeScrub) {
                _videoController!.pause();
              }
            },
            onChangeEnd: (newValue) {
              if (_wasPlayingBeforeScrub) {
                _videoController!.play();
              }
              _startControlsTimeout();
            },
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
              Colors.black.withOpacity(0.8),
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
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () {
                      ref.read(filterVisibilityProvider.notifier).state =
                          !showFilters;
                    }),
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
                                .map((genre) => _buildFilterChip(genre))
                                .toList(),
                          ),
                        )
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
    bool isSelected = _selectedGenre == genre;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Text(genre),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedGenre = genre;
          });
        },
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildActionIcon(Icons.favorite_border, "Like"),
        const SizedBox(height: 20),
        _buildActionIcon(Icons.bookmark_border, "Save"),
        const SizedBox(height: 20),
        _buildActionIcon(Icons.share, "Share"),
      ],
    );
  }

  Widget _buildActionIcon(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 30),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildBottomInfoPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.movie.title,
          style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 8),
        Text(
          widget.movie.description,
          style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.8)),
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 20),
            const SizedBox(width: 4),
            Text(
              widget.movie.rating.toString(),
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: widget.movie.genres
                      .map((genre) => _buildGenreTag(genre))
                      .toList(),
                ),
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
      child: Text(
        genre,
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
