// lib/utils/video_player_utils.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../services/analytics_service.dart';

class VideoPlayerUtils {
  static Future<void> playWithRetry({
    required YoutubePlayerController controller,
    int maxAttempts = 3,
    Duration retryInterval = const Duration(milliseconds: 500),
    Duration readyCheckInterval = const Duration(milliseconds: 100),
    String? debugContext,
    bool shouldSeekToZero = false,
    String? videoId,
    String? sessionId,
  }) async {
    // Ждем, пока контроллер будет готов
    while (!controller.value.isReady) {
      await Future.delayed(readyCheckInterval);
    }

    if (shouldSeekToZero) {
      controller.seekTo(Duration.zero);
    }

    controller.unMute();
    controller.play();

    final completer = Completer<void>();
    int attempts = 0;

    Timer.periodic(retryInterval, (timer) async {
      if (controller.value.isPlaying) {
        timer.cancel();
        if (kDebugMode) {
          debugPrint(
              "✅ Video started successfully${debugContext != null ? ' ($debugContext)' : ''}");
        }

        // Лог успеха в аналитике
        if (videoId != null && sessionId != null) {
          await AnalyticsService.logVideoResumedAfterAd(0, sessionId);
        }

        completer.complete();
        return;
      }

      if (attempts >= maxAttempts) {
        timer.cancel();
        if (kDebugMode) {
          debugPrint(
              "❌ Video failed after $maxAttempts retries${debugContext != null ? ' ($debugContext)' : ''}");
        }

        // Лог неудачи в аналитике
        await AnalyticsService.logVideoResumeFailed(
            0, "Failed after $maxAttempts retries");

        completer
            .completeError("Failed to start video after $maxAttempts attempts");
        return;
      }

      if (kDebugMode) {
        debugPrint(
            "🔁 Video retry #${attempts + 1}${debugContext != null ? ' ($debugContext)' : ''}");
      }

      controller.unMute();
      controller.play();
      attempts++;
    });

    return completer.future;
  }
}
