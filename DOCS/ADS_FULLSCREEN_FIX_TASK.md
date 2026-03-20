# 📱 Завдання: Повноекранна реклама (Immersive Mode Fix)

## 📌 Опис проблеми
При показі Interstitial реклами (AdMob / AppLovin) вона не розтягується на весь екран. Верхня частина екрана (статус-бар, зона навколо вирізу/чілки камери) залишається відкритою, і крізь неї видно інтерфейс нашого додатку. Реклама виглядає "обрізаною" зверху, що порушує ефект повноекранного перекриття.

## 🛠 План вирішення (Roadmap)

Проблема пов'язана з керуванням системним UI (System UI) у Flutter. Щоб реклама дійсно перекривала весь екран (включаючи зону "чілки"), нам потрібно приховувати статус-бар перед показом реклами і повертати його після її закриття.

### 1. Налаштування SystemChrome
Ми будемо використовувати `SystemChrome.setEnabledSystemUIMode` з пакету `flutter/services.dart` для тимчасового переходу в режим `immersiveSticky`.

### 2. Модифікація логіки показу реклами в `ShortsPageView`
У методі `_tryToShowAd()` потрібно додати логіку керування системним UI:

1. **Перед показом реклами:**
   ```dart
   // Приховуємо верхню та нижню панелі системи
   SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
   ```

2. **Після закриття реклами:**
   ```dart
   // Повертаємо стандартний вигляд (Edge to Edge)
   SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
   ```

### 3. Перевірка Android-маніфесту (опціонально)
Якщо програмного приховування через Flutter буде недостатньо, потрібно буде переконатися, що тема Activity в `android/app/src/main/res/values/styles.xml` підтримує правильний атрибут `windowLayoutInDisplayCutoutMode` (але зазвичай `SystemChrome` вирішує 90% таких проблем).

---

## 🤖 Промпт для ШІ (Next Step)

Коли ви будете готові до реалізації, скопіюйте і відправте мені цей текст:

> **Промпт для реалізації:**
> "Привіт! Давай реалізуємо завдання з файлу `DOCS/ADS_FULLSCREEN_FIX_TASK.md`. 
> Відкрий `lib/screens/shorts_page_view.dart` та онови метод `_tryToShowAd()`. 
> Перед викликом `adManager.showInterstitialAd()` додай `SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);`, щоб сховати статус-бар і зону камери. 
> Після того, як реклама закриється і `showInterstitialAd` поверне результат, додай `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);` для відновлення нормального інтерфейсу (або `manual` з `[SystemUiOverlay.top, SystemUiOverlay.bottom]`).
> Зроби це, будь ласка."
