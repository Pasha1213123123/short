---
name: ads-short-main
overview: "Интегрировать interstitial реклама в `short-main` по логике из `shortsee`: два независимых триггера (Nswipe=5, Nfinish=3) и fallback между AdMob и AppLovin."
todos:
  - id: pubspec-ads-deps
    content: "В `pubspec.yaml` добавить зависимости `google_mobile_ads` и `applovin_max` (версионность согласовать с `shortsee`: `google_mobile_ads:^5.1.0`, `applovin_max:^2.6.0`)."
    status: pending
  - id: platform-ad-keys
    content: "Настроить ключи на платформах: `android/app/src/main/AndroidManifest.xml` (meta-data `applovin.sdk.key`), и проверить `ios/Runner/Info.plist` для AppLovin/AdMob ключей. Ad unit IDs хранить в `.env`."
    status: pending
  - id: ads-manager-service
    content: "Добавить `lib/services/ads_manager.dart`: единый `AdsManager` с `initialize()` и `Future<bool> showInterstitialAd()` с fallback (AdMob->AppLovin), preload/ready state и lock `isAdShowing`. Показывать и дождаться закрытия."
    status: pending
  - id: init-in-main
    content: В `lib/main.dart` вызвать `MobileAds.instance.initialize()` и `AdsManager().initialize()` перед `runApp` (guard по `kIsWeb`).
    status: pending
  - id: integrate-triggers
    content: В `lib/screens/shorts_page_view.dart` добавить счетчики и флаги (`_swipeCounter`, `_finishCounter`, `_isAdShowing`, `_suppressNextPageAsSwipe`), обновить `_onPageChanged` для триггера A (Nswipe=5) и `onVideoFinished` для триггера B (Nfinish=3).
    status: pending
  - id: pause-resume
    content: "Во время показа interstitial: паузить текущее видео через `currentVideoControllerProvider`, после закрытия — возобновлять по `autoplayProvider`."
    status: pending
  - id: analytics-logging
    content: "Добавить события аналитики (опционально, но желательно): попытка показа/успех/какой SDK. (Например, через существующий FirebaseAnalytics в `ShortsPageView`)."
    status: pending
  - id: test-plan
    content: "Проверить поведение: быстрые свайпы, фильтры (изменение длины `filteredVideos`), завершение видео и программная навигация; убедиться что счетчики не дублируют показы."
    status: pending
isProject: false
---

## Цель

Добавить полноэкранные `interstitial` показы в ленту `short-main` аналогично `shortsee`, с разными триггерами:

- `A` (Nswipe=5): показывать после каждых 5 свайпов/смен страниц
- `B` (Nfinish=3): показывать после окончания каждых 3 видео
- оба триггера независимы (`bothSeparate`)
- приоритет показа: `AdMob` первым, если он не готов — `AppLovin MAX` (`admobPrimary`)

Лента при показе рекламы должна корректно приостанавливать проигрывание текущего видео и не ломать навигацию (PageView).

```mermaid
flowchart TD
  PageView[ShortsPageView/PageView.builder] -->|onPageChanged| SwipeCounter[Swipe counter]
  ShortPlayer[ShortPlayerScreen/onVideoFinished] -->|finish callback| FinishCounter[Finish counter]
  SwipeCounter --> AdLogic[Ad decision logic]
  FinishCounter --> AdLogic
  AdLogic --> AdsManager[AdsManager: init + show interstitial (AdMob first, fallback AppLovin)]
  AdsManager --> Pause[Pause current VideoPlayerController]
  Pause --> Show[Show interstitial]
  Show --> Resume[Resume playback after close]
```



## Детали интеграции по коду

### 1) Точки, которые нужно изменить в `short-main`

- `lib/screens/shorts_page_view.dart`
  - добавить счетчики/флаги в `_ShortsPageViewState` и изменить `_onPageChanged(int newIndex)`
  - изменить колбэк `onVideoFinished` внутри `ShortPlayerScreen(...)` (сейчас он сразу делает `nextPage`)
  - область, где сегодня происходит свайв-логика и PageView:

```dart
// lib/screens/shorts_page_view.dart
void _onPageChanged(int newIndex) {
  final videos = ref.read(filteredVideosProvider);
  ...
  setState(() => _currentIndex = newIndex);
  ref.read(videoCacheManagerProvider).preload(newIndex, videos);
  ...
}

// itemBuilder
ShortPlayerScreen(
  ...
  onVideoFinished: () {
    if (index < filteredVideos.length - 1) {
      _pageController.nextPage(...);
    }
  },
)
```

- `lib/main.dart`
  - добавить инициализацию ad SDK перед `runApp(...)`
- `lib/providers.dart`
  - использовать существующий `currentVideoControllerProvider` для паузы/возобновления видео во время interstitial

