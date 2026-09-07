import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';

import '../../core/theme.dart';
import '../base/base_screen.dart';
import '../components/transaction_item.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import 'profile_screen.dart';

class DashboardScreen extends BaseScreen {
  const DashboardScreen({super.key});

  @override
  BaseScreenState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends BaseScreenState<DashboardScreen> with SingleTickerProviderStateMixin {
  late AnimationController _searchAnimController;
  late Animation<double> _searchAnim;
  bool _isSearchActive = false;
  String _searchQuery = "";
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();

  late final PageController _pageController;
  final ScrollController _scrollController = ScrollController();
  final List<DateTime> _months = [];
  final int _initialIndex = 24;

  static const double itemWidth = 80.0;
  int _lastTapTime = 0;
  int _lastTapIndex = -1;
  bool _isSyncing = false;

  static final DateFormat _dayHeaderFormat = DateFormat('MMM d, EEEE');
  static final Map<int, String> _formattedDayCache = {};

  static String _formatDayHeader(DateTime d) {
    final key = d.year * 10000 + d.month * 100 + d.day;
    return _formattedDayCache.putIfAbsent(key, () => _dayHeaderFormat.format(d));
  }

  List<TransactionModel>? _cachedAllTransactionsRef;
  List<CategoryModel>? _cachedCategoriesRef;
  String _cachedSearchQuery = '';
  Map<String, CategoryModel> _cachedCategoryMap = const {};
  final Map<int, List<dynamic>> _monthGroupedCache = {};

  @override
  bool get hasOwnBackground => false;

  @override
  bool get useSafeArea => true;

  @override
  void initState() {
    super.initState();
    _searchAnimController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _searchAnim = Tween<double>(begin: 0, end: 1).animate(_searchAnimController);
    _pageController = PageController(initialPage: _initialIndex);

    _generateMonths();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_initialIndex * itemWidth);
      }
    });
  }

  void _generateMonths() {
    final baseDate = DateTime.now();
    for (int i = -24; i <= 24; i++) {
      _months.add(DateTime(baseDate.year, baseDate.month + i, 1));
    }
  }

  void _toggleSearch() {
    if (_isSearchActive) {
      _searchFocusNode.unfocus();
      setState(() {
        _isSearchActive = false;
      });
      _searchAnimController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _searchQuery = "";
            _searchController.clear();
          });
        }
      });
    } else {
      setState(() {
        _isSearchActive = true;
      });
      _searchAnimController.forward();
    }
  }

  void _syncCarouselToPage(int pageIndex) {
    if (_isSyncing) return;
    _isSyncing = true;

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        pageIndex * itemWidth,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      ).then((_) => _isSyncing = false);
    } else {
      _isSyncing = false;
    }
  }

  void _handleMonthTap(int index, AppProvider provider) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final isDoubleTap = (now - _lastTapTime < 300) && (_lastTapIndex == index);

    final targetIndex = isDoubleTap ? _initialIndex : index;
    final targetDate = isDoubleTap ? DateTime.now() : _months[index];

    provider.setCurrentDate(targetDate);

    _isSyncing = true;
    if (isDoubleTap) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(targetIndex);
      }
      if (_scrollController.hasClients) {
        _scrollController
            .animateTo(
              targetIndex * itemWidth,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
            )
            .then((_) => _isSyncing = false);
      } else {
        _isSyncing = false;
      }
      _lastTapTime = 0;
      _lastTapIndex = -1;
    } else {
      Future.wait([
        if (_scrollController.hasClients)
          _scrollController.animateTo(targetIndex * itemWidth, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic),
        if (_pageController.hasClients)
          _pageController.animateToPage(targetIndex, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic),
      ]).then((_) => _isSyncing = false);
      _lastTapTime = now;
      _lastTapIndex = index;
    }
  }

  @override
  void dispose() {
    _searchAnimController.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<dynamic> _getGroupedTransactionsForMonth(
    DateTime monthDate,
    String searchQuery,
    List<TransactionModel> allTransactions,
    List<CategoryModel> categories,
  ) {
    final isStale = !identical(_cachedAllTransactionsRef, allTransactions) ||
        !identical(_cachedCategoriesRef, categories) ||
        _cachedSearchQuery != searchQuery;

    if (isStale) {
      _cachedAllTransactionsRef = allTransactions;
      _cachedCategoriesRef = categories;
      _cachedSearchQuery = searchQuery;
      _cachedCategoryMap = {for (var c in categories) c.id: c};
      _monthGroupedCache.clear();
    }

    final int monthKey = monthDate.year * 100 + monthDate.month;
    final cached = _monthGroupedCache[monthKey];
    if (cached != null) {
      return cached;
    }

    final startMs = DateTime(monthDate.year, monthDate.month, 1).millisecondsSinceEpoch;
    final endMs = DateTime(monthDate.year, monthDate.month + 1, 1).millisecondsSinceEpoch;
    final hasSearch = searchQuery.isNotEmpty;
    final q = hasSearch ? searchQuery.toLowerCase() : '';

    final List<TransactionModel> currentMonthTransactions = [];
    for (final t in allTransactions) {
      if (t.date >= startMs && t.date < endMs) {
        if (!hasSearch) {
          currentMonthTransactions.add(t);
        } else {
          final cat = _cachedCategoryMap[t.categoryId];
          final noteMatch = t.note.toLowerCase().contains(q);
          final catMatch = cat != null && cat.name.toLowerCase().contains(q);
          if (noteMatch || catMatch) {
            currentMonthTransactions.add(t);
          }
        }
      }
    }

    if (currentMonthTransactions.isEmpty) {
      _monthGroupedCache[monthKey] = const [];
      return const [];
    }

    currentMonthTransactions.sort((a, b) => b.date.compareTo(a.date));

    final Map<String, List<TransactionModel>> grouped = {};
    for (final t in currentMonthTransactions) {
      final dateObj = DateTime.fromMillisecondsSinceEpoch(t.date);
      final dateString = _formatDayHeader(dateObj);
      (grouped[dateString] ??= []).add(t);
    }

    final List<dynamic> flattened = [];
    for (final entry in grouped.entries) {
      flattened.add(entry.key);
      flattened.addAll(entry.value);
    }

    _monthGroupedCache[monthKey] = flattened;
    return flattened;
  }

  @override
  Widget buildBody(BuildContext context) {
    final transactions = context.select((AppProvider p) => p.transactions);
    final categories = context.select((AppProvider p) => p.categories);
    final currentDate = context.select((AppProvider p) => p.currentDate);
    final currency = context.select((AppProvider p) => p.currency);
    final user = context.select((AppProvider p) => p.user);
    final isSynced = context.select((AppProvider p) => p.isSynced);
    final width = MediaQuery.sizeOf(context).width;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 8.0, bottom: 2.0),
          child: SizedBox(
            height: 44,
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedBuilder(
                    animation: _searchAnim,
                    builder: (context, child) {
                      return Opacity(
                        opacity: (1.0 - _searchAnim.value).clamp(0.0, 1.0),
                        child: Text(
                          user?.name != null ? "Welcome, ${user!.name}" : "Ducat",
                          style: user?.name != null
                              ? AppTypography.screenTitle.copyWith(fontSize: 24)
                              : AppTypography.screenTitle,
                        ),
                      );
                    },
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    height: 44,
                    width: width - 40,
                    child: Stack(
                      alignment: Alignment.centerRight,
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          right: 44,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            width: _isSearchActive ? width - 90 : 44.0,
                            height: 44.0,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: _isSearchActive ? 0.3 : 0.0),
                                width: 1.5,
                              ),
                              color: _isSearchActive ? const Color(0xFF121212).withValues(alpha: 0.90) : Colors.transparent,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(left: 15, right: 40),
                                      child: TextField(
                                        controller: _searchController,
                                        focusNode: _searchFocusNode,
                                        onChanged: (val) => setState(() => _searchQuery = val),
                                        style: const TextStyle(color: Colors.white),
                                        decoration: InputDecoration(
                                          border: InputBorder.none,
                                          hintText: "Search...",
                                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 44,
                          child: GestureDetector(
                            onTap: _toggleSearch,
                            child: Container(
                              width: 44,
                              height: 44,
                              color: Colors.transparent,
                              alignment: Alignment.center,
                              child: Icon(
                                _isSearchActive ? Icons.close : Icons.search,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(builder: (_) => const ProfileScreen()),
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.all(2.0),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSynced ? const Color(0xFF00E676) : const Color(0xFFFF3D00),
                                  width: 2.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isSynced ? const Color(0xFF00E676) : const Color(0xFFFF3D00))
                                        .withValues(alpha: 0.45),
                                    blurRadius: 6,
                                    spreadRadius: 0.5,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: user?.photoPath != null
                                    ? Image.file(
                                        File(user!.photoPath!),
                                        width: 24,
                                        height: 24,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Image.asset(
                                          'assets/avatar.png',
                                          width: 24,
                                          height: 24,
                                          fit: BoxFit.cover,
                                          color: Colors.white,
                                          colorBlendMode: BlendMode.srcIn,
                                        ),
                                      )
                                    : Image.asset(
                                        'assets/avatar.png',
                                        width: 24,
                                        height: 24,
                                        fit: BoxFit.cover,
                                        color: Colors.white,
                                        colorBlendMode: BlendMode.srcIn,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),

        Container(
          height: 90,
          margin: const EdgeInsets.only(left: 20, right: 20, top: 0, bottom: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF121212).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (_isSyncing) return false;
              if (notification is ScrollEndNotification && notification.depth == 0) {
                final index = (_scrollController.offset / itemWidth).round().clamp(0, _months.length - 1);
                final selected = _months[index];
                if (selected.month != currentDate.month || selected.year != currentDate.year) {
                  context.read<AppProvider>().setCurrentDate(selected);
                }
                _isSyncing = true;
                Future.wait([
                  if (_scrollController.hasClients)
                    _scrollController.animateTo(
                      index * itemWidth,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                    ),
                  if (_pageController.hasClients)
                    _pageController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                    ),
                ]).then((_) => _isSyncing = false);
              }
              return false;
            },
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: SnappingScrollPhysics(itemExtent: itemWidth, parent: const BouncingScrollPhysics()),
              itemExtent: itemWidth,
              padding: EdgeInsets.symmetric(horizontal: (width - 40 - itemWidth) / 2),
              itemCount: _months.length,
              itemBuilder: (context, index) {
                final item = _months[index];
                final isActive = item.month == currentDate.month && item.year == currentDate.year;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _handleMonthTap(index, context.read<AppProvider>()),
                  child: Container(
                    width: itemWidth,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: isActive ? 3 : 2,
                          height: isActive ? 22 : 15,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(1),
                            boxShadow: isActive ? [const BoxShadow(color: Colors.white, blurRadius: 10)] : null,
                          ),
                        ),
                        Text(
                          DateFormat('MMM').format(item).toUpperCase(),
                          style: TextStyle(
                            color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.3),
                            fontSize: isActive ? 16 : 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            shadows: isActive ? [const Shadow(color: Colors.white70, blurRadius: 10)] : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.year.toString(),
                          style: TextStyle(
                            color: isActive ? Colors.white.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.15),
                            fontSize: isActive ? 11 : 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _months.length,
            onPageChanged: (index) {
              final selected = _months[index];
              if (selected.month != currentDate.month || selected.year != currentDate.year) {
                context.read<AppProvider>().setCurrentDate(selected);
              }
              _syncCarouselToPage(index);
            },
            itemBuilder: (context, index) {
              final monthDate = _months[index];
              final monthTransactions = _getGroupedTransactionsForMonth(monthDate, _searchQuery, transactions, categories);

              return MonthTransactionsView(
                transactions: monthTransactions,
                categoryMap: _cachedCategoryMap,
                currencySymbol: currency.symbol,
              );
            },
          ),
        ),
      ],
    );
  }
}

