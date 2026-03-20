import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calkulator/providers.dart';
import 'package:calkulator/models/movie.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

// Fake Analytics implementation
class FakeFirebaseAnalytics extends Fake implements FirebaseAnalytics {
  @override
  Future<void> logEvent({
    required String name,
    Map<String, Object?>? parameters,
    AnalyticsCallOptions? callOptions,
  }) async {}
}

void main() {
  group('SelectedGenresProvider Tests', () {
    test('T1.1.1: Initial state is an empty Set', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(selectedGenresProvider);
      expect(state, isA<Set<String>>());
      expect(state, isEmpty);
    });

    test('T1.1.2: Adding a genre updates the state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(selectedGenresProvider.notifier).state = {'Action'};
      expect(container.read(selectedGenresProvider), contains('Action'));
    });

    test('T1.1.3: Removing a genre updates the state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(selectedGenresProvider.notifier).state = {'Action'};
      container.read(selectedGenresProvider.notifier).state = {};
      expect(container.read(selectedGenresProvider), isEmpty);
    });

    test('T1.1.4: Multiple genres can be selected', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(selectedGenresProvider.notifier).state = {'Comedy', 'Drama'};
      expect(container.read(selectedGenresProvider), contains('Comedy'));
      expect(container.read(selectedGenresProvider), contains('Drama'));
      expect(container.read(selectedGenresProvider).length, 2);
    });
  });

  group('AvailableGenresProvider Tests', () {
    final mockMovies = [
      Movie(title: 'V1', description: 'D1', playbackId: 'id1', rating: 4.5, genres: ['Action', 'Comedy'], imageUrl: ''),
      Movie(title: 'V2', description: 'D2', playbackId: 'id2', rating: 4.5, genres: ['Drama'], imageUrl: ''),
    ];

    test('T1.2.1 & T1.2.2: "All" is first, others are sorted alphabetically', () {
      final container = ProviderContainer(overrides: [
        firebaseAnalyticsProvider.overrideWithValue(FakeFirebaseAnalytics()),
        shortVideosProvider.overrideWith((ref) => ShortVideosNotifierMock(ref, mockMovies)),
      ]);
      addTearDown(container.dispose);

      final genres = container.read(availableGenresProvider);
      
      expect(genres.first, 'All');
      expect(genres, containsAllInOrder(['All', 'Action', 'Comedy', 'Drama']));
    });

    test('T1.2.3: Genres are unique', () {
       final moviesWithDuplicates = [
        Movie(title: 'V1', description: 'D1', playbackId: 'id1', rating: 4.5, genres: ['Action'], imageUrl: ''),
        Movie(title: 'V2', description: 'D2', playbackId: 'id2', rating: 4.5, genres: ['Action'], imageUrl: ''),
      ];
      final container = ProviderContainer(overrides: [
        firebaseAnalyticsProvider.overrideWithValue(FakeFirebaseAnalytics()),
        shortVideosProvider.overrideWith((ref) => ShortVideosNotifierMock(ref, moviesWithDuplicates)),
      ]);
      addTearDown(container.dispose);

      final genres = container.read(availableGenresProvider);
      expect(genres.where((g) => g == 'Action').length, 1);
    });
  });

  group('FilteredVideosProvider Tests (OR Logic)', () {
    final mockMovies = [
      Movie(title: 'Action Movie', description: 'D1', playbackId: 'id1', rating: 4.5, genres: ['Action'], imageUrl: ''),
      Movie(title: 'Comedy Movie', description: 'D2', playbackId: 'id2', rating: 4.5, genres: ['Comedy'], imageUrl: ''),
      Movie(title: 'Action Comedy', description: 'D3', playbackId: 'id3', rating: 4.5, genres: ['Action', 'Comedy'], imageUrl: ''),
      Movie(title: 'Drama Movie', description: 'D4', playbackId: 'id4', rating: 4.5, genres: ['Drama'], imageUrl: ''),
    ];

    test('T1.3.1: Empty selection returns all videos', () {
      final container = ProviderContainer(overrides: [
        firebaseAnalyticsProvider.overrideWithValue(FakeFirebaseAnalytics()),
        shortVideosProvider.overrideWith((ref) => ShortVideosNotifierMock(ref, mockMovies)),
      ]);
      addTearDown(container.dispose);

      final filtered = container.read(filteredVideosProvider);
      expect(filtered.length, mockMovies.length);
    });

    test('T1.3.2: Selecting one genre returns correct videos', () {
      final container = ProviderContainer(overrides: [
        firebaseAnalyticsProvider.overrideWithValue(FakeFirebaseAnalytics()),
        shortVideosProvider.overrideWith((ref) => ShortVideosNotifierMock(ref, mockMovies)),
      ]);
      addTearDown(container.dispose);

      container.read(selectedGenresProvider.notifier).state = {'Action'};
      final filtered = container.read(filteredVideosProvider);
      
      expect(filtered.every((m) => m.genres.contains('Action')), isTrue);
      expect(filtered.length, 2); // Action Movie and Action Comedy
    });

    test('T1.3.3: Selecting multiple genres (OR logic)', () {
      final container = ProviderContainer(overrides: [
        firebaseAnalyticsProvider.overrideWithValue(FakeFirebaseAnalytics()),
        shortVideosProvider.overrideWith((ref) => ShortVideosNotifierMock(ref, mockMovies)),
      ]);
      addTearDown(container.dispose);

      container.read(selectedGenresProvider.notifier).state = {'Comedy', 'Drama'};
      final filtered = container.read(filteredVideosProvider);
      
      // Should include Comedy Movie, Action Comedy, and Drama Movie
      expect(filtered.length, 3);
      expect(filtered.any((m) => m.title == 'Comedy Movie'), isTrue);
      expect(filtered.any((m) => m.title == 'Action Comedy'), isTrue);
      expect(filtered.any((m) => m.title == 'Drama Movie'), isTrue);
      expect(filtered.any((m) => m.title == 'Action Movie'), isFalse);
    });

    test('T1.3.4: No matches returns empty list', () {
      final container = ProviderContainer(overrides: [
        firebaseAnalyticsProvider.overrideWithValue(FakeFirebaseAnalytics()),
        shortVideosProvider.overrideWith((ref) => ShortVideosNotifierMock(ref, mockMovies)),
      ]);
      addTearDown(container.dispose);

      container.read(selectedGenresProvider.notifier).state = {'Horror'};
      final filtered = container.read(filteredVideosProvider);
      expect(filtered, isEmpty);
    });
  });
}

// Mock Notifier for stable tests
class ShortVideosNotifierMock extends ShortVideosNotifier {
  final List<Movie> mockData;
  ShortVideosNotifierMock(Ref ref, this.mockData) : super(ref) {
    // We override the state directly
    state = mockData;
  }

  @override
  Future<void> fetchInitialVideos() async {} // Do nothing
}
