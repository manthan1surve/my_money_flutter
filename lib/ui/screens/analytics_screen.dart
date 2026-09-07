import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../base/base_screen.dart';
import '../base/base_card.dart';
import '../components/loading_spinner.dart';
import '../components/charts.dart';
import '../../core/currency_format.dart';

const List<Color> colors = [
  Color(0xFFFE0000),
  Color(0xFFFFEB3B),
  Color(0xFF9C27B0),
  Color(0xFF00FE06),
  Color(0xFFE91E63),
  Color(0xFF00BCD4),
  Color(0xFFFF9800),
  Color(0xFF3F51B5),
];

class AnalyticsScreen extends BaseScreen {
  final bool isActive;
  const AnalyticsScreen({super.key, this.isActive = true});

  @override
  BaseScreenState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends BaseScreenState<AnalyticsScreen> {
  @override
  bool get hasOwnBackground => false;

  String _analysisType = 'expense';
  String _trendPeriod = '1m';
  String _avgPeriod = 'month';
  bool _isCalculatingTrend = false;
  Timer? _computeDebounceTimer;
  bool _justBecameActive = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant AnalyticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _justBecameActive = true;
      _computeDebounceTimer?.cancel();
    } else if (oldWidget.isActive && !widget.isActive) {
      _computeDebounceTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _computeDebounceTimer?.cancel();
    _activeTrendNotifier.dispose();
    super.dispose();
  }

  void _toggleAnalysisType() {
    setState(() {
      _analysisType = _analysisType == 'expense' ? 'income' : 'expense';
    });
  }