Существующий механизм паузы/включения аудио/видео не добавляется поверх `ShortPlayerScreen` (чтобы минимизировать правки): вместо этого планируетcя пауза через контроллер, который уже прокидывается в `currentVideoControllerProvider`.

### 2) Сервис рекламы (аналог `shortsee/lib/ads_manager.dart`)

Создать новый сервис, например:

- `lib/services/ads_manager.dart`

Задачи сервиса:

- `initialize()`:
  - `MobileAds.instance.initialize()` (AdMob)
  - `AppLovinMAX.initialize(...)` (AppLovin)
- `showInterstitialAd()`:
  - вернуть `Future<bool>`: показано/не показано
  - стратегия `admobPrimary`:
    - если AdMob interstitial готов — показать его и дождаться закрытия
    - иначе попытаться показать AppLovin
  - внутри учитывать lock `isAdShowing`, чтобы не запускать параллельно

Параллельно нужен preload/ready-механизм для обоих SDK.

### 3) Триггеры и логика счетчиков

Добавить поля в `_ShortsPageViewState`:

- `int _swipeCounter = 0;`
- `int _finishCounter = 0;`
- `bool _isAdShowing = false;`
- `bool _suppressNextPageAsSwipe = false;` (чтобы программный `nextPage()` не считался как свайв)

Правила:

- `A` (Nswipe=5):
  - в `_onPageChanged` увеличивать `_swipeCounter` только если не стоит `_suppressNextPageAsSwipe`
  - когда `_swipeCounter == 5`:
    - попытаться показать interstitial
    - если показ удался или даже если не удался — сбросить `_swipeCounter = 0` (лучше, чтобы частота не “разгонялась”)
- `B` (Nfinish=3):
  - в `onVideoFinished` увеличивать `_finishCounter`
  - если `_finishCounter == 3`:
    - сначала показать interstitial
    - после закрытия выполнить `nextPage`
    - сбросить `_finishCounter = 0`
  - если interstitial не показали (не готово) — всё равно делать `nextPage`, но счетчик сбросить (чтобы оставаться в ожидаемой частоте)

Важно про конфликт A и B:

- `bothSeparate` означает: каждый триггер независимо накапливает события и может сработать в разное время
- но программный `nextPage` может вызвать `onPageChanged` — поэтому нужен `_suppressNextPageAsSwipe`

### 4) Пауза/возобновление видео во время рекламы

Перед `adsManager.showInterstitialAd()`:

- прочитать текущий контроллер: `final controller = ref.read(currentVideoControllerProvider);`
- если `controller != null` и он playing — `controller.pause()`

После закрытия interstitial:

- если `autoplayProvider == true` и текущая страница всё еще активна — `controller.play()`
- если autoplay выключен — оставлять паузу

### 5) Настройки/ключи

Ориентир на `shortsee`:

- `AndroidManifest.xml` содержит `com.google.android.gms.ads.APPLICATION_ID`
- и `applovin.sdk.key` meta-data

В `short-main`:

- AdMob app id уже есть (manifest meta-data через `ADMOB_APP_ID_ANDROID`)
- нужно добавить `applovin.sdk.key` (как минимум на Android)
- Ad unit ids (interstitial) лучше держать в `.env`, чтобы не хардкодить в код

## Файлы, которые будут затронуты

1. `lib/main.dart` — инициализация рекламных SDK перед `runApp`
2. `lib/screens/shorts_page_view.dart` — счетчики A/B и вызов `showInterstitialAd()`
3. `lib/services/ads_manager.dart` (новый) — единый менеджер рекламы: init + show + fallback
4. `lib/providers.dart` — (минимально) использовать текущий `currentVideoControllerProvider`
5. `pubspec.yaml` — добавить зависимости `google_mobile_ads` и `applovin_max`
6. `android/app/src/main/AndroidManifest.xml` — добавить meta-data `applovin.sdk.key` (при необходимости)
7. `ios/Runner/Info.plist` — проверить, нужен ли AppLovin ключ на iOS

## Риски/edge-cases

- `onVideoFinished` делает `nextPage`, что может триггерить `_onPageChanged` и ломать счетчик свайпов — решается `_suppressNextPageAsSwipe`.
- Видео может продолжать играть во время interstitial — решается паузой через `currentVideoControllerProvider`.
- Одновременные события (например, быстрые свайпы) — решается `isAdShowing` lock в `AdsManager`.

## Что считается готовым

- Interstitial появляется корректно с частотой `Nswipe=5` и `Nfinish=3`.
- В логах/аналитике видно, какой SDK был показан (AdMob первично, fallback AppLovin).
- При показе рекламы видео ставится на паузу и продолжает по закрытию (если autoplay включен).

