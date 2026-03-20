# 🛠 Detailed Implementation Plan: Ads Integration

Цей документ містить технічні деталі реалізації інтеграції реклами (AdMob + AppLovin) у проект `short-main`.

## 1. Етап 1: Конфігурація та Залежності
*   **pubspec.yaml:** Використовуємо стабільні версії, що підтримують останні зміни в Android SDK 34/35.
*   **Environment:** Всі ID рекламних блоків виносимо в `.env`. Це дозволяє змінювати рекламу без перезбірки коду (якщо використовувати Firebase Remote Config у майбутньому).

## 2. Етап 2: Сервіс `AdsManager` (Singleton + Fallback)
Файл: `lib/services/ads_manager.dart`

### Ключові механізми:
1.  **Singleton Pattern:** Доступ через `AdsManager.instance`.
2.  **State Management:** 
    *   `bool _isAdMobLoading = false;`
    *   `bool _isAppLovinLoading = false;`
    *   `InterstitialAd? _adMobInterstitialAd;`
    *   `bool _isAppLovinReady = false;`
3.  **Логіка завантаження (Preload):**
    *   Завантаження AdMob починається відразу після `initialize()`.
    *   Якщо AdMob не вдалося завантажити, запускається завантаження AppLovin.
    *   Після кожного показу (onDismissed) — автоматичне перезавантаження.
4.  **Показ з Fallback:**
    *   Метод `showInterstitialAd()` повертає `Future<bool>`.
    *   Якщо AdMob ready -> показуємо AdMob.
    *   Інакше, якщо AppLovin ready -> показуємо AppLovin.
    *   Якщо нічого не готово -> повертаємо `false` (користувач продовжує дивитися відео).

## 3. Етап 3: Інтеграція в `ShortsPageView`
Файл: `lib/screens/shorts_page_view.dart`

### Робота з лічильниками:
*   `int _swipeCounter = 0;` — збільшується в `onPageChanged`, якщо `newIndex > oldIndex` (тільки свайп вперед).
*   `int _finishCounter = 0;` — збільшується в `onVideoFinished`.

### Сценарій показу реклами:
1.  **Пауза:** Виклик `ref.read(currentVideoControllerProvider)?.pause()`.
2.  **Показ:** `bool adShown = await AdsManager.instance.showInterstitialAd();`.
3.  **Обробка результату:**
    *   Якщо реклама була показана, чекаємо її закриття.
    *   Скидаємо відповідний лічильник (`_swipeCounter = 0` або `_finishCounter = 0`).
4.  **Відновлення:** 
    *   Якщо тригер був `Finish`, викликаємо `_pageController.nextPage()`.
    *   Викликаємо `play()` для нового відео (якщо `autoplay` увімкнено).

## 4. Етап 4: Крос-платформенна специфіка
### Android (`AndroidManifest.xml`):
*   Додати `<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" ... />`
*   Додати `<meta-data android:name="applovin.sdk.key" ... />`
*   Додати дозволи на використання рекламного ID (AD_ID).

### iOS (`Info.plist`):
*   Додати `GADApplicationIdentifier`.
*   Додати `AppLovinSdkKey`.
*   Додати `SKAdNetworkItems` (список ID рекламних мереж для дозволу Tracking).

## 5. Етап 5: Аналітика (Best Practices)
Замість простого `print`, використовуємо існуючий `FirebaseAnalytics`:
*   `logEvent(name: 'interstitial_attempt')`
*   `logEvent(name: 'interstitial_success', parameters: {'provider': 'admob'})`
*   `logEvent(name: 'interstitial_fail', parameters: {'error': 'no_fill'})`

---
**Останнє оновлення:** 20 березня 2026 р.
