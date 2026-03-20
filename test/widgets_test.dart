import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calkulator/screens/shorts_page_view.dart';
import 'package:calkulator/screens/upload_screen.dart';
import 'package:calkulator/providers.dart';
import 'package:calkulator/models/movie.dart';
import 'package:calkulator/l10n/app_localizations.dart';
import 'package:calkulator/services/video_cache_manager.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:video_player/video_player.dart';

// Fake Analytics
class FakeFirebaseAnalytics extends Fake implements FirebaseAnalytics {
  @override
  Future<void> logEvent({required String name, Map<String, Object?>? parameters, AnalyticsCallOptions? callOptions}) async {}
}

// Fake Crashlytics
class FakeFirebaseCrashlytics extends Fake implements FirebaseCrashlytics {
  @override
  Future<void> recordError(dynamic exception, StackTrace? stack, {dynamic reason, Iterable<Object> information = const [], bool? printDetails, bool fatal = false}) async {}
}

// Mock VideoCacheManager
class VideoCacheManagerMock extends Fake implements VideoCacheManager {
  @override
  Future<VideoPlayerController> getOrCreateController(Movie movie) async {
    // Return a dummy controller that is not initialized to avoid platform errors
    return VideoPlayerController.networkUrl(Uri.parse('https://example.com'));
  }
  @override
  void preload(int index, List<Movie> movies) {}
}

// Mock Notifier
class ShortVideosNotifierMock extends ShortVideosNotifier {
  final List<Movie> mockData;
  ShortVideosNotifierMock(Ref ref, this.mockData) : super(ref) {
    state = mockData;
  }
  @override
  Future<void> _init() async {}
  @override
  Future<void> fetchInitialVideos() async {}
}

void main() {
  final mockMovies = [
    Movie(title: 'Action Movie', description: 'D1', playbackId: 'id1', rating: 4.5, genres: ['Action'], imageUrl: 'https://example.com/img1.jpg'),
    Movie(title: 'Comedy Movie', description: 'D2', playbackId: 'id2', rating: 4.5, genres: ['Comedy'], imageUrl: 'https://example.com/img2.jpg'),
  ];

  Widget createTestWidget(Widget child, {List overrides = const []}) {
    return ProviderScope(
      overrides: [
        firebaseAnalyticsProvider.overrideWithValue(FakeFirebaseAnalytics()),
        firebaseCrashlyticsProvider.overrideWithValue(FakeFirebaseCrashlytics()),
        videoCacheManagerProvider.overrideWithValue(VideoCacheManagerMock()),
        ...overrides,
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ru'), Locale('uk')],
        home: child,
      ),
    );
  }

  group('ShortsPageView Widget Tests', () {
    testWidgets('T2.1.1 & T2.1.2: Filters are visible and "All" is selected by default', (tester) async {
      await tester.pumpWidget(createTestWidget(
        const ShortsPageView(),
        overrides: [
          shortVideosProvider.overrideWith((ref) => ShortVideosNotifierMock(ref, mockMovies)),
          filterVisibilityProvider.overrideWith((ref) => true),
        ],
      ));

      await tester.pump(); // Start animations
      await tester.pump(const Duration(seconds: 1)); // Wait for AnimatedSize

      expect(find.byType(FilterChip), findsWidgets);
      
      final allChip = tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'All'));
      expect(allChip.selected, isTrue);
    });

    testWidgets('T2.1.3: Toggling a genre chip', (tester) async {
      await tester.pumpWidget(createTestWidget(
        const ShortsPageView(),
        overrides: [
          shortVideosProvider.overrideWith((ref) => ShortVideosNotifierMock(ref, mockMovies)),
          filterVisibilityProvider.overrideWith((ref) => true),
        ],
      ));

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Use a more specific finder to avoid ambiguity with video title/desc
      final actionChipFinder = find.ancestor(
        of: find.text('Action'),
        matching: find.byType(FilterChip),
      );

      await tester.tap(actionChipFinder);
      await tester.pump();

      final allChip = tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'All'));
      expect(allChip.selected, isFalse);

      final actionChip = tester.widget<FilterChip>(actionChipFinder);
      expect(actionChip.selected, isTrue);
    });

    testWidgets('T2.1.4: Tapping "All" clears other filters', (tester) async {
       await tester.pumpWidget(createTestWidget(
        const ShortsPageView(),
        overrides: [
          shortVideosProvider.overrideWith((ref) => ShortVideosNotifierMock(ref, mockMovies)),
          filterVisibilityProvider.overrideWith((ref) => true),
        ],
      ));

      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final actionChipFinder = find.ancestor(
        of: find.text('Action'),
        matching: find.byType(FilterChip),
      );

      await tester.tap(actionChipFinder);
      await tester.pump();
      
      await tester.tap(find.widgetWithText(FilterChip, 'All'));
      await tester.pump();

      final allChip = tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'All'));
      expect(allChip.selected, isTrue);

      final actionChip = tester.widget<FilterChip>(actionChipFinder);
      expect(actionChip.selected, isFalse);
    });
  });

  group('UploadScreen Widget Tests', () {
    testWidgets('T3.1.1 & T3.1.3: Localization and Genre Exclusion', (tester) async {
      await tester.pumpWidget(createTestWidget(
        const UploadScreen(),
        overrides: [
          shortVideosProvider.overrideWith((ref) => ShortVideosNotifierMock(ref, mockMovies)),
        ],
      ));

      await tester.pumpAndSettle();

      expect(find.text('Select Genres'), findsOneWidget);

      expect(find.widgetWithText(FilterChip, 'All'), findsNothing);
      expect(find.widgetWithText(FilterChip, 'Mux'), findsNothing);
      expect(find.widgetWithText(FilterChip, 'API'), findsNothing);
      
      expect(find.widgetWithText(FilterChip, 'Action'), findsOneWidget);
    });
  });
}
