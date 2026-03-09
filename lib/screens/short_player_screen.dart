import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:video_player/video_player.dart';

import '../l10n/app_localizations.dart';
import '../models/movie.dart';
import '../providers.dart';
import '../services/video_cache_manager.dart';
import '../theme/app_theme.dart';
import '../utils/constants.dart';
import '../utils/logger.dart';

class ShortPlayerScreen extends ConsumerStatefulWidget {
  final Movie movie;
  final int index;
  final bool isCurrent;
  final VoidCallback? onVideoFinished;

  const ShortPlayerScreen({
    super.key,
    required this.movie,
    required this.index,
    required this.isCurrent,
    this.onVideoFinished,
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

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void dispose() {
    _videoController?.removeListener(_videoListener);
    _controlsVisibilityTimer?.cancel();
    _iconVisibilityTimer?.cancel();
    if (widget.isCurrent) {
      Future.microtask(() {
        try {
          ref.read(currentVideoControllerProvider.notifier).state = null;
        } catch (_) {}
      });
    }
    super.dispose();
  }

  void _videoListener() {
    if (!mounted || _videoController == null) return;
    
    final value = _videoController!.value;
    if (value.position >= value.duration && !value.isPlaying && value.isInitialized) {
      final isAutoplayEnabled = ref.read(autoplayProvider);
      if (isAutoplayEnabled) {
        widget.onVideoFinished?.call();
      }
    }
  }

  Future<void> _initializeController() async {
    try {
      final controller = await ref
          .read(videoCacheManagerProvider)
          .getOrCreateController(widget.movie);
      if (mounted) {
        setState(() => _videoController = controller);
        
        // Настройка зацикливания в зависимости от Autoplay
        final isAutoplayEnabled = ref.read(autoplayProvider);
        _videoController!.setLooping(!isAutoplayEnabled);
        _videoController!.addListener(_videoListener);

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
      _iconVisibilityTimer = Timer(AppConstants.iconAnimationDuration, () {
        if (mounted) setState(() => _isCenterIconVisible = false);
      });
    }
  }

  void _startControlsTimeout(
      {Duration duration = AppConstants.controlsHideDuration}) {
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
          color: Theme.of(context).colorScheme.error.withOpacity(0.8),
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

    return Consumer(builder: (context, ref, child) {
      return ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: _videoController!,
          builder: (context, value, child) {
            final double max = value.duration.inMilliseconds.toDouble();
            final double current = value.position.inMilliseconds.toDouble();
            if (max <= 0) return const SizedBox(height: 48);

            return Semantics(
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
            );
          });
    });
  }

  Widget _buildGradientOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.videoOverlayGradient,
        ),
      ),
    );
  }

  Widget _buildRightSideBar() {
    return _buildUnifiedFab();
  }

  Widget _buildUnifiedFab() {
    final loc = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final videoId = widget.movie.playbackId ?? 'unknown';

    // Состояния для Like и Bookmark
    final likedVideos = ref.watch(likedVideosProvider);
    final isLiked = likedVideos.contains(videoId);
    final bookmarkedVideos = ref.watch(bookmarkedVideosProvider);
    final isBookmarked = bookmarkedVideos.contains(videoId);

    final warningColor =
        theme.extension<AppColorsExtension>()?.warning ?? Colors.amber;

    return SpeedDial(
      icon: Icons.more_vert,
      activeIcon: Icons.close,
      backgroundColor: Colors.black54,
      foregroundColor: Colors.white,
      activeBackgroundColor: theme.colorScheme.primary,
      activeForegroundColor: Colors.white,
      visible: true,
      closeManually: false,
      renderOverlay: false,
      curve: Curves.bounceIn,
      spacing: 12,
      spaceBetweenChildren: 12,
      children: [
        // Like
        SpeedDialChild(
          child: Icon(isLiked ? Icons.favorite : Icons.favorite_border,
              color: isLiked ? theme.colorScheme.primary : Colors.white),
          backgroundColor: Colors.black87,
          label: loc.like,
          labelStyle: const TextStyle(fontSize: 14.0, color: Colors.white),
          labelBackgroundColor: Colors.black54,
          onTap: () {
            HapticFeedback.lightImpact();
            ref.read(likedVideosProvider.notifier).toggle(videoId);
            FirebaseAnalytics.instance.logEvent(
              name: isLiked ? 'video_unliked' : 'video_liked',
              parameters: {'video_id': videoId},
            );
          },
        ),
        // Favorite
        SpeedDialChild(
          child: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: isBookmarked ? warningColor : Colors.white),
          backgroundColor: Colors.black87,
          label: loc.save,
          labelStyle: const TextStyle(fontSize: 14.0, color: Colors.white),
          labelBackgroundColor: Colors.black54,
          onTap: () {
            HapticFeedback.lightImpact();
            ref.read(bookmarkedVideosProvider.notifier).toggle(videoId);
            FirebaseAnalytics.instance.logEvent(
              name: isBookmarked ? 'video_unsaved' : 'video_saved',
              parameters: {'video_id': videoId},
            );
          },
        ),
        // Share
        SpeedDialChild(
          child: const Icon(Icons.share, color: Colors.white),
          backgroundColor: Colors.black87,
          label: loc.share,
          labelStyle: const TextStyle(fontSize: 14.0, color: Colors.white),
          labelBackgroundColor: Colors.black54,
          onTap: () async {
            HapticFeedback.mediumImpact();
            FirebaseAnalytics.instance.logEvent(
              name: 'video_shared',
              parameters: {'video_id': videoId},
            );
            final String url = widget.movie.videoUrl.toString();
            await Clipboard.setData(ClipboardData(text: url));

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text("Ссылка на видео скопирована"),
                  duration: AppConstants.snackBarDuration,
                  backgroundColor: theme.colorScheme.secondary,
                ),
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildBottomInfoPanel() {
    final theme = Theme.of(context);
    final warningColor =
        theme.extension<AppColorsExtension>()?.warning ?? Colors.amber;

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
            Icon(Icons.star, color: warningColor, size: 20),
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
                        .map((g) => GenreTag(genre: g))
                        .toList()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class GenreTag extends StatelessWidget {
  final String genre;
  const GenreTag({super.key, required this.genre});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20)),
      child: Text(genre,
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
