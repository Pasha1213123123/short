# Roadmap: Multi-Genre Filter (OR Logic)

## Objective
Implement a multi-selection genre filter in the `ShortsPageView` using OR logic. Selecting multiple genres will show videos that belong to at least one of the selected genres. Selecting "All" will clear all specific filters and show all videos.

## Phases

### Phase 1: Data Model & Providers (lib/providers.dart)
- [x] Replace `selectedGenreProvider` (String) with `selectedGenresProvider` (Set<String>).
- [x] Update `filteredVideosProvider` to implement OR logic.
- [x] Ensure `availableGenresProvider` remains compatible.

### Phase 2: UI Implementation (lib/screens/shorts_page_view.dart)
- [x] Update `ShortsPageView` state to use `selectedGenresProvider`.
- [x] Replace `ChoiceChip` with `FilterChip` (or toggleable `ChoiceChip`) in `GenreFilterChip`.
- [x] Implement "All" button logic (clears selection).
- [x] Implement toggle logic for individual genre chips.

### Phase 3: UX & Navigation (lib/screens/shorts_page_view.dart)
- [x] Implement automatic scroll-to-top (`jumpToPage(0)`) and index reset when filters change.
- [x] Ensure preloading logic works correctly with the new filtered list.

### Phase 4: Cleanup & Validation
- [x] Remove unused `selectedGenreProvider`.
- [x] Verify compilation and fix any warnings.
- [ ] (Optional) Audit `UploadScreen` for consistency.

---

# Technical Implementation Plan

## 1. Providers Transformation (`lib/providers.dart`)

### Current State
```dart
final selectedGenreProvider = StateProvider.autoDispose<String>((ref) => 'All');

final filteredVideosProvider = Provider.autoDispose<List<Movie>>((ref) {
  final allVideos = ref.watch(shortVideosProvider);
  final genre = ref.watch(selectedGenreProvider);

  if (genre == 'All') return allVideos;
  return allVideos.where((v) => v.genres.contains(genre)).toList();
});
```

### Proposed Change
```dart
// Use Set for efficient O(1) lookups and unique values
final selectedGenresProvider = StateProvider.autoDispose<Set<String>>((ref) => {});

final filteredVideosProvider = Provider.autoDispose<List<Movie>>((ref) {
  final allVideos = ref.watch(shortVideosProvider);
  final selectedGenres = ref.watch(selectedGenresProvider);

  // If no genres are selected, treat it as "All"
  if (selectedGenres.isEmpty) return allVideos;
  
  // OR Logic: show video if it has ANY of the selected genres
  return allVideos.where((movie) {
    return movie.genres.any((genre) => selectedGenres.contains(genre));
  }).toList();
});
```

## 2. UI & Interaction (`lib/screens/shorts_page_view.dart`)

### Filter Logic in `_buildTopBar`
- **"All" Chip**: 
  - `isSelected` if `selectedGenres.isEmpty`.
  - `onSelected` => `ref.read(selectedGenresProvider.notifier).state = {}`.
- **Genre Chips**:
  - `isSelected` if `selectedGenres.contains(genre)`.
  - `onSelected(true)` => Add genre to Set.
  - `onSelected(false)` => Remove genre from Set.

### Implementation Detail for `GenreFilterChip`
Convert it to use `FilterChip` for better semantic alignment with multi-selection.

```dart
class GenreFilterChip extends StatelessWidget {
  final String genre;
  final bool isSelected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(genre),
      selected: isSelected,
      onSelected: onSelected,
      // Optional styling to match ChoiceChip if needed
    );
  }
}
```

## 3. Index Reset & Auto-Scroll

To prevent the `PageView` from staying on a high index when the filtered list shrinks (causing a blank screen), we must listen to changes in `filteredVideosProvider`.

### Inside `_ShortsPageViewState`
```dart
@override
void initState() {
  super.initState();
  // ... existing code ...

  // Listen for filter changes
  ref.listenManual(filteredVideosProvider, (previous, next) {
    if (previous != next) {
      _currentIndex = 0;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
      // Re-trigger preloading for the new first video
      ref.read(videoCacheManagerProvider).preload(0, next);
    }
  });
}
```
*Note: Using `ref.listenManual` or `ref.listen` in `build` is preferred for state side-effects in Riverpod.*

## 4. Verification Steps
1. Open filter menu.
2. Select "Action". Verify only Action videos show.
3. Select "Comedy". Verify both Action AND Comedy videos show.
4. Select "All". Verify selection clears and all videos show.
5. While on 10th video of "All", select a genre that only has 2 videos. Verify the app jumps to the 1st video of that genre.
