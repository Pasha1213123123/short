# 🔘 Объединение кнопок Like, Share, Favorite в один floating button

Отдельная задача по замене отдельных кнопок «Нравится», «Поделиться» и «Сохранить» (избранное) одной плавающей кнопкой с раскрывающимся меню.

---

## Задача

**FAB-001**: Функционал объединения кнопок Like, Share, Favorite в один floating button

- **Описание:** Вместо трёх отдельных кнопок справа от видео (Like, Save/Bookmark, Share) сделать одну плавающую кнопку (FAB), по нажатию раскрывающую варианты: «Нравится», «Поделиться», «В избранное» (сохранить).
- **Цель:** Упростить боковую панель, освободить место на экране, сохранить все действия в одном месте.
- **Приоритет:** Улучшение (UX).

### Текущее состояние

- В `lib/screens/short_player_screen.dart` правая панель `_buildRightSideBar()` выводит три отдельные кнопки:
  - `_buildLikeButton(loc)` — лайк, провайдер `likedVideosProvider`;
  - `_buildBookmarkButton(loc)` — сохранить в избранное, провайдер `bookmarkedVideosProvider`;
  - `_buildShareButton(loc)` — поделиться (копирование ссылки в буфер).
- Локализация: `like`, `share`, `save` в `lib/l10n/`.

### Требования

- Одна плавающая кнопка (Floating Action Button или кастомный виджет в том же месте справа).
- По тапу по основной кнопке — раскрытие меню с тремя действиями: Like, Share, Favorite (Save).
- Сохранить текущую логику: переключение лайка/избранного, копирование ссылки при Share, аналитика (Firebase), haptic feedback.
- Состояния «лайкнуто» / «в избранном» по возможности отображать в меню (иконки/подсветка), не теряя функциональность.
- Доступность: семантика и подписи для скринридеров (как сейчас через `Semantics`).

### Реализация (подсказки)

**Варианты UI**

1. **Speed dial (FAB с дочерними FAB)**  
   Одна главная FAB, по нажатию над ней появляются 3 маленькие FAB с иконками Like, Bookmark, Share. Повторное нажатие или тап вне — сворачивание.

2. **FAB + PopupMenu / BottomSheet**  
   Одна FAB, по нажатию открывается `PopupMenuButton` или `showModalBottomSheet` с тремя пунктами: Like, Save, Share. В пунктах можно показывать иконку и состояние (лайкнуто/в избранном).

3. **Кастомный виджет**  
   В текущей позиции правой колонки один круглый/квадратный виджет; по тапу — анимация раскрытия трёх кнопок вниз или вверх (аналогично Speed dial).

**Место в коде**

- Файл: `lib/screens/short_player_screen.dart`.
- Заменить `_buildRightSideBar()` так, чтобы вместо трёх виджетов `_buildLikeButton`, `_buildBookmarkButton`, `_buildShareButton` рендерился один виджет «объединённая FAB» (Speed dial или FAB + меню).
- Логику из `_buildLikeButton`, `_buildBookmarkButton`, `_buildShareButton` перенести в обработчики пунктов меню / дочерних FAB (вызовы тех же провайдеров и `FirebaseAnalytics.instance.logEvent`).

**Пакеты (по желанию)**

- Можно обойтись виджетами из Material: `FloatingActionButton`, `PopupMenuButton`, `showModalBottomSheet`.
- Либо использовать пакет вроде `flutter_speed_dial` для готового Speed dial.

### Связанные файлы

- `lib/screens/short_player_screen.dart` — правая панель, кнопки Like/Bookmark/Share.
- `lib/providers.dart` — `likedVideosProvider`, `bookmarkedVideosProvider`.
- `lib/l10n/` — строки `like`, `share`, `save`.

### Статус

- [ ] Не выполнено

---

**Последнее обновление:** 2026
