class Movie {
  final String title;
  final double rating;
  final String description;
  final List<String> genres;
  final String imageUrl;

  const Movie({
    required this.title,
    required this.rating,
    required this.description,
    required this.genres,
    required this.imageUrl,
  });

  factory Movie.fromJson(Map<String, dynamic> json) {
    return Movie(
      title: json['title'] as String,
      rating: (json['rating'] as num).toDouble(),
      description: json['description'] as String,
      genres: (json['genres'] as List<dynamic>).cast<String>(),
      imageUrl: json['imageUrl'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'rating': rating,
      'description': description,
      'genres': genres,
      'imageUrl': imageUrl,
    };
  }
}
