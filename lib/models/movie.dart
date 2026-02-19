class Movie {
  final String title;
  final double rating;
  final String description;
  final List<String> genres;
  final String imageUrl;
  final String? playbackId;

  const Movie({
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

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'rating': rating,
      'description': description,
      'genres': genres,
      'imageUrl': imageUrl,
      'playbackId': playbackId,
    };
  }

  factory Movie.fromMap(Map<String, dynamic> map) {
    return Movie(
      title: map['title'] ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      description: map['description'] ?? '',
      genres: List<String>.from(map['genres'] ?? []),
      imageUrl: map['imageUrl'] ?? '',
      playbackId: map['playbackId'],
    );
  }
}
