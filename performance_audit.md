# Performance & Bottlenecks Audit — Ducat (my_money_flutter)

## Executive Summary

The app has a solid architectural foundation (offline-first, isolate-offloaded analytics, RepaintBoundary isolation on the background canvas), but carries several significant bottlenecks that will degrade real-world performance — especially as the transaction list grows. Issues range from **O(n²) list searches**, **full-state `notifyListeners()` blasts**, **SharedPreferences misuse for large data**, and a **60fps animated custom painter running unconditionally** on every screen.

---

## 🔴 Critical Issues

### 1. `SharedPreferences` used as primary database — catastrophic at scale
**File:** [`local_store.dart`](file:///c:/Users/manthan/Desktop/proj/my_money_flutter/lib/services/local_store.dart)

SharedPreferences serialises **all** transactions as a single JSON blob into a single string key. With 2,000 transactions (the Firestore limit you pull), this is a ~1–2 MB JSON string being:
- Fully re-encoded and re-written on **every single mutation** (`addTransaction`, `deleteTransaction`, `updateTransaction`, `updateAccountsOrder`, etc.)
- Fully decoded on every cold start

```dart
// Every CRUD op triggers this — O(n) JSON encode of all transactions:
await _saveAllToLocal();  // encodes ALL accounts + ALL txns + ALL categories
```

**Impact:** Noticeable jank (100–500ms freezes) on add/delete with large datasets. The `compute()` offloading partially mitigates it for transactions, but accounts and categories are still encoded **on the main thread**.

> [!CAUTION]
> **Fix:** Migrate to `sqflite` or `isar` for individual record writes. At minimum, avoid re-saving the entire accounts/categories list on every transaction CRUD; use dirty-flagging or separate keys per entity ID.

---

### 2. Monolithic `notifyListeners()` — whole UI rebuilds on every mutation
**File:** [`app_provider.dart`](file:///c:/Users/manthan/Desktop/proj/my_money_flutter/lib/providers/app_provider.dart)

`AppProvider` is a single `ChangeNotifier`. Every `notifyListeners()` call — including `setCurrentDate()`, currency changes, sync status updates — rebuilds every widget that calls `Provider.of<AppProvider>(context)`.

**Worst offender:**
```dart
// accounts_screen.dart line 110 — rebuilds the ENTIRE screen on ANY provider change:
final provider = Provider.of<AppProvider>(context);
```

**Profile screen** (line 71) does the same.

> [!WARNING]
> **Fix:** Replace `Provider.of<AppProvider>(context)` with fine-grained `context.select(...)` (already done correctly in `dashboard_screen.dart` and `analytics_screen.dart`). Accounts screen and profile screen need this treatment urgently.

---

### 3. O(n) linear scans in hot paths — `firstWhere` in `ListView.builder`
**File:** [`dashboard_screen.dart`](file:///c:/Users/manthan/Desktop/proj/my_money_flutter/lib/ui/screens/dashboard_screen.dart#L180-L186) and [`analytics_screen.dart`](file:///c:/Users/manthan/Desktop/proj/my_money_flutter/lib/ui/screens/analytics_screen.dart#L262-L265)

```dart
// dashboard_screen.dart — called for EVERY item in the list during build:
final cat = categories.firstWhere(
  (c) => c.id == item.categoryId,
  orElse: () => CategoryModel(id: '', name: '', icon: '', type: ''),
);

// analytics_screen.dart — inside dialog ListView builder:
acc = provider.accounts.firstWhere((a) => a.id == t.accountId);
```

With 50 categories and 500 transactions, this is **25,000 iterations per build frame** during scrolling.

> [!CAUTION]
> **Fix:** Pre-build `Map<String, CategoryModel>` and `Map<String, Account>` lookup maps once (in provider or at top of `build()`), then do `O(1)` map lookups in the item builder. The isolate already does this correctly in `exportTransactionsCSV`.

---

### 4. Full transaction list re-serialised on `syncOnline` (push + pull)
**File:** [`app_provider.dart`](file:///c:/Users/manthan/Desktop/proj/my_money_flutter/lib/providers/app_provider.dart#L270-L294)

`syncOnline()` calls `_pushToFirestore()` followed by `_restoreFromCloud()`. The restore re-downloads **everything** from Firestore and overwrites local state. This means:
- A full round-trip even when data hasn't changed
- `_saveAllToLocal()` re-encodes and re-persists the entire dataset

There is no delta/diff sync; it's always a full overwrite.

---

## 🟠 High-Priority Issues

### 5. `AppBackground` ticker runs at 60fps on every screen unconditionally
**File:** [`app_background.dart`](file:///c:/Users/manthan/Desktop/proj/my_money_flutter/lib/ui/components/app_background.dart#L99-L142)

The `nightSky` ticker fires every frame (~16ms) even when the screen is still and no touches are active. The stop condition exists (`_ticker?.stop()`) but only triggers when `_touches.isEmpty && !isStillAnimating` — `nightSky` mode sets `isStillAnimating = true` unconditionally (line 113), so the ticker **never stops**.

```dart
bool isStillAnimating = widget.patternMode != PixelPatternMode.interactiveOnly;
// nightSky is not interactiveOnly → always true → ticker never sleeps
```

This also means `_repaint.value++` fires every frame, triggering a `ValueListenableBuilder` rebuild + `CustomPaint` repaint of the entire pixel grid on every screen in the app.

> [!WARNING]
> **Fix:** For `nightSky`, only repaint when `_elapsedSeconds` has advanced enough to visually change any star brightness (e.g., throttle to 30fps for ambient animation, only bump to 60fps when touches are active).

---

### 6. `_PixelGridPainter` uses `Map<int, double> litPixels` — heap allocation every frame
**File:** [`app_background.dart`](file:///c:/Users/manthan/Desktop/proj/my_money_flutter/lib/ui/components/app_background.dart#L571)

Every `paint()` call allocates a new `Map<int, double>` and populates it with hundreds of entries. On a 400×800 dp screen at `step = 10dp`, this is ~3200 grid cells, with stars and touch points allocating map entries every frame.

> [!TIP]
> **Fix:** Replace `Map<int, double> litPixels` with a pre-allocated `Float32List` of size `cols * rows`, zeroed at the start of each `paint()` call. `memset`-like zeroing of a typed list is far cheaper than GC-ing a Map.

---

### 7. `_computeAnalyticsIsolate` spawned via `compute()` — no result caching, spawned on every `setState`
**File:** [`analytics_screen.dart`](file:///c:/Users/manthan/Desktop/proj/my_money_flutter/lib/ui/screens/analytics_screen.dart#L84-L130)

The identity-based cache check (`_cachedTransactions == transactions`) is correct, but:
- `compute()` spawns a **new isolate** (via `Isolate.spawn`) on every call — even cheap period changes trigger full isolate overhead
- Toggling `_avgPeriod` (tap on 1M/6M/1Y/All) fires a fresh isolate even though only the avg computation subset needs to change

> [!TIP]
> **Fix:** Use a persistent `Isolate` with `ReceivePort`/`SendPort` for the analytics worker, or split the compute into two cheaper functions: a heavy one (trend graph, chart data) only when transactions/date change, and a light one (averages) when only `_avgPeriod` changes.

---

### 8. `_groupedTransactionsCache` in Dashboard — wrong cache invalidation
**File:** [`dashboard_screen.dart`](file:///c:/Users/manthan/Desktop/proj/my_money_flutter/lib/ui/screens/dashboard_screen.dart#L163-L171)

```dart
if (_cachedTransactions == allTransactions && _cachedSearchQuery == searchQuery) {
  // Use cache
} else {
  _groupedTransactionsCache.clear();  // <-- Clears ALL 49 months on any change
```

Any transaction CRUD (which creates a new `List` in provider) clears the entire 49-month cache. All `PageView` pages re-compute on next render.

> [!TIP]
> **Fix:** Cache at the individual transaction level. Store a content hash or the list length+last-modified timestamp. Only invalidate affected month pages, not all of them.

---

### 9. `importTransactionsCSV` — O(n×m) account/category lookups in inner loop
**File:** [`app_provider.dart`](file:///c:/Users/manthan/Desktop/proj/my_money_flutter/lib/providers/app_provider.dart#L843-L907)

```dart
for (final a in accounts) {
  if (a.name.toLowerCase() == accountName.toLowerCase()) { ... }
}
// and separately:
for (final c in categories) {
  if (c.name.toLowerCase() == categoryName.toLowerCase()) { ... }
}
```

This runs inside the CSV row loop. With 2000 rows, 20 accounts, 30 categories → 100,000 string comparisons.

> [!TIP]
> **Fix:** Build `Map<String, Account>` and `Map<String, CategoryModel>` keyed by lowercased name before entering the loop.

---

### 10. Profile photo stored as base64 in Firestore document
**File:** [`app_provider.dart`](file:///c:/Users/manthan/Desktop/proj/my_money_flutter/lib/providers/app_provider.dart#L1080-L1106)

Storing base64-encoded images in Firestore documents:
- Inflates document size by ~33% vs raw bytes
- Firestore has a 1 MB document limit — a 512×512 JPEG can easily be 50–150 KB → ~200KB base64
- Slows down every read of the `users` document

> [!WARNING]
> **Fix:** Use Firebase Storage for binary files. Store only the download URL in Firestore.

---

## 🟡 Medium-Priority Issues

### 11. `SharedPreferences.getInstance()` called on every read/write
**File:** [`local_store.dart`](file:///c:/Users/manthan/Desktop/proj/my_money_flutter/lib/services/local_store.dart) and [`app_provider.dart`](file:///c:/Users/manthan/Desktop/proj/my_money_flutter/lib/providers/app_provider.dart)

`SharedPreferences.getInstance()` is awaited 10+ times across the codebase — in `_loadCurrency`, `_loadOnboardingStatus`, `completeOnboarding`, `updateCurrency`, `_restoreFromCloud`, `_restorePhotoFromFirestore`, `pickProfilePhoto`, `updateUserName`, and all `LocalStore` methods. Each call is an async platform channel round-trip.

> [!TIP]
> **Fix:** Cache the `SharedPreferences` instance once as a static field after `getInstance()`, or pass it through the call chain.

---

### 12. `BackdropFilter` on every account item in `AccountsScreen`
**File:** [`accounts_screen.dart`](file:///c:/Users/manthan/Desktop/proj/my_money_flutter/lib/ui/screens/accounts_screen.dart#L362)

```dart
BackdropFilter(
  filter: ImageFilter.blur(sigmaX: 12.0, sigmaY: 12.0),
  ...
)
```

Every account card applies a `BackdropFilter` blur. `BackdropFilter` triggers an offscreen render pass — rendering N cards creates N offscreen buffers. With 5+ accounts this is measurably expensive, especially on top of the animated pixel background.

> [!TIP]
> **Fix:** Replace per-card `BackdropFilter` with a semi-opaque solid `Color(0xFF121212).withAlpha(...)` container, which is essentially free to render and matches the visual result on a dark background.

---

### 13. `ConcentricRingsPainter` creates new `Paint` objects every `paint()` call
**File:** [`charts.dart`](file:///c:/Users/manthan/Desktop/proj/my_money_flutter/lib/ui/components/charts.dart#L36-L55)

```dart
// Called every frame during animation:
final Paint bgPaint = Paint()..color = ...;  // new allocation
final Paint glowPaint = Paint()..maskFilter = ...;  // new allocation
final Paint solidPaint = Paint()..color = ...;  // new allocation
```

Three `Paint` instances per ring, allocated every repaint. With 8 rings that's 24 `Paint` allocations per frame during chart animation.

> [!TIP]
> **Fix:** Cache `Paint` objects as instance fields in the painter, update their properties only when `shouldRepaint` returns true.

---

### 14. Conflict: `persistenceEnabled: true` in `main.dart` vs `false` in `AppProvider._init()`
**File:** [`main.dart`](file:///c:/Users/manthan/Desktop/proj/my_money_flutter/lib/main.dart#L15-L17) and [`app_provider.dart`](file:///c:/Users/manthan/Desktop/proj/my_money_flutter/lib/providers/app_provider.dart#L49)

```dart
// main.dart:
FirebaseFirestore.instance.settings = const Settings(persistenceEnabled: true);

// app_provider.dart _init():
_db.settings = const Settings(persistenceEnabled: false);
```

`main.dart` enables Firestore disk cache, then `AppProvider` disables it. The second call wins — but this is confusing, and if Firestore initialises before `AppProvider._init()` runs, there may be a window where cached data is served. At minimum this is dead code in `main.dart`.

> [!WARNING]
> **Fix:** Remove the conflicting `Settings` from `main.dart`. Keep only the single authoritative setting in `AppProvider._init()`.

---

### 15. `google_fonts` used extensively without preloading
**File:** Multiple screens — `analytics_screen.dart`, `accounts_screen.dart`, `dashboard_screen.dart`, etc.

`GoogleFonts.fraunces(...)` triggers network font downloads on first use unless bundled. This causes **invisible text** or layout shifts on first launch without internet.

> [!TIP]
> **Fix:** Either declare the font in `pubspec.yaml` under `fonts:` (bundling it at build time), or call `GoogleFonts.pendingFonts([GoogleFonts.frauncesTextTheme()])` at app startup to preload.

---

### 16. `video_player` dependency is imported but no video UI was found
**File:** [`pubspec.yaml`](file:///c:/Users/manthan/Desktop/proj/my_money_flutter/pubspec.yaml#L43)

`video_player: ^2.11.1` adds ~2–4 MB to the final APK. If it's only used in the onboarding screen and nowhere else, consider lazy-loading or removing it if the onboarding no longer uses video.

---

## 📊 Summary Table

| # | Issue | Severity | File | Effort to Fix |
|---|-------|----------|------|---------------|
| 1 | SharedPreferences as DB | 🔴 Critical | `local_store.dart` | High |
| 2 | Monolithic `notifyListeners` | 🔴 Critical | `accounts_screen.dart`, `profile_screen.dart` | Low |
| 3 | O(n) `firstWhere` in list builders | 🔴 Critical | `dashboard_screen.dart`, `analytics_screen.dart` | Low |
| 4 | Full Firestore push+pull on sync | 🔴 Critical | `app_provider.dart` | Medium |
| 5 | Background ticker never sleeps | 🟠 High | `app_background.dart` | Low |
| 6 | Map allocation in painter hot path | 🟠 High | `app_background.dart` | Medium |
| 7 | compute() isolate on every toggle | 🟠 High | `analytics_screen.dart` | Medium |
| 8 | Dashboard cache invalidated on every change | 🟠 High | `dashboard_screen.dart` | Low |
| 9 | O(n×m) lookups in CSV import loop | 🟠 High | `app_provider.dart` | Low |
| 10 | Profile photo as base64 in Firestore | 🟠 High | `app_provider.dart` | Medium |
| 11 | `SharedPreferences.getInstance()` repeated | 🟡 Medium | `local_store.dart`, `app_provider.dart` | Low |
| 12 | `BackdropFilter` on every account card | 🟡 Medium | `accounts_screen.dart` | Low |
| 13 | `Paint` objects created per `paint()` | 🟡 Medium | `charts.dart` | Low |
| 14 | Conflicting Firestore persistence settings | 🟡 Medium | `main.dart` vs `app_provider.dart` | Trivial |
| 15 | Google Fonts not bundled/preloaded | 🟡 Medium | `pubspec.yaml` | Low |
| 16 | Unused `video_player` dependency | 🟡 Medium | `pubspec.yaml` | Trivial |

---

## ✅ What's Already Done Well

- **Isolate offloading** for analytics computation (`compute()` in `analytics_screen.dart`) ✅
- **Isolate offloading** for transaction serialization/deserialization (`compute()` in `local_store.dart`) ✅
- **CSV parsing** in background isolate (`compute(_parseCsvInBackground, ...)`) ✅
- **RepaintBoundary** correctly used to isolate background painter from foreground UI ✅
- **Firestore batch writes** with 450-op chunking to avoid batch limits ✅
- **Sync debouncing** (600ms) to batch rapid mutations into a single upload ✅
- **`context.select()`** used correctly in `dashboard_screen.dart` and `analytics_screen.dart` ✅
- **`_groupedTransactionsCache`** for memoising grouped transactions per month ✅
- **Connectivity listener** for automatic pending sync on network restore ✅
- **`Float32List` + `drawRawPoints`** for batch pixel rendering in the background painter ✅
- **Paint caching** (static bucket paints) in `_PixelGridPainter` ✅
