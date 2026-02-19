import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../l10n/app_localizations.dart';
import '../models/movie.dart';
import '../providers.dart';
import '../services/video_cache_manager.dart';
import '../utils/constants.dart';
import 'settings_screen.dart';
import 'short_player_screen.dart';
import 'upload_screen.dart';

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
      final videos = ref.read(filteredVideosProvider);
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
    final videos = ref.read(filteredVideosProvider);
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

            await Future.delayed(AppConstants.navigationDelay);
            final freshController = ref.read(currentVideoControllerProvider);
            if (freshController != null && !freshController.value.isPlaying) {
              await freshController.play();
            }
          },
          backgroundColor: theme.colorScheme.surface,
          child: Icon(Icons.add, color: theme.colorScheme.onSurface, size: 30),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
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
    final selectedGenre = ref.watch(selectedGenreProvider);
    const genres = ['All', 'Action', 'Adventure', 'Comedy', 'Drama', 'Horror'];
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
                              children: genres
                                  .map((g) => GenreFilterChip(
                                      genre: g,
                                      isSelected: selectedGenre == g,
                                      onSelected: (val) => ref
                                          .read(selectedGenreProvider.notifier)
                                          .state = g))
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
}

class GenreFilterChip extends StatelessWidget {
  final String genre;
  final bool isSelected;
  final Function(bool) onSelected;

  const GenreFilterChip(
      {super.key,
      required this.genre,
      required this.isSelected,
      required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ChoiceChip(
        label: Text(genre),
        selected: isSelected,
        onSelected: onSelected,
      ),
    );
  }
}
