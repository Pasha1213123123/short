import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  static Future<void> initialize() async {
    await _analytics.setAnalyticsCollectionEnabled(true);
    await _crashlytics.setCrashlyticsCollectionEnabled(true);
  }

  // ✅ НОВЫЙ МЕТОД: для батчевой отправки
  static Future<void> logBatchEvents(List<Map<String, dynamic>> events) async {
    if (events.isEmpty) return;

    if (kDebugMode) {
      debugPrint('[Analytics] FLUSHING BATCH: ${events.length} events');
    }

    for (final event in events) {
      final name = event['name'] as String;
      final parameters = event['parameters'] as Map<String, dynamic>;

      switch (name) {
        case 'cache_hit':
          await logCacheHit(parameters['video_id'] as String);
          break;
        case 'cache_miss':
          await logCacheMiss(parameters['video_id'] as String);
          break;
        case 'cache_cleanup':
          await logCacheCleanup(
              parameters['reason'] as String, parameters['info']);
          break;
        case 'preload':
          await logVideoPreloadStart(parameters['video_id'] as String);
          break;
        default:
          if (kDebugMode) {
            debugPrint('  [Warning] Unknown batched event: $name');
          }
      }
    }
  }

  // ======== ВИДЕО ========

  static Future<void> logVideoStart(
      String videoId, int position, int duration, String sessionId) async {
    await _analytics.logEvent(name: 'video_start', parameters: {
      'video_id': videoId,
      'video_position': position,
      'video_duration': duration,
      'user_session_id': sessionId,
    });
  }

  static Future<void> logVideoComplete(String videoId, int position,
      double completionRate, int watchTime) async {
    await _analytics.logEvent(name: 'video_complete', parameters: {
      'video_id': videoId,
      'video_position': position,
      'completion_rate': completionRate,
      'watch_time': watchTime,
    });
  }

  static Future<void> logVideoSkip(
      String videoId, int position, double skipTime, String skipReason) async {
    await _analytics.logEvent(name: 'video_skip', parameters: {
      'video_id': videoId,
      'video_position': position,
      'skip_time': skipTime,
      'skip_reason': skipReason,
    });
  }

  static Future<void> logVideoPause(
      String videoId, int position, double pauseTime) async {
    await _analytics.logEvent(name: 'video_pause', parameters: {
      'video_id': videoId,
      'video_position': position,
      'pause_time': pauseTime,
    });
  }

  static Future<void> logVideoResume(
      String videoId, int position, double pauseDuration) async {
    await _analytics.logEvent(name: 'video_resume', parameters: {
      'video_id': videoId,
      'video_position': position,
      'pause_duration': pauseDuration,
    });
  }

  static Future<void> logVideoSwipe(
      int from, int to, String direction, String speed) async {
    await _analytics.logEvent(name: 'video_swipe', parameters: {
      'from_position': from,
      'to_position': to,
      'swipe_direction': direction,
      'swipe_speed': speed,
    });
  }

  // ======== РЕКЛАМА ========

  static Future<void> logAdShown(String adType, String adUnitId, int position,
      String sessionId, double loadTime) async {
    await _analytics.logEvent(name: 'ad_interstitial_shown', parameters: {
      'ad_type': adType,
      'ad_unit_id': adUnitId,
      'ad_position': position,
      'user_session_id': sessionId,
      'ad_load_time': loadTime,
    });
  }

  static Future<void> logAdClick(
      String adType, String adUnitId, int position, String adNetwork) async {
    await _analytics.logEvent(name: 'ad_click', parameters: {
      'ad_type': adType,
      'ad_unit_id': adUnitId,
      'click_position': position,
      'ad_network': adNetwork,
    });
  }

  static Future<void> logAdDismissed(String adType, String adUnitId,
      double dismissTime, String dismissMethod) async {
    await _analytics.logEvent(name: 'ad_dismissed', parameters: {
      'ad_type': adType,
      'ad_unit_id': adUnitId,
      'dismiss_time': dismissTime,
      'dismiss_method': dismissMethod,
    });
  }

  static Future<void> logAdCompleted(
      String adType, String adUnitId, double completionRate) async {
    await _analytics.logEvent(name: 'ad_completed', parameters: {
      'ad_type': adType,
      'ad_unit_id': adUnitId,
      'completion_rate': completionRate,
    });
  }

  static Future<void> logAdSkipped(
      String adType, String adUnitId, double skipTime) async {
    await _analytics.logEvent(name: 'ad_skipped', parameters: {
      'ad_type': adType,
      'ad_unit_id': adUnitId,
      'skip_time': skipTime,
    });
  }

  static Future<void> logAdLoadFailed(String adType, String adUnitId,
      String errorCode, String errorMessage) async {
    await _analytics.logEvent(name: 'ad_load_failed', parameters: {
      'ad_type': adType,
      'ad_unit_id': adUnitId,
      'error_code': errorCode,
      'error_message': errorMessage,
    });
  }

  // ======== APP ========

  static Future<void> logAppStartup(
      int startupTime, String deviceModel, String appVersion) async {
    await _analytics.logEvent(name: 'app_startup_time', parameters: {
      'startup_time_ms': startupTime,
      'device_model': deviceModel,
      'app_version': appVersion,
    });
  }

  static Future<void> logAdsInitialization(int initTime, bool success) async {
    await _analytics.logEvent(
      name: 'ads_initialization_time',
      parameters: {
        'init_time_ms': initTime,
        'success': success ? 1 : 0,
      },
    );
  }

  // ======== ERRORS ========

  static Future<void> logVideoLoadError(String videoId, String errorType,
      String errorMessage, int retryCount) async {
    await _analytics.logEvent(name: 'video_load_error', parameters: {
      'video_id': videoId,
      'error_type': errorType,
      'error_message': errorMessage,
      'retry_count': retryCount,
    });
  }

  static Future<void> logYouTubePlayerError(
      String errorCode, String errorMessage, String videoId) async {
    await _analytics.logEvent(name: 'youtube_player_error', parameters: {
      'error_code': errorCode,
      'error_message': errorMessage,
      'video_id': videoId,
    });
  }

  static Future<void> logNetworkError(
      String errorType, int retryCount, String connectionType) async {
    await _analytics.logEvent(name: 'network_error', parameters: {
      'error_type': errorType,
      'retry_count': retryCount,
      'connection_type': connectionType,
    });
  }

  static Future<void> logSessionStart(String sessionId, String userId,
      String appVersion, String deviceInfo) async {
    await _analytics.logEvent(name: 'app_session_start', parameters: {
      'session_id': sessionId,
      'user_id': userId,
      'app_version': appVersion,
      'device_info': deviceInfo,
    });
  }

  static Future<void> logSessionEnd(
      String sessionId, int duration, int videosWatched, int adsShown) async {
    await _analytics.logEvent(name: 'session_end', parameters: {
      'session_id': sessionId,
      'session_duration': duration,
      'videos_watched': videosWatched,
      'ads_shown': adsShown,
    });
  }

  // ======== КРАШИ ========

  static Future<void> logError(dynamic error, StackTrace stack,
      {String context = ''}) async {
    await _crashlytics.recordError(error, stack, reason: context);
  }

  static Future<void> setUserId(String userId) async {
    await _analytics.setUserId(id: userId);
  }

  static Future<void> setUserProperty(String name, String value) async {
    await _analytics.setUserProperty(name: name, value: value);
  }

  // ======== КЭШ + MEMORY (для батчера) ========

  static Future<void> logCacheHit(String videoId) async {
    await _analytics.logEvent(name: 'cache_hit', parameters: {
      'video_id': videoId,
    });
    if (kDebugMode) debugPrint('[Analytics] cache_hit $videoId');
  }

  static Future<void> logCacheMiss(String videoId) async {
    await _analytics.logEvent(name: 'cache_miss', parameters: {
      'video_id': videoId,
    });
    if (kDebugMode) debugPrint('[Analytics] cache_miss $videoId');
  }

  static Future<void> logVideoPreloadStart(String videoId) async {
    await _analytics.logEvent(name: 'video_preload_start', parameters: {
      'video_id': videoId,
    });
    if (kDebugMode) debugPrint('[Analytics] preload_start $videoId');
  }

  static Future<void> logVideoPreloadSuccess(String videoId) async {
    await _analytics.logEvent(name: 'video_preload_success', parameters: {
      'video_id': videoId,
    });
    if (kDebugMode) debugPrint('[Analytics] preload_success $videoId');
  }

  static Future<void> logCacheCleanup(String reason, Object info) async {
    await _analytics.logEvent(name: 'cache_cleanup', parameters: {
      'reason': reason,
      'info': info.toString(),
    });
    if (kDebugMode)
      debugPrint('[Analytics] cache_cleanup reason=$reason info=$info');
  }

  static Future<void> logMemoryUsage(int usedMB) async {
    await _analytics.logEvent(name: 'memory_usage', parameters: {
      'used_mb': usedMB,
    });
    if (kDebugMode) debugPrint('[Analytics] memory_usage ${usedMB}MB');
  }

  static Future<void> logVideoPausedForAd(int page, String sessionId) async {
    await _analytics.logEvent(name: 'video_paused_for_ad', parameters: {
      'page': page,
      'session_id': sessionId,
      'timestamp': DateTime.now().toIso8601String(),
    });
    if (kDebugMode)
      debugPrint(
          '[Analytics] video_paused_for_ad page=$page session=$sessionId');
  }

  static Future<void> logVideoResumedAfterAd(int page, String sessionId) async {
    await _analytics.logEvent(name: 'video_resumed_after_ad', parameters: {
      'page': page,
      'session_id': sessionId,
      'timestamp': DateTime.now().toIso8601String(),
    });
    if (kDebugMode)
      debugPrint(
          '[Analytics] video_resumed_after_ad page=$page session=$sessionId');
  }

  static Future<void> logVideoPauseFailed(int page, String error) async {
    await _analytics.logEvent(name: 'video_pause_failed', parameters: {
      'page': page,
      'error': error,
    });
    if (kDebugMode)
      debugPrint('[Analytics] video_pause_failed page=$page error=$error');
  }

  static Future<void> logVideoResumeFailed(int page, String error) async {
    await _analytics.logEvent(name: 'video_resume_failed', parameters: {
      'page': page,
      'error': error,
    });
    if (kDebugMode)
      debugPrint('[Analytics] video_resume_failed page=$page error=$error');
  }
}
