import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsHelper {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  static Future<void> _logEvent(
    String name,
    Map<String, Object?> parameters,
  ) async {
    if (kDebugMode) {
      debugPrint('[Analytics] Event: $name, Params: $parameters');
    }

    final Map<String, Object> sanitizedParams = {
      for (var entry in parameters.entries)
        if (entry.value != null) entry.key: entry.value!,
    };

    await _analytics.logEvent(name: name, parameters: sanitizedParams);
  }

  static Future<void> logVideoEvent({
    required String eventType,
    String? videoId,
    int? position,
    int? duration,
    String? sessionId,
    Map<String, dynamic>? additionalParams,
  }) async {
    final parameters = <String, Object?>{
      'video_id': videoId,
      'video_position': position,
      'video_duration': duration,
      'user_session_id': sessionId,
      if (additionalParams != null) ...additionalParams,
    };

    await _logEvent('video_$eventType', parameters);
  }

  static Future<void> logAdEvent({
    required String eventType,
    required String adType,
    required String adUnitId,
    int? position,
    String? sessionId,
    Map<String, dynamic>? additionalParams,
  }) async {
    final parameters = <String, Object?>{
      'ad_type': adType,
      'ad_unit_id': adUnitId,
      'ad_position': position,
      'user_session_id': sessionId,
      if (additionalParams != null) ...additionalParams,
    };
    await _logEvent('ad_$eventType', parameters);
  }

  static Future<void> logAppEvent(
      {required String name, Map<String, dynamic>? parameters}) async {
    await _logEvent(name, parameters ?? {});
  }
}
