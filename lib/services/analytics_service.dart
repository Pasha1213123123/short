// lib/services/analytics_service.dart

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../helpers/analytics_helper.dart';

class AnalyticsService {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final FirebaseCrashlytics _crashlytics = FirebaseCrashlytics.instance;

  static Future<void> initialize() async {
    await _analytics.setAnalyticsCollectionEnabled(true);
    await _crashlytics.setCrashlyticsCollectionEnabled(true);
  }

  static Future<void> logBatchEvents(List<Map<String, dynamic>> events) async {
    if (events.isEmpty) return;

    if (kDebugMode) {
      debugPrint('[Analytics] FLUSHING BATCH: ${events.length} events');
    }

    for (final event in events) {
      final name = event['name'] as String;
      final parameters = event['parameters'] as Map<String, dynamic>;

      // Батчинг по-прежнему использует старые методы, так как они уже оптимизированы для него
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
    await AnalyticsHelper.logVideoEvent(
      eventType: 'start',
      videoId: videoId,
      position: position,
      duration: duration,
      sessionId: sessionId,
    );
  }

  static Future<void> logVideoComplete(String videoId, int position,
      double completionRate, int watchTime) async {
    await AnalyticsHelper.logVideoEvent(
        eventType: 'complete',
        videoId: videoId,
        position: position,
        additionalParams: {
          'completion_rate': completionRate,
          'watch_time': watchTime,
        });
  }

  static Future<void> logVideoSkip(
      String videoId, int position, double skipTime, String skipReason) async {
    await AnalyticsHelper.logVideoEvent(
        eventType: 'skip',
        videoId: videoId,
        position: position,
        additionalParams: {
          'skip_time': skipTime,
          'skip_reason': skipReason,
        });
  }

  static Future<void> logVideoPause(
      String videoId, int position, double pauseTime) async {
    await AnalyticsHelper.logVideoEvent(
        eventType: 'pause',
        videoId: videoId,
        position: position,
        additionalParams: {'pause_time': pauseTime});
  }

  static Future<void> logVideoResume(
      String videoId, int position, double pauseDuration) async {
    await AnalyticsHelper.logVideoEvent(
        eventType: 'resume',
        videoId: videoId,
        position: position,
        additionalParams: {'pause_duration': pauseDuration});
  }

  static Future<void> logVideoSwipe(
      int from, int to, String direction, String speed) async {
    await AnalyticsHelper.logAppEvent(name: 'video_swipe', parameters: {
      'from_position': from,
      'to_position': to,
      'swipe_direction': direction,
      'swipe_speed': speed,
    });
  }

  // ======== РЕКЛАМА ========

  static Future<void> logAdShown(String adType, String adUnitId, int position,
      String sessionId, double loadTime) async {
    await AnalyticsHelper.logAdEvent(
        eventType: 'ad_interstitial_shown',
        adType: adType,
        adUnitId: adUnitId,
        position: position,
        sessionId: sessionId,
        additionalParams: {
          'ad_load_time': loadTime,
        });
  }

  static Future<void> logAdClick(
      String adType, String adUnitId, int position, String adNetwork) async {
    await AnalyticsHelper.logAdEvent(
        eventType: 'click',
        adType: adType,
        adUnitId: adUnitId,
        position: position,
        additionalParams: {
          'ad_network': adNetwork,
        });
  }

  static Future<void> logAdDismissed(String adType, String adUnitId,
      double dismissTime, String dismissMethod) async {
    await AnalyticsHelper.logAdEvent(
        eventType: 'dismissed',
        adType: adType,
        adUnitId: adUnitId,
        additionalParams: {
          'dismiss_time': dismissTime,
          'dismiss_method': dismissMethod,
        });
  }

  static Future<void> logAdCompleted(
      String adType, String adUnitId, double completionRate) async {
    await AnalyticsHelper.logAdEvent(
        eventType: 'completed',
        adType: adType,
        adUnitId: adUnitId,
        additionalParams: {
          'completion_rate': completionRate,
        });
  }

  static Future<void> logAdSkipped(
      String adType, String adUnitId, double skipTime) async {
    await AnalyticsHelper.logAdEvent(
        eventType: 'skipped',
        adType: adType,
        adUnitId: adUnitId,
        additionalParams: {'skip_time': skipTime});
  }

  static Future<void> logAdLoadFailed(String adType, String adUnitId,
      String errorCode, String errorMessage) async {
    await AnalyticsHelper.logAdEvent(
        eventType: 'load_failed',
        adType: adType,
        adUnitId: adUnitId,
        additionalParams: {
          'error_code': errorCode,
          'error_message': errorMessage,
        });
  }

  // ======== APP ========

  static Future<void> logAppStartup(
      int startupTime, String deviceModel, String appVersion) async {
    await AnalyticsHelper.logAppEvent(name: 'app_startup_time', parameters: {
      'startup_time_ms': startupTime,
      'device_model': deviceModel,
      'app_version': appVersion,
    });
  }

  static Future<void> logAdsInitialization(int initTime, bool success) async {
    await AnalyticsHelper.logAppEvent(
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
    await AnalyticsHelper.logAppEvent(name: 'video_load_error', parameters: {
      'video_id': videoId,
      'error_type': errorType,
      'error_message': errorMessage,
      'retry_count': retryCount,
    });
  }

  static Future<void> logYouTubePlayerError(
      String errorCode, String errorMessage, String videoId) async {
    await AnalyticsHelper.logAppEvent(
        name: 'youtube_player_error',
        parameters: {
          'error_code': errorCode,
          'error_message': errorMessage,
          'video_id': videoId,
        });
  }

  static Future<void> logNetworkError(
      String errorType, int retryCount, String connectionType) async {
    await AnalyticsHelper.logAppEvent(name: 'network_error', parameters: {
      'error_type': errorType,
      'retry_count': retryCount,
      'connection_type': connectionType,
    });
  }

  static Future<void> logSessionStart(String sessionId, String userId,
      String appVersion, String deviceInfo) async {
    await AnalyticsHelper.logAppEvent(name: 'app_session_start', parameters: {
      'session_id': sessionId,
      'user_id': userId,
      'app_version': appVersion,
      'device_info': deviceInfo,
    });
  }

  static Future<void> logSessionEnd(
      String sessionId, int duration, int videosWatched, int adsShown) async {
    await AnalyticsHelper.logAppEvent(name: 'session_end', parameters: {
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
    await AnalyticsHelper.logAppEvent(
        name: 'cache_hit', parameters: {'video_id': videoId});
  }

  static Future<void> logCacheMiss(String videoId) async {
    await AnalyticsHelper.logAppEvent(
        name: 'cache_miss', parameters: {'video_id': videoId});
  }

  static Future<void> logVideoPreloadStart(String videoId) async {
    await AnalyticsHelper.logAppEvent(
        name: 'video_preload_start', parameters: {'video_id': videoId});
  }

  static Future<void> logVideoPreloadSuccess(String videoId) async {
    await AnalyticsHelper.logAppEvent(
        name: 'video_preload_success', parameters: {'video_id': videoId});
  }

  static Future<void> logCacheCleanup(String reason, Object info) async {
    await AnalyticsHelper.logAppEvent(
        name: 'cache_cleanup',
        parameters: {'reason': reason, 'info': info.toString()});
  }

  static Future<void> logMemoryUsage(int usedMB) async {
    await AnalyticsHelper.logAppEvent(
        name: 'memory_usage', parameters: {'used_mb': usedMB});
  }

  static Future<void> logVideoPausedForAd(int page, String sessionId) async {
    await AnalyticsHelper.logAppEvent(name: 'video_paused_for_ad', parameters: {
      'page': page,
      'session_id': sessionId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> logVideoResumedAfterAd(int page, String sessionId) async {
    await AnalyticsHelper.logAppEvent(
        name: 'video_resumed_after_ad',
        parameters: {
          'page': page,
          'session_id': sessionId,
          'timestamp': DateTime.now().toIso8601String(),
        });
  }

  static Future<void> logVideoPauseFailed(int page, String error) async {
    await AnalyticsHelper.logAppEvent(
        name: 'video_pause_failed', parameters: {'page': page, 'error': error});
  }

  static Future<void> logVideoResumeFailed(int page, String error) async {
    await AnalyticsHelper.logAppEvent(
        name: 'video_resume_failed',
        parameters: {'page': page, 'error': error});
  }
}