  void _setTrendPeriod(String period) {
    if (_trendPeriod == period) return;
    setState(() {
      _trendPeriod = period;
      _isCalculatingTrend = true;
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _isCalculatingTrend = false);
    });
  }

  List<TransactionModel>? _cachedTransactions;
  DateTime? _cachedDate;
  String? _cachedAnalysisType;
  String? _cachedTrendPeriod;

  // Cached average data
  String? _cachedAvgPeriod;
  double _avgIncome = 0;
  double _avgExpense = 0;

  List<TransactionModel> _monthlyTransactions = [];
  double _mExpense = 0;
  double _mIncome = 0;
  List<Map<String, dynamic>> _chartData = [];
  List<Map<String, dynamic>> _trendGraph = [];
  int? _trendDefaultIndex;
  final ValueNotifier<Map<String, dynamic>?> _activeTrendNotifier = ValueNotifier(null);
  double _maxTrendAmount = 0;
  List<Map<String, dynamic>> _groupedBarData = [];
  double _maxBarAmount = 0;

  int _computeSeq = 0;

  void _updateAveragesOnly(List<TransactionModel> transactions, DateTime currentDate) {
    _cachedAvgPeriod = _avgPeriod;
    List<TransactionModel> periodTrans = [];
    if (_avgPeriod == 'month') {
      periodTrans = _monthlyTransactions;
    } else if (_avgPeriod == '6_months') {
      final cutoff = DateTime(currentDate.year, currentDate.month - 5, 1);
      periodTrans = transactions.where((t) {
        final d = DateTime.fromMillisecondsSinceEpoch(t.date);
        return d.isAfter(cutoff) || d.isAtSameMomentAs(cutoff);
      }).toList();
    } else if (_avgPeriod == '1_year') {
      final cutoff = DateTime(currentDate.year - 1, currentDate.month, 1);
      periodTrans = transactions.where((t) {
        final d = DateTime.fromMillisecondsSinceEpoch(t.date);
        return d.isAfter(cutoff) || d.isAtSameMomentAs(cutoff);
      }).toList();
    } else {
      periodTrans = transactions;
    }

    final activeDaySet = periodTrans.map((t) {
      final d = DateTime.fromMillisecondsSinceEpoch(t.date);
      return "${d.year}-${d.month}-${d.day}";
    }).toSet();
    final activeDays = activeDaySet.length;

    final pIncome = periodTrans.where((t) => t.type == 'income').fold(0.0, (acc, curr) => acc + curr.amount);
    final pExpense = periodTrans.where((t) => t.type == 'expense').fold(0.0, (acc, curr) => acc + curr.amount);

    _avgIncome = activeDays > 0 ? pIncome / activeDays : 0.0;
    _avgExpense = activeDays > 0 ? pExpense / activeDays : 0.0;
  }

  void _triggerCompute(
    List<TransactionModel> transactions,
    DateTime currentDate,
    List<CategoryModel> categories, {
    bool delay = false,
  }) {
    if (!widget.isActive) return;
    if (_cachedTransactions == transactions && 
        _cachedDate == currentDate &&
        _cachedAnalysisType == _analysisType &&
        _cachedTrendPeriod == _trendPeriod) {
      if (_cachedAvgPeriod != _avgPeriod) {
        _updateAveragesOnly(transactions, currentDate);
      }
      return;
    }

    _cachedTransactions = transactions;
    _cachedDate = currentDate;
    _cachedAnalysisType = _analysisType;
    _cachedTrendPeriod = _trendPeriod;
    _cachedAvgPeriod = _avgPeriod;

    _computeSeq++;
    final seq = _computeSeq;
    _computeDebounceTimer?.cancel();

    void executeCompute() {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || !widget.isActive || _computeSeq != seq) return;
        
        final result = await compute(_computeAnalyticsIsolate, _AnalyticsComputeInput(
          transactions, currentDate, categories, _analysisType, _trendPeriod, _avgPeriod,
        ));

        if (!mounted || !widget.isActive || _computeSeq != seq) return;

        setState(() {
          _monthlyTransactions = result.monthlyTransactions;
          _mExpense = result.mExpense;
          _mIncome = result.mIncome;
          _chartData = result.chartData;
          _trendGraph = result.trendGraph;
          _maxTrendAmount = result.maxTrendAmount;
          _trendDefaultIndex = result.trendDefaultIndex;
          _groupedBarData = result.groupedBarData;
          _maxBarAmount = result.maxBarAmount;
          _avgIncome = result.avgIncome;
          _avgExpense = result.avgExpense;

          if (_trendGraph.isNotEmpty) {
            _activeTrendNotifier.value = _trendGraph[_trendDefaultIndex ?? (_trendGraph.length - 1)];
          }
        });
      });
    }

    if (delay) {
      _computeDebounceTimer = Timer(const Duration(milliseconds: 150), () {
        if (!mounted || !widget.isActive || _computeSeq != seq) return;
        executeCompute();
      });
    } else {
      executeCompute();
    }
  }

  void _showCategoryTransactions(String categoryId, String categoryName, Color categoryColor) {
    final provider = context.read<AppProvider>();
    final currency = provider.currency;
    final accountMap = {for (var a in provider.accounts) a.id: a};
    final targetTrans = _monthlyTransactions.where((t) => t.categoryId == categoryId && t.type == _analysisType).toList();
    targetTrans.sort((a, b) => b.date.compareTo(a.date));

    final Map<String, List<TransactionModel>> grouped = {};
    for (var t in targetTrans) {
      final dateObj = DateTime.fromMillisecondsSinceEpoch(t.date);
      final dateString = DateFormat('MMM dd, EEEE').format(dateObj);
      if (!grouped.containsKey(dateString)) {
        grouped[dateString] = [];
      }
      grouped[dateString]!.add(t);
    }

    showDialog(
      context: context,
      builder: (context) {
        bool isNewToOld = true;
        final monthStr = DateFormat('MMMM yyyy').format(_cachedDate ?? DateTime.now());
        
        return StatefulBuilder(
          builder: (context, setState) {
            for (var key in grouped.keys) {
              grouped[key]!.sort((a, b) => isNewToOld ? b.date.compareTo(a.date) : a.date.compareTo(b.date));
            }
            final sortedKeys = grouped.keys.toList()..sort((a, b) {
              final dateA = grouped[a]!.first.date;
              final dateB = grouped[b]!.first.date;
              return isNewToOld ? dateB.compareTo(dateA) : dateA.compareTo(dateB);
            });

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                    ),
                    RepaintBoundary(
                      child: Container(
                        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  "$monthStr : ${targetTrans.length} records",
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    isNewToOld = !isNewToOld;
                                  });
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Row(
                                  children: [
                                    Icon(isNewToOld ? Icons.arrow_downward : Icons.arrow_upward, color: Colors.white, size: 16),
                                    const SizedBox(width: 4),
                                    Text(isNewToOld ? "NEW TO OLD" : "OLD TO NEW", style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                behavior: HitTestBehavior.opaque,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                                ),
                              ),
                            ],
                          ),
                      const SizedBox(height: 20),
                      if (targetTrans.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: Text(
                              "No transactions found.",
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ),
                        )
                      else
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                            itemCount: sortedKeys.length,
                            itemBuilder: (context, index) {
                              final dateKey = sortedKeys[index];
                              final dayTrans = grouped[dateKey]!;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    dateKey,
                                    style: GoogleFonts.fraunces(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(height: 1, color: Colors.white.withValues(alpha: 0.2)),
                                  const SizedBox(height: 12),
                                  ...dayTrans.map((t) {
                                    final acc = accountMap[t.accountId];
                                    final sign = t.type == 'expense' ? '-' : '+';
                                    final amountColor = t.type == 'expense' ? const Color(0xFFFE0000) : const Color(0xFF00FE06);
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 16),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 6,
                                            height: 6,
                                            margin: const EdgeInsets.only(top: 6, right: 12),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.5),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          Expanded(
                                            child: Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  acc?.name ?? 'Unknown',
                                                  style: GoogleFonts.fraunces(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                                                ),
                                                if (t.note.isNotEmpty) ...[
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      '" ${t.note} "',
                                                      style: GoogleFonts.fraunces(color: Colors.white.withValues(alpha: 0.4), fontSize: 16, fontStyle: FontStyle.italic),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            "$sign${currency.symbol}${t.amount.formatIndianCurrency()}",
                                            style: GoogleFonts.fraunces(color: amountColor, fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 8),
                                ],
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                ),
                  ],
                ),
              ),
            );
        },
        );
      },
    );
  }

  @override
  String? get screenTitle => "Analytics";

  @override
  Widget buildBody(BuildContext context) {
    final currency = context.select((AppProvider p) => p.currency);
    final currentDate = context.select((AppProvider p) => p.currentDate);
    final transactions = context.select((AppProvider p) => p.transactions);
    final categories = context.select((AppProvider p) => p.categories);

    if (widget.isActive) {
      final shouldDelay = _justBecameActive;
      _justBecameActive = false;
      _triggerCompute(transactions, currentDate, categories, delay: shouldDelay);
    }

    final monthlyBalance = _mIncome - _mExpense;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        CupertinoSliverRefreshControl(
          refreshTriggerPullDistance: 80.0,
          refreshIndicatorExtent: 60.0,
          onRefresh: () async {
            HapticFeedback.lightImpact();
            final provider = context.read<AppProvider>();
            await Future.wait([
              provider.refreshData(),
              Future.delayed(const Duration(milliseconds: 650)),
            ]);
          },
          builder: (
            BuildContext context,
            RefreshIndicatorMode refreshState,
            double pulledExtent,
            double refreshTriggerPullDistance,
            double refreshIndicatorExtent,
          ) {
            final double progress = (pulledExtent / refreshTriggerPullDistance).clamp(0.0, 1.0);
            return Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.only(bottom: 8),
              child: Opacity(
                opacity: progress,
                child: Transform.scale(
                  scale: 0.7 + (0.3 * progress),
                  child: const LoadingSpinner(size: 26, strokeWidth: 3.5),
                ),
              ),
            );
          },
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          sliver: SliverList(
            delegate: SliverChildListDelegate([

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _buildSmallSummaryCard(
                          "Net Balance", 
                          "${currency.symbol}${monthlyBalance.abs().formatIndianCurrency()}", 
                          monthlyBalance < 0 ? const Color(0xFFFE0000) : Colors.white,
                          isBreathing: monthlyBalance < 0,
                        ),
                        const SizedBox(height: 6),
                        _buildSmallSummaryCard("Total Income", "${currency.symbol}${_mIncome.formatIndianCurrency()}", const Color(0xFF00FE06)),
                        const SizedBox(height: 6),
                        _buildSmallSummaryCard("Total Expenses", "${currency.symbol}${_mExpense.formatIndianCurrency()}", const Color(0xFFFE0000)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SolidCard(
                      padding: const EdgeInsets.all(16),
                      margin: EdgeInsets.zero,
                      borderRadius: 28,
                      height: 252,
                      child: Builder(builder: (context) {
                        final options = ['1M', '6M', '1Y', 'All'];
                        final values = ['month', '6_months', '1_year', 'all_time'];

                        return Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text("Avg Income", style: GoogleFonts.fraunces(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                                    const SizedBox(height: 4),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.center,
                                      child: Text(
                                        "${currency.symbol}${_avgIncome.formatIndianCurrency()}",
                                        style: GoogleFonts.fraunces(color: const Color(0xFF00FE06), fontSize: 22, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                    Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),
                                    const SizedBox(height: 32),
                                    Text("Avg Expense", style: GoogleFonts.fraunces(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                                    const SizedBox(height: 4),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.center,
                                      child: Text(
                                        "${currency.symbol}${_avgExpense.formatIndianCurrency()}",
                                        style: GoogleFonts.fraunces(color: const Color(0xFFFE0000), fontSize: 22, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              width: 44,
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: Stack(
                                children: [
                                  AnimatedAlign(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic,
                                    alignment: _avgPeriod == 'month'
                                        ? Alignment.topCenter
                                        : _avgPeriod == '6_months'
                                            ? const Alignment(0, -0.333)
                                            : _avgPeriod == '1_year'
                                                ? const Alignment(0, 0.333)
                                                : Alignment.bottomCenter,
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.center,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: List.generate(4, (i) {
                                        final isSelected = _avgPeriod == values[i];
                                        return GestureDetector(
                                          onTap: () => setState(() => _avgPeriod = values[i]),
                                          behavior: HitTestBehavior.opaque,
                                          child: Container(
                                            width: 36,
                                            height: 36,
                                            alignment: Alignment.center,
                                            child: AnimatedDefaultTextStyle(
                                              duration: const Duration(milliseconds: 300),
                                              curve: Curves.easeOutCubic,
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.fraunces(
                                                color: isSelected ? Colors.black : Colors.white,
                                                fontSize: 14,
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                              ),
                                              child: Text(options[i], textAlign: TextAlign.center),
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _SolidCard(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                borderRadius: 28,
                child: RepaintBoundary(
                  child: Column(
                    children: [
                      Container(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Pie Chart", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                            GestureDetector(
                              onTap: _toggleAnalysisType,
                              child: Container(
                                width: 50,
                                height: 24,
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                                child: Stack(
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 400),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        color: _analysisType == 'expense' ? const Color(0xFFFE0000) : const Color(0xFF00FE06),
                                      ),
                                    ),
                                    AnimatedPositioned(
                                      duration: const Duration(milliseconds: 400),
                                      curve: Curves.easeInOut,
                                      left: _analysisType == 'expense' ? 2.0 : 26.0,
                                      top: 2,
                                      child: Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(10),
                                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
                                        ),
                                        alignment: Alignment.center,
                                        child: AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 400),
                                          child: Icon(
                                            _analysisType == 'expense' ? Icons.arrow_downward : Icons.arrow_upward,
                                            key: ValueKey(_analysisType),
                                            size: 9,
                                            color: _analysisType == 'expense' ? const Color(0xFFFE0000) : const Color(0xFF00FE06),
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
                        const SizedBox(height: 24),
                        if (_chartData.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: SizedBox(
                                  width: 140,
                                  height: 140,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      RepaintBoundary(
                                        child: CustomPaint(
                                          size: const Size(140, 140),
                                          painter: ConcentricRingsPainter(rings: _chartData.toList()),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              ...List.generate(_chartData.length, (index) {
                                final item = _chartData[index];
                                final percentage = item['percentage'] as double;
                                final amount = item['amount'] as double;
                                final color = item['color'] as Color;
                                final name = item['name'] as String;
                                final icon = item['icon'] as String;
                                
                                final sign = _analysisType == 'expense' ? '-' : '+';
                                final amountText = "$sign${currency.symbol}${amount.formatIndianCurrency()}";
                                final percentageText = "${percentage.toStringAsFixed(2)}%";
                                
                                return GestureDetector(
                                  onTap: () => _showCategoryTransactions(item['id'] as String, name, color),
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    color: Colors.transparent,
                                    child: Column(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Row(
                                        children: [
                                          // Circular category icon background
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: color,
                                              shape: BoxShape.circle,
                                            ),
                                            alignment: Alignment.center,
                                            child: Text(
                                              icon,
                                              style: const TextStyle(fontSize: 20),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          // Middle section: name, amount, progress bar
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        name,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      amountText,
                                                      style: TextStyle(
                                                        color: _analysisType == 'expense' 
                                                            ? const Color(0xFFFE0000) 
                                                            : const Color(0xFF00FE06),
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                // Progress bar with border
                                                Container(
                                                  height: 9,
                                                  width: double.infinity,
                                                  padding: const EdgeInsets.all(1.2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.transparent,
                                                    borderRadius: BorderRadius.circular(4.5),
                                                    border: Border.all(
                                                      color: Colors.white,
                                                      width: 1.0,
                                                    ),
                                                  ),
                                                  alignment: Alignment.centerLeft,
                                                  child: TweenAnimationBuilder<double>(
                                                    key: ValueKey('${item['id']}_${_analysisType}_${currentDate.millisecondsSinceEpoch}'),
                                                    tween: Tween<double>(begin: 0.0, end: (percentage / 100).clamp(0.0, 1.0)),
                                                    duration: const Duration(milliseconds: 800),
                                                    curve: Curves.easeOutCubic,
                                                    builder: (context, animValue, child) {
                                                      return FractionallySizedBox(
                                                        widthFactor: animValue,
                                                        child: Container(
                                                          decoration: BoxDecoration(
                                                            color: Colors.white,
                                                            borderRadius: BorderRadius.circular(3.5),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          // Right section: percentage label
                                          SizedBox(
                                            width: 52,
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              alignment: Alignment.centerRight,
                                              child: Text(
                                                percentageText,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (index < _chartData.length - 1)
                                      const Divider(color: Color(0x15FFFFFF), height: 1),
                                  ],
                                ),
                              ),
                            );
                          }),
                            ],
                          )
                        else if (_cachedTransactions == null)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(child: LoadingSpinner()),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(40),
                            alignment: Alignment.center,
                            child: Text("No ${_analysisType}s recorded yet.", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16)),
                          ),
                        
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Trend", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Builder(
                              builder: (context) {
                                final periodTotal = _trendGraph.fold<double>(
                                  0.0,
                                  (sum, item) => sum + (item['total'] as double),
                                );
                                final periodLabel = _trendPeriod == '1w'
                                    ? 'This Week'
                                    : _trendPeriod == '1m'
                                        ? 'This Month'
                                        : _trendPeriod == '6m'
                                            ? 'Last 6 Months'
                                            : _trendPeriod == '1y'
                                                ? 'This Year'
                                                : 'All Time';
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          _analysisType == 'expense' ? 'Total Expense' : 'Total Income',
                                          style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12, letterSpacing: 0.3),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            periodLabel,
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.45),
                                              fontSize: 10,
                                              letterSpacing: 0.2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${currency.symbol}${periodTotal.formatIndianCurrency()}',
                                      style: TextStyle(
                                        color: _analysisType == 'expense' ? const Color(0xFFFE0000) : const Color(0xFF00FE06),
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 220,
                          child: (_isCalculatingTrend || _cachedTransactions == null)
                              ? const Center(child: LoadingSpinner())
                              : RepaintBoundary(
                                  child: CustomLineChart(
                                    data: _trendGraph,
                                    maxAmount: _maxTrendAmount,
                                    color: _analysisType == 'expense' ? const Color(0xFFFE0000) : const Color(0xFF00FE06),
                                    currencySymbol: currency.symbol,
                                    showAllLabels: _trendPeriod != '1m',
                                    isExpense: _analysisType == 'expense',
                                    defaultIndex: _trendDefaultIndex,
                                    onActiveItemChanged: (item) => _activeTrendNotifier.value = item,
                                    labelWidth: _trendPeriod == '1w' ? 50 : 30,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 20),
                        Center(
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white),
                            ),
                            padding: const EdgeInsets.all(2),
                            child: Stack(
                              children: [
                                AnimatedPositioned(
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeOutQuart,
                                  left: _trendPeriod == '1w'
                                      ? 0.0
                                      : (_trendPeriod == '1m'
                                          ? 45.0
                                          : (_trendPeriod == '6m'
                                              ? 90.0
                                              : (_trendPeriod == '1y' ? 135.0 : 180.0))),
                                  top: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 45,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(17),
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildTrendBtn('1w', '1W'),
                                    _buildTrendBtn('1m', '1M'),
                                    _buildTrendBtn('6m', '6M'),
                                    _buildTrendBtn('1y', '1Y'),
                                    _buildTrendBtn('all', 'ALL'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),
              _SolidCard(
                borderRadius: 28,
                padding: const EdgeInsets.all(24),
                child: RepaintBoundary(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Income vs Expense", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 220,
                        child: _cachedTransactions == null
                            ? const Center(child: LoadingSpinner())
                            : CustomGroupedBarChart(
                                data: _groupedBarData,
                                maxAmount: _maxBarAmount == 0 ? 100 : _maxBarAmount,
                                currencySymbol: currency.symbol,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSmallSummaryCard(String label, String value, Color valueColor, {bool isBreathing = false}) {
    return _SolidCard(
      height: 80,
      margin: EdgeInsets.zero,
      borderRadius: 24,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13, letterSpacing: 0.5))),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown, 
            alignment: Alignment.centerLeft, 
            child: isBreathing 
                ? BreathingText(text: value, color: valueColor, fontSize: 18)
                : Text(value, style: TextStyle(color: valueColor, fontSize: 18, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  Widget _buildTrendBtn(String period, String title) {
    final isActive = _trendPeriod == period;
    return GestureDetector(
      onTap: () => _setTrendPeriod(period),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 45,
        height: 36,
        alignment: Alignment.center,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutQuart,
          style: GoogleFonts.fraunces(
            color: isActive ? Colors.black : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
          child: Text(title),
        ),
      ),
    );
  }
}

class _SolidCard extends BaseCardWidget {
  const _SolidCard({
    required super.child,
    super.borderRadius = 20.0,
    super.padding = const EdgeInsets.all(24.0),
    super.margin = const EdgeInsets.symmetric(vertical: 12.0),
    super.height = double.nan,
  });

  @override
  Widget buildCardContainer(BuildContext context, Widget cardChild) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF121212).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1.5,
        ),
      ),
      child: cardChild,
    );
  }
}


class _AnalyticsComputeInput {
  final List<TransactionModel> transactions;
  final DateTime currentDate;
  final List<CategoryModel> categories;
  final String analysisType;
  final String trendPeriod;
  final String avgPeriod;

  _AnalyticsComputeInput(this.transactions, this.currentDate, this.categories, this.analysisType, this.trendPeriod, this.avgPeriod);
}

class _AnalyticsComputeResult {
  final List<TransactionModel> monthlyTransactions;
  final double mExpense;
  final double mIncome;
  final List<Map<String, dynamic>> chartData;
  final List<Map<String, dynamic>> trendGraph;
  final double maxTrendAmount;
  final int? trendDefaultIndex;
  final List<Map<String, dynamic>> groupedBarData;
  final double maxBarAmount;
  final double avgIncome;
  final double avgExpense;

  _AnalyticsComputeResult({
    required this.monthlyTransactions,
    required this.mExpense,
    required this.mIncome,
    required this.chartData,
    required this.trendGraph,
    required this.maxTrendAmount,
    required this.trendDefaultIndex,
    required this.groupedBarData,
    required this.maxBarAmount,
    required this.avgIncome,
    required this.avgExpense,
  });
}

_AnalyticsComputeResult _computeAnalyticsIsolate(_AnalyticsComputeInput input) {
  final transactions = input.transactions;
  final currentDate = input.currentDate;
  final categories = input.categories;
  final analysisType = input.analysisType;
  final trendPeriod = input.trendPeriod;
  final avgPeriod = input.avgPeriod;

  final monthlyTransactions = transactions.where((t) {
    final date = DateTime.fromMillisecondsSinceEpoch(t.date);
    return date.month == currentDate.month && date.year == currentDate.year;
  }).toList();

  final expenses = monthlyTransactions.where((t) => t.type == 'expense').toList();
  final incomes = monthlyTransactions.where((t) => t.type == 'income').toList();
  final mExpense = expenses.fold(0.0, (acc, curr) => acc + curr.amount);
  final mIncome = incomes.fold(0.0, (acc, curr) => acc + curr.amount);

  final targetTransactions = analysisType == 'expense' ? expenses : incomes;
  final total = analysisType == 'expense' ? mExpense : mIncome;

  final Map<String, double> categoryTotals = {};
  for (var t in targetTransactions) {
    final catId = t.categoryId.isEmpty ? 'unknown' : t.categoryId;
    categoryTotals[catId] = (categoryTotals[catId] ?? 0) + t.amount;
  }

  final chartData = categoryTotals.keys.map((catId) {
    final cat = categories.firstWhere((c) => c.id == catId, orElse: () => CategoryModel(id: '', name: 'Uncategorized', icon: '❓', type: ''));
    return {
      'id': catId,
      'name': cat.name,
      'icon': cat.icon,
      'amount': categoryTotals[catId]!,
      'percentage': total > 0 ? (categoryTotals[catId]! / total) * 100 : 0.0,
    };
  }).toList();
  
  chartData.sort((a, b) => (b['amount'] as num).compareTo(a['amount'] as num));
  final List<Color> colors = [
    const Color(0xFFFE0000), const Color(0xFFFFEB3B), const Color(0xFF9C27B0), 
    const Color(0xFF00FE06), const Color(0xFFE91E63), const Color(0xFF00BCD4), 
    const Color(0xFFFF9800), const Color(0xFF3F51B5),
  ];
  for (int i = 0; i < chartData.length; i++) {
    chartData[i]['color'] = colors[i % colors.length];
  }

  final List<Map<String, dynamic>> trendGraph = [];
  double maxTrendAmount = 0;

  final monthsShort = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  final weekdaysShort = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];

  if (trendPeriod == '1w') {
    final DateTime targetEndDate;
    final now = DateTime.now();
    if (currentDate.month == now.month && currentDate.year == now.year) {
      targetEndDate = DateTime(now.year, now.month, now.day);
    } else {
      targetEndDate = DateTime(currentDate.year, currentDate.month + 1, 0);
    }
    final monthStart = DateTime(targetEndDate.year, targetEndDate.month, 1);
    final List<DateTime> days = [];
    for (int i = 6; i >= 0; i--) {
      final day = targetEndDate.subtract(Duration(days: i));
      if (!day.isBefore(monthStart)) days.add(day);
    }
    Map<String, double> dailyTotals = {};
    for (var t in transactions) {
      if (t.type == analysisType) {
        final tDate = DateTime.fromMillisecondsSinceEpoch(t.date);
        final key = "${tDate.year}-${tDate.month.toString().padLeft(2, '0')}-${tDate.day.toString().padLeft(2, '0')}";
        dailyTotals[key] = (dailyTotals[key] ?? 0.0) + t.amount;
      }
    }
    for (var day in days) {
      final key = "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";
      final tTotal = dailyTotals[key] ?? 0.0;
      if (tTotal > maxTrendAmount) maxTrendAmount = tTotal;
      final weekdayName = weekdaysShort[day.weekday - 1];
      final monthName = monthsShort[day.month - 1];
      trendGraph.add({
        'label': "$weekdayName, $monthName ${day.day.toString().padLeft(2, '0')}",
        'axisLabel': weekdayName,
        'total': tTotal,
      });
    }
  } else if (trendPeriod == '1m') {
    final year = currentDate.year;
    final month = currentDate.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final monthName = monthsShort[month - 1];
    Map<int, double> dailyTotals = {};
    for (var t in transactions) {
      final tDate = DateTime.fromMillisecondsSinceEpoch(t.date);
      if (tDate.month == month && tDate.year == year && t.type == analysisType) {
        dailyTotals[tDate.day] = (dailyTotals[tDate.day] ?? 0.0) + t.amount;
      }
    }
    for (int i = 1; i <= daysInMonth; i++) {
      final tTotal = dailyTotals[i] ?? 0.0;
      if (tTotal > maxTrendAmount) maxTrendAmount = tTotal;
      trendGraph.add({
        'label': "$monthName ${i.toString().padLeft(2, '0')}",
        'axisLabel': i.toString(),
        'dayNumber': i,
        'daysInMonth': daysInMonth,
        'total': tTotal,
      });
    }
  } else if (trendPeriod == '6m' || trendPeriod == '1y') {
    final endYear = currentDate.year;
    final endMonth = currentDate.month;
    final numMonths = trendPeriod == '6m' ? 6 : 12;
    Map<String, double> monthlyTotals = {};
    for (var t in transactions) {
       if (t.type == analysisType) {
          final tDate = DateTime.fromMillisecondsSinceEpoch(t.date);
          final key = "${tDate.year}-${tDate.month}";
          monthlyTotals[key] = (monthlyTotals[key] ?? 0.0) + t.amount;
       }
    }
    for (int i = numMonths - 1; i >= 0; i--) {
      int m = endMonth - i;
      int y = endYear;
      while (m < 1) {
        m += 12;
        y -= 1;
      }
      final key = "$y-$m";
      final tTotal = monthlyTotals[key] ?? 0.0;
      if (tTotal > maxTrendAmount) maxTrendAmount = tTotal;
      final mName = monthsShort[m - 1];
      trendGraph.add({
        'label': "$mName $y",
        'axisLabel': mName,
        'total': tTotal,
      });
    }
  } else {
    if (transactions.isNotEmpty) {
      Map<int, double> yearlyTotals = {};
      for (var t in transactions) {
         if (t.type == analysisType) {
            final y = DateTime.fromMillisecondsSinceEpoch(t.date).year;
            yearlyTotals[y] = (yearlyTotals[y] ?? 0.0) + t.amount;
         }
      }
      final years = yearlyTotals.keys.toList()..sort();
      if (years.isEmpty) years.add(DateTime.now().year);
      for (final y in years) {
        final tTotal = yearlyTotals[y] ?? 0.0;
        if (tTotal > maxTrendAmount) maxTrendAmount = tTotal;
        trendGraph.add({
          'label': y.toString(),
          'axisLabel': y.toString(),
          'total': tTotal,
        });
      }
    } else {
      final curYear = DateTime.now().year.toString();
      trendGraph.add({'label': curYear, 'axisLabel': curYear, 'total': 0.0});
    }
  }

  int? trendDefaultIndex;
  if ((trendPeriod == '1m' || trendPeriod == '1w') && trendGraph.isNotEmpty) {
    if (trendPeriod == '1w') {
      trendDefaultIndex = trendGraph.length - 1;
    } else {
      final now = DateTime.now();
      if (currentDate.month == now.month && currentDate.year == now.year) {
        int presentIndex = now.day - 1;
        if (presentIndex >= trendGraph.length) {
          presentIndex = trendGraph.length - 1;
        }
        trendDefaultIndex = presentIndex;
      } else {
        double maxVal = -1;
        int maxIdx = 0;
        for (int i = 0; i < trendGraph.length; i++) {
          if (trendGraph[i]['total'] > maxVal) {
            maxVal = trendGraph[i]['total'];
            maxIdx = i;
          }
        }
        trendDefaultIndex = maxIdx;
      }
    }
  }

  List<Map<String, dynamic>> groupedBarData = [];
  double maxBarAmount = 0;
  
  Map<String, Map<String, double>> barTotals = {};
  for (var t in transactions) {
     if (t.type == 'income' || t.type == 'expense') {
        final tDate = DateTime.fromMillisecondsSinceEpoch(t.date);
        final key = "${tDate.year}-${tDate.month}";
        barTotals.putIfAbsent(key, () => {'income': 0.0, 'expense': 0.0});
        barTotals[key]![t.type] = barTotals[key]![t.type]! + t.amount;
     }
  }
  
  final monthsNameBar = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
  for (int i = 5; i >= 0; i--) {
    int y = currentDate.year;
    int m = currentDate.month - i;
    while (m < 1) {
      m += 12;
      y -= 1;
    }
    
    final mName = monthsNameBar[m-1];
    
    final key = "$y-$m";
    final inc = barTotals[key]?['income'] ?? 0.0;
    final exp = barTotals[key]?['expense'] ?? 0.0;

    if (inc > maxBarAmount) maxBarAmount = inc;
    if (exp > maxBarAmount) maxBarAmount = exp;

    groupedBarData.add({'label': mName, 'income': inc, 'expense': exp});
  }

  // Calculate Averages
  List<TransactionModel> periodTrans = [];
  if (avgPeriod == 'month') {
    periodTrans = monthlyTransactions;
  } else if (avgPeriod == '6_months') {
    final cutoff = DateTime(currentDate.year, currentDate.month - 5, 1);
    periodTrans = transactions.where((t) {
      final d = DateTime.fromMillisecondsSinceEpoch(t.date);
      return d.isAfter(cutoff) || d.isAtSameMomentAs(cutoff);
    }).toList();
  } else if (avgPeriod == '1_year') {
    final cutoff = DateTime(currentDate.year - 1, currentDate.month, 1);
    periodTrans = transactions.where((t) {
      final d = DateTime.fromMillisecondsSinceEpoch(t.date);
      return d.isAfter(cutoff) || d.isAtSameMomentAs(cutoff);
    }).toList();
  } else {
    periodTrans = transactions;
  }

  final activeDaySet = periodTrans.map((t) {
    final d = DateTime.fromMillisecondsSinceEpoch(t.date);
    return "${d.year}-${d.month}-${d.day}";
  }).toSet();
  final activeDays = activeDaySet.length;

  final pIncome = periodTrans.where((t) => t.type == 'income').fold(0.0, (acc, curr) => acc + curr.amount);
  final pExpense = periodTrans.where((t) => t.type == 'expense').fold(0.0, (acc, curr) => acc + curr.amount);

  final avgIncome = activeDays > 0 ? pIncome / activeDays : 0.0;
  final avgExpense = activeDays > 0 ? pExpense / activeDays : 0.0;

  return _AnalyticsComputeResult(
    monthlyTransactions: monthlyTransactions,
    mExpense: mExpense,
    mIncome: mIncome,
    chartData: chartData,
    trendGraph: trendGraph,
    maxTrendAmount: maxTrendAmount,
    trendDefaultIndex: trendDefaultIndex,
    groupedBarData: groupedBarData,
    maxBarAmount: maxBarAmount,
    avgIncome: avgIncome,
    avgExpense: avgExpense,
  );
}
