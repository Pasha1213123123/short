import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Shorts Demo',
      theme: ThemeData.dark(),
      home: const ShortsViewer(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ShortModel {
  final String id;
  final String youtubeUrl;

  ShortModel({
    required this.id,
    required this.youtubeUrl,
  });
}

class ShortsViewer extends HookConsumerWidget {
  const ShortsViewer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pageController = usePageController();

    final shorts = [
      ShortModel(
          id: '1', youtubeUrl: 'https://www.youtube.com/shorts/M2ca8XUSy-E'),
      ShortModel(
          id: '2', youtubeUrl: 'https://www.youtube.com/shorts/052o6oWuHYQ'),
      ShortModel(
          id: '3', youtubeUrl: 'https://www.youtube.com/shorts/CotKFP4R_jY'),
      ShortModel(
          id: '4', youtubeUrl: 'https://www.youtube.com/shorts/euibKb3WUqo'),
      ShortModel(
          id: '5', youtubeUrl: 'https://www.youtube.com/shorts/P5dpiwGBo-s'),
      ShortModel(
          id: '6', youtubeUrl: 'https://www.youtube.com/shorts/bumNXv4pOro'),
    ];

    const int totalCards = 30;

    void onPageChanged(int page) {
      if (page % 3 == 0 && page != 0) {
        _showInterstitialAd();
      }
    }

    return Scaffold(
      body: PageView.builder(
        controller: pageController,
        scrollDirection: Axis.vertical,
        itemCount: totalCards,
        onPageChanged: onPageChanged,
        itemBuilder: (context, index) {
          final short = shorts[index % shorts.length];

          final controller = YoutubePlayerController(
            initialVideoId: YoutubePlayer.convertUrlToId(short.youtubeUrl)!,
            flags: const YoutubePlayerFlags(
              autoPlay: true,
              mute: false,
            ),
          );

          return YoutubePlayerBuilder(
            player: YoutubePlayer(controller: controller),
            builder: (context, player) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  player,
                  Positioned(
                    bottom: 50,
                    left: 20,
                    child: Text(
                      'Шортс ${index + 1}',
                      style: const TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                        shadows: [Shadow(blurRadius: 10)],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _showInterstitialAd() {
    InterstitialAd.load(
      adUnitId: 'ca-app-pub-3940256099942544/1033173712',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.show();
        },
        onAdFailedToLoad: (error) {
          debugPrint('Interstitial failed to load: $error');
        },
      ),
    );
  }
}
