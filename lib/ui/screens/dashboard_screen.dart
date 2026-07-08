import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../components/app_background.dart';
import '../components/transaction_item.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
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

  bool _isSyncing = false;

  // Cache of grouped transactions per month and search query
  // Key: "year_month_searchQuery"
  final Map<String, List<dynamic>> _groupedTransactionsCache = {};
  List<TransactionModel>? _cachedTransactions;
  String? _cachedSearchQuery;

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

  void _syncPageToCarousel(int pageIndex) {
    if (_isSyncing) return;
    _isSyncing = true;
    
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        pageIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      ).then((_) => _isSyncing = false);
    } else {
      _isSyncing = false;
    }
  }

  void _handleMonthTap(int index, AppProvider provider) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final targetIndex = (now - _lastTapTime < 300) ? _initialIndex : index;
    final targetDate = (now - _lastTapTime < 300) ? DateTime.now() : _months[index];
    
    _isSyncing = true;
    Future.wait([
      if (_scrollController.hasClients)
        _scrollController.animateTo(targetIndex * itemWidth, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic),
      if (_pageController.hasClients)
        _pageController.animateToPage(targetIndex, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic),
    ]).then((_) => _isSyncing = false);

    provider.setCurrentDate(targetDate);
    _lastTapTime = now;
  }

  @override
  void dispose() {
    _searchAnimController.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  List<dynamic> _getGroupedTransactionsForMonth(DateTime monthDate, String searchQuery, AppProvider provider) {
    if (_cachedTransactions != provider.transactions || _cachedSearchQuery != searchQuery) {
      _groupedTransactionsCache.clear();
      _cachedTransactions = provider.transactions;
      _cachedSearchQuery = searchQuery;
    }

    final cacheKey = "${monthDate.year}_${monthDate.month}_$searchQuery";
    if (_groupedTransactionsCache.containsKey(cacheKey)) {
      return _groupedTransactionsCache[cacheKey]!;
    }

    final currentMonthTransactions = provider.transactions.where((t) {
      final date = DateTime.fromMillisecondsSinceEpoch(t.date);
      final isCurrentMonth = date.month == monthDate.month && date.year == monthDate.year;
      if (!isCurrentMonth) return false;

      if (searchQuery.isEmpty) return true;
      final q = searchQuery.toLowerCase();
      final cat = provider.categories.firstWhere((c) => c.id == t.categoryId, orElse: () => CategoryModel(id: '', name: 'Uncategorized', icon: '❓', type: ''));
      final noteMatch = (t.note).toLowerCase().contains(q);
      final catMatch = cat.name.toLowerCase().contains(q);
      return noteMatch || catMatch;
    }).toList();

    final Map<String, List<TransactionModel>> grouped = {};
    for (var t in currentMonthTransactions) {
      final dateObj = DateTime.fromMillisecondsSinceEpoch(t.date);
      final dateString = DateFormat('MMM d, EEEE').format(dateObj);
      if (!grouped.containsKey(dateString)) {
        grouped[dateString] = [];
      }
      grouped[dateString]!.add(t);
    }

    final sortedKeys = grouped.keys.toList()..sort((a, b) {
      final dateA = grouped[a]!.first.date;
      final dateB = grouped[b]!.first.date;
      return dateB.compareTo(dateA);
    });

    final List<dynamic> flattened = [];
    for (final key in sortedKeys) {
      flattened.add(key);
      flattened.addAll(grouped[key]!);
    }

    _groupedTransactionsCache[cacheKey] = flattened;
    return flattened;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final width = MediaQuery.of(context).size.width;

    return AppBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
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
                            child: Text("Ducat", style: AppTypography.screenTitle),
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
                              right: 50,
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
                                  color: Colors.white.withValues(alpha: _isSearchActive ? 0.05 : 0.0),
                                ),
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        ignoring: !_isSearchActive,
                                        child: AnimatedOpacity(
                                          duration: const Duration(milliseconds: 300),
                                          opacity: _isSearchActive ? 1.0 : 0.0,
                                          child: Padding(
                                            padding: const EdgeInsets.only(left: 15, right: 44),
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
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
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
                                            size: 28,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
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
                                child: ClipOval(
                                  child: Image.asset(
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
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const Icon(Icons.arrow_drop_down, color: Colors.white),
            
            Container(
              height: 90,
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollEndNotification && notification.depth == 0) {
                    final index = (_scrollController.offset / itemWidth).round();
                    if (index >= 0 && index < _months.length) {
                      final selected = _months[index];
                      if (selected.month != provider.currentDate.month || selected.year != provider.currentDate.year) {
                        provider.setCurrentDate(selected);
                      }
                      _syncPageToCarousel(index);
                    }
                  }
                  return false;
                },
                child: ListView.builder(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(), 
                  itemExtent: itemWidth,
                  padding: EdgeInsets.symmetric(horizontal: (width - 20 - itemWidth) / 2),
                  itemCount: _months.length,
                  itemBuilder: (context, index) {
                    final item = _months[index];
                    final isActive = item.month == provider.currentDate.month && item.year == provider.currentDate.year;
                    
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _handleMonthTap(index, provider),
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
                                boxShadow: isActive ? [BoxShadow(color: Colors.white, blurRadius: 10)] : null,
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
                  if (selected.month != provider.currentDate.month || selected.year != provider.currentDate.year) {
                    provider.setCurrentDate(selected);
                  }
                  _syncCarouselToPage(index);
                },
                itemBuilder: (context, index) {
                  final monthDate = _months[index];
                  final monthTransactions = _getGroupedTransactionsForMonth(monthDate, _searchQuery, provider);
                  
                  return MonthTransactionsView(
                    transactions: monthTransactions,
                    categories: provider.categories,
                    currencySymbol: provider.currency.symbol,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MonthTransactionsView extends StatelessWidget {
  final List<dynamic> transactions;
  final List<CategoryModel> categories;
  final String currencySymbol;

  const MonthTransactionsView({
    super.key,
    required this.transactions,
    required this.categories,
    required this.currencySymbol,
  });

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
          final cat = categories.firstWhere((c) => c.id == item.categoryId, orElse: () => CategoryModel(id: '', name: '', icon: '', type: ''));
          return TransactionItem(transaction: item, category: cat);
        }
        return const SizedBox.shrink();
      },
    );
  }
}