class MonthTransactionsView extends StatelessWidget {
  final List<dynamic> transactions;
  final Map<String, CategoryModel> categoryMap;
  final String currencySymbol;

  const MonthTransactionsView({
    super.key,
    required this.transactions,
    required this.categoryMap,
    required this.currencySymbol,
  });

  static final _defaultCategory = CategoryModel(id: '', name: '', icon: '', type: '');

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Center(
        child: Text(
          "No transactions this month.",
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      padding: const EdgeInsets.symmetric(horizontal: 20).copyWith(bottom: 110),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final item = transactions[index];
        if (item is String) {
          return Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 5),
            child: Text(item, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          );
        } else if (item is TransactionModel) {
          final cat = categoryMap[item.categoryId] ?? _defaultCategory;
          return TransactionItem(transaction: item, category: cat);
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class SnappingScrollPhysics extends ScrollPhysics {
  final double itemExtent;

  const SnappingScrollPhysics({required this.itemExtent, super.parent});

  @override
  SnappingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return SnappingScrollPhysics(itemExtent: itemExtent, parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    final Tolerance tolerance = toleranceFor(position);
    final double currentIndex = position.pixels / itemExtent;
    double targetIndex;

    if (velocity.abs() < tolerance.velocity) {
      targetIndex = currentIndex.roundToDouble();
    } else {
      double expectedPixels = position.pixels + velocity * 0.25;
      targetIndex = (expectedPixels / itemExtent).roundToDouble();

      if (velocity > 0 && targetIndex <= currentIndex) {
        targetIndex = currentIndex.ceilToDouble();
      } else if (velocity < 0 && targetIndex >= currentIndex) {
        targetIndex = currentIndex.floorToDouble();
      }
    }

    final double targetPixels = (targetIndex * itemExtent).clamp(position.minScrollExtent, position.maxScrollExtent);

    if ((targetPixels - position.pixels).abs() > 0.001) {
      return ScrollSpringSimulation(
        spring,
        position.pixels,
        targetPixels,
        velocity,
        tolerance: tolerance,
      );
    }

    return null;
  }

  @override
  bool get allowImplicitScrolling => false;
}
