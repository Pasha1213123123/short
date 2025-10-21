import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

class Movie {
  final String title;
  final double rating;
  final String description;
  final List<String> genres;
  final String imageUrl;

  Movie({
    required this.title,
    required this.rating,
    required this.description,
    required this.genres,
    required this.imageUrl,
  });
}

void main() {
  final sampleMovie = Movie(
    title: 'Lost in the Woods',
    rating: 4.5,
    description: 'A thrilling adventure through mysterious forests',
    genres: ['Adventure', 'Thriller', 'Mystery'],
    imageUrl: '',
  );

  runApp(
    ProviderScope(
      child: MyApp(sampleMovie: sampleMovie),
    ),
  );
}

class MyApp extends StatelessWidget {
  final Movie sampleMovie;

  const MyApp({super.key, required this.sampleMovie});

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
      home: ShortPlayerScreen(movie: sampleMovie),
    );
  }
}

class ShortPlayerScreen extends ConsumerStatefulWidget {
  final Movie movie;

  const ShortPlayerScreen({super.key, required this.movie});

  @override
  ConsumerState<ShortPlayerScreen> createState() => _ShortPlayerScreenState();
}

class _ShortPlayerScreenState extends ConsumerState<ShortPlayerScreen> {
  late VideoPlayerController _videoController;
  bool _isVideoInitialized = false;

  bool _isIconVisible = false;
  Timer? _iconVisibilityTimer;

  String _selectedGenre = 'All';
  bool _showFilters = true;
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
    _videoController = VideoPlayerController.asset('assets/test.mp4')
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isVideoInitialized = true;
          });
          _videoController.play();
          _videoController.setLooping(true);
        }
      });

    _videoController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _videoController.dispose();
    _iconVisibilityTimer?.cancel();
    super.dispose();
  }

  void _toggleIconVisibility() {
    _isIconVisible = true;
    _iconVisibilityTimer?.cancel();

    _iconVisibilityTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isIconVisible = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildBackgroundVideoPlayer(),
          _buildGradientOverlay(),
          _buildCenterControls(),
          _buildFullScreenTapHandler(),
          _buildTopBar(),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(child: _buildBottomInfoPanel()),
                    _buildRightSideBar(),
                  ],
                ),
                const SizedBox(height: 12),
                _buildProgressBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullScreenTapHandler() {
    return Positioned.fill(
      child: GestureDetector(
        child: Container(color: Colors.transparent),
        onTap: () {
          _toggleIconVisibility();

          setState(() {
            if (_videoController.value.isPlaying) {
              _videoController.pause();
            } else {
              _videoController.play();
            }
          });
        },
      ),
    );
  }

  Widget _buildCenterControls() {
    final IconData icon = _videoController.value.isPlaying
        ? Icons.pause
        : Icons.play_arrow_rounded;

    return Center(
      child: AnimatedOpacity(
        opacity: _isIconVisible ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 150),
        child: IgnorePointer(
          child: Icon(
            icon,
            size: 80,
            color: Colors.white.withOpacity(0.85),
          ),
        ),
      ),
    );
  }

  Widget _buildBackgroundVideoPlayer() {
    if (_isVideoInitialized) {
      return Positioned.fill(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _videoController.value.size.width,
            height: _videoController.value.size.height,
            child: VideoPlayer(_videoController),
          ),
        ),
      );
    } else {
      return Container(color: Colors.black);
    }
  }

  Widget _buildProgressBar() {
    double progress = 0.0;
    if (_videoController.value.isInitialized &&
        _videoController.value.duration.inMilliseconds > 0) {
      progress = _videoController.value.position.inMilliseconds /
          _videoController.value.duration.inMilliseconds;
    }

    return SizedBox(
      height: 4,
      child: LinearProgressIndicator(
        value: progress,
        backgroundColor: Colors.white.withOpacity(0.3),
        valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
      ),
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
                  color: _showFilters ? Colors.black.withOpacity(0.5) : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.menu, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _showFilters = !_showFilters;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _showFilters
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
          fontWeight: FontWeight.w600,
        ),
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
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
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
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.movie.description,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.8),
          ),
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
                color: Colors.white,
              ),
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
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        genre,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
