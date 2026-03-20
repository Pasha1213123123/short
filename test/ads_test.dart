import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:calkulator/screens/shorts_page_view.dart';
import 'package:calkulator/providers.dart';
import 'package:calkulator/models/movie.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:calkulator/l10n/app_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Mocks
class MockFirebaseAnalytics extends Mock implements FirebaseAnalytics {}
class MockFirebaseCrashlytics extends Mock implements FirebaseCrashlytics {}
class MockFirebasePerformance extends Mock implements FirebasePerformance {}

class FakeVideoPlayerPlatform extends VideoPlayerPlatform with Mock implements MockPlatformInterfaceMixin {
  @override
  Future<void> init() async {}
  @override
  Future<int> create(DataSource dataSource) async => 1;
  @override
  Future<void> dispose(int textureId) async {}
  @override
  Stream<VideoEvent> videoEventsFor(int textureId) => const Stream.empty();
  @override
  Future<void> setLooping(int textureId, bool looping) async {}
  @override
  Future<void> play(int textureId) async {}
  @override
  Future<void> pause(int textureId) async {}
}

void main() {
  late MockFirebaseAnalytics mockAnalytics;
  late MockFirebaseCrashlytics mockCrashlytics;
  late MockFirebasePerformance mockPerformance;

  setUpAll(() async {
    registerFallbackValue(const {});
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
    
    await dotenv.load(mergeWith: {
      'ADMOB_INTERSTITIAL_ID_ANDROID': 'test',
      'ADMOB_INTERSTITIAL_ID_IOS': 'test',
    });
  });

  setUp(() {
    mockAnalytics = MockFirebaseAnalytics();
    mockCrashlytics = MockFirebaseCrashlytics();
    mockPerformance = MockFirebasePerformance();

    when(() => mockAnalytics.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        )).thenAnswer((_) async {});

    // Fix for recordError crash
    when(() => mockCrashlytics.recordError(
      any(),
      any(),
      reason: any(named: 'reason'),
      information: any(named: 'information'),
      printDetails: any(named: 'printDetails'),
      fatal: any(named: 'fatal'),
    )).thenAnswer((_) async {});
  });

  final testVideos = List.generate(
    10,
    (i) => Movie(
      title: 'Video $i',
      rating: 4.5,
      description: 'Desc $i',
      genres: ['Action'],
      imageUrl: 'url$i',
      playbackId: 'p$i',
    ),
  );

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        filteredVideosProvider.overrideWithValue(testVideos),
        firebaseAnalyticsProvider.overrideWithValue(mockAnalytics),
        firebaseCrashlyticsProvider.overrideWithValue(mockCrashlytics),
        firebasePerformanceProvider.overrideWithValue(mockPerformance),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: [
          Locale('en'),
        ],
        home: ShortsPageView(),
      ),
    );
  }

  testWidgets('Trigger A: Ad attempt is logged after 5 swipes forward', (tester) async {
    await tester.pumpWidget(createTestWidget());
    await tester.pump(const Duration(seconds: 1)); 

    final pageViewFinder = find.byType(PageView);
    expect(pageViewFinder, findsOneWidget);

    // Swipe 5 times
    for (int i = 0; i < 5; i++) {
      await tester.drag(pageViewFinder, const Offset(0, -600));
      await tester.pump(const Duration(milliseconds: 500));
    }

    verify(() => mockAnalytics.logEvent(name: 'ad_interstitial_attempt')).called(1);
    
    // Cleanup pending timers to avoid test failure
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });
}
