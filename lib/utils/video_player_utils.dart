// import 'dart:async';

// import 'package:flutter/foundation.dart';
// import 'package:youtube_player_flutter/youtube_player_flutter.dart';

// class VideoPlayerUtils {
//   static Future<void> playWithRetry({
//     required YoutubePlayerController controller,
//     int maxAttempts = 3,
//     Duration retryInterval = const Duration(milliseconds: 500),
//     Duration readyCheckInterval = const Duration(milliseconds: 100),
//     String? debugContext,
//     bool shouldSeekToZero = false,
//     bool Function()? shouldCancelRetry,
//   }) async {
//     final completer = Completer<void>();

//     while (!controller.value.isReady) {
//       if (shouldCancelRetry != null && shouldCancelRetry()) {
//         if (!completer.isCompleted) completer.complete();
//         return completer.future;
//       }
//       await Future.delayed(readyCheckInterval);
//     }

//     if (shouldSeekToZero) {
//       controller.seekTo(Duration.zero);
//     }

//     controller.unMute();
//     controller.play();

//     int attempts = 0;

//     Timer.periodic(retryInterval, (timer) {
//       if (shouldCancelRetry != null && shouldCancelRetry()) {
//         if (kDebugMode) {
//           debugPrint(
//               "Video Retry CANCELLED by external flag (e.g., Ad): $debugContext");
//         }
//         timer.cancel();
//         if (!completer.isCompleted) completer.complete();
//         return;
//       }

//       if (controller.value.isPlaying) {
//         timer.cancel();
//         if (!completer.isCompleted)
//           completer.complete(); // Успех! Завершаем Future
//         return;
//       }

//       if (attempts >= maxAttempts) {
//         timer.cancel();
//         if (kDebugMode) {
//           debugPrint(
//               "Video Failed after $maxAttempts retries${debugContext != null ? ' ($debugContext)' : ''}");
//         }
//         if (!completer.isCompleted)
//           completer.complete(); // Неудача. Завершаем Future
//         return;
//       }

//       if (kDebugMode) {
//         debugPrint(
//             "Video Retry${debugContext != null ? ' ($debugContext)' : ''}: $attempts");
//       }
//       controller.unMute();
//       controller.play();
//       attempts++;
//     });

//     return completer.future;
//   }
// }
