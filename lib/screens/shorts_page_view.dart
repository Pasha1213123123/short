import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../l10n/app_localizations.dart';
import '../models/movie.dart';
import '../providers.dart';
import '../services/ads_manager.dart';
import '../services/video_cache_manager.dart';
import 'settings_screen.dart';
import 'short_player_screen.dart';

class ShortsPageView extends ConsumerStatefulWidget {
  const ShortsPageView({super.key});
  @override
  ConsumerState<ShortsPageView> createState() => _ShortsPageViewState();
}

class _ShortsPageViewState extends ConsumerState<ShortsPageView> {
  late PageController _pageController;
  int _currentIndex = 0;

  late final FirebaseAnalytics _analytics;
  final Stopwatch _watchTimeStopwatch = Stopwatch();

  // Ads counters
  int _swipeCounter = 0;

  @override
  void initState() {
    super.initState();
    _analytics = ref.read(firebaseAnalyticsProvider);
    _pageController = PageController();
    _watchTimeStopwatch.start();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final videos = ref.read(filteredVideosProvider);
      if (videos.isNotEmpty) {
        _logVideoView(videos[0]);
        ref.read(videoCacheManagerProvider).preload(_currentIndex, videos);
      }
    });

    // Listen for filter changes to reset index
    ref.listenManual(filteredVideosProvider, (previous, next) {
      if (previous != next) {
        setState(() {
          _currentIndex = 0;
          _swipeCounter = 0; // Reset counters on filter change
        });
        if (_pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
        ref.read(videoCacheManagerProvider).preload(0, next);
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

  Future<void> _tryToShowAd() async {
    final adManager = AdsManager.instance;
    if (adManager.isAdShowing) return;

    // Log attempt
    _analytics.logEvent(name: 'ad_interstitial_attempt');

    // Pause video globally
    ref.read(isAdShowingProvider.notifier).state = true;
    final controller = ref.read(currentVideoControllerProvider);
    
    // Safety check just in case, but ShortPlayerScreen also listens to the provider
    if (controller?.value.isPlaying ?? false) {
      await controller?.pause();
    }

    // Enter full immersive mode (hide status bar and navigation bar)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Show ad and wait for dismissal
    final adShown = await adManager.showInterstitialAd();
    
    if (adShown) {
      _analytics.logEvent(name: 'ad_interstitial_success');
    }

    // Restore normal system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Unpause globally
    ref.read(isAdShowingProvider.notifier).state = false;
  }

  void _onPageChanged(int newIndex) async {
    final videos = ref.read(filteredVideosProvider);
    if (videos.isEmpty) return;

    // Handle swipe counter (Trigger every swipe: N=3)
    _swipeCounter++;
    debugPrint('Swipe Counter: $_swipeCounter');
    if (_swipeCounter >= 3) {
      _swipeCounter = 0;
      await _tryToShowAd();
    }

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
    final videos = ref.watch(shortVideosProvider.select((value) => value));
    final filteredVideos = ref.watch(filteredVideosProvider);

    final status = ref.watch(feedStatusProvider);
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    // Экран загрузки
    if (status == FeedStatus.loading && videos.isEmpty) {
      return Scaffold(
        body: Shimmer.fromColors(
          baseColor: theme.colorScheme.surface,
          highlightColor: theme.colorScheme.onSurface.withOpacity(0.1),
          child: Container(color: theme.scaffoldBackgroundColor),
        ),
      );
    }

    // Экран ошибки
    if (status == FeedStatus.error && videos.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  size: 60, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              const Text("Failed to load videos"),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () =>
                    ref.read(shortVideosProvider.notifier).refresh(),
                child: const Text("Retry"),
              )
            ],
          ),
        ),
      );
    }

    // Экран пустого списка
    if (videos.isEmpty && status == FeedStatus.success) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          actions: [
            IconButton(
              icon: Icon(Icons.settings, color: theme.colorScheme.onSurface),
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen())),
            )
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off, size: 60, color: theme.disabledColor),
              const SizedBox(height: 16),
              Text("No videos found",
                  style: TextStyle(color: theme.disabledColor)),
            ],
          ),
        ),
      );
    }

    // Основной контент
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: RefreshIndicator(
        onRefresh: () => ref.read(shortVideosProvider.notifier).refresh(),
        color: theme.colorScheme.onSurface,
        backgroundColor: theme.colorScheme.primary,
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: filteredVideos.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                return ShortPlayerScreen(
                  key: ValueKey(filteredVideos[index].playbackId),
                  movie: filteredVideos[index],
                  index: index,
                  isCurrent: index == _currentIndex,
                  onVideoFinished: () {
                    if (index < filteredVideos.length - 1) {
                      if (mounted) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    }
                  },
                );
              },
            ),
            _buildTopBar(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, WidgetRef ref) {
    final showFilters = ref.watch(filterVisibilityProvider);
    final selectedGenres = ref.watch(selectedGenresProvider);
    final genres = ref.watch(availableGenresProvider);
    final theme = Theme.of(context);

    final overlayColor = theme.colorScheme.surface.withOpacity(0.6);
    final iconColor = theme.colorScheme.onSurface;

    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 8.0, left: 16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                        color: overlayColor,
                        borderRadius: BorderRadius.circular(8)),
                    child: IconButton(
                        tooltip: "Filters",
                        icon: Icon(Icons.menu, color: iconColor),
                        onPressed: () => ref
                            .read(filterVisibilityProvider.notifier)
                            .state = !showFilters),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                        color: overlayColor,
                        borderRadius: BorderRadius.circular(8)),
                    child: IconButton(
                      tooltip: "Settings",
                      icon: Icon(Icons.settings, color: iconColor),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const SettingsScreen())),
                    ),
                  ),
                ],
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
                              children: genres.map((g) {
                            final isAll = g == 'All';
                            final isSelected = isAll
                                ? selectedGenres.isEmpty
                                : selectedGenres.contains(g);

                            return GenreFilterChip(
                              genre: g,
                              isSelected: isSelected,
                              onSelected: (selected) {
                                if (isAll) {
                                  ref
                                      .read(selectedGenresProvider.notifier)
                                      .state = {};
                                } else {
                                  final current = ref.read(selectedGenresProvider);
                                  if (selected) {
                                    ref.read(selectedGenresProvider.notifier).state =
                                        {...current, g};
                                  } else {
                                    ref.read(selectedGenresProvider.notifier).state =
                                        {...current}..remove(g);
                                  }
                                }
                              },
                            );
                          }).toList()))
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GenreFilterChip extends StatelessWidget {
  final String genre;
  final bool isSelected;
  final ValueChanged<bool> onSelected;

  const GenreFilterChip(
      {super.key,
      required this.genre,
      required this.isSelected,
      required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: FilterChip(
        label: Text(genre),
        selected: isSelected,
        onSelected: onSelected,
      ),
    );
  }
}
