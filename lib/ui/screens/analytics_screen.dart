import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../components/app_background.dart';
// Removed glass_card.dart import
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

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _analysisType = 'expense';
  String _trendPeriod = 'monthly';
  bool _isCalculatingTrend = false;

  @override
  void initState() {
    super.initState();
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

  List<TransactionModel> _monthlyTransactions = [];
  double _mExpense = 0;
  double _mIncome = 0;
  List<Map<String, dynamic>> _chartData = [];
  List<Map<String, dynamic>> _trendGraph = [];
  double _maxTrendAmount = 0;
  List<Map<String, dynamic>> _groupedBarData = [];
  double _maxBarAmount = 0;

  void _calculateAnalyticsData(AppProvider provider) {
    if (_cachedTransactions == provider.transactions && 
        _cachedDate == provider.currentDate &&
        _cachedAnalysisType == _analysisType &&
        _cachedTrendPeriod == _trendPeriod) {
      return;
    }

    _cachedTransactions = provider.transactions;
    _cachedDate = provider.currentDate;
    _cachedAnalysisType = _analysisType;
    _cachedTrendPeriod = _trendPeriod;

    final transactions = provider.transactions;
    final currentDate = provider.currentDate;
    final categories = provider.categories;

    _monthlyTransactions = transactions.where((t) {
      final date = DateTime.fromMillisecondsSinceEpoch(t.date);
      return date.month == currentDate.month && date.year == currentDate.year;
    }).toList();

    final expenses = _monthlyTransactions.where((t) => t.type == 'expense').toList();
    final incomes = _monthlyTransactions.where((t) => t.type == 'income').toList();
    _mExpense = expenses.fold(0.0, (acc, curr) => acc + curr.amount);
    _mIncome = incomes.fold(0.0, (acc, curr) => acc + curr.amount);

    final targetTransactions = _analysisType == 'expense' ? expenses : incomes;
    final total = _analysisType == 'expense' ? _mExpense : _mIncome;

    final Map<String, double> categoryTotals = {};
    for (var t in targetTransactions) {
      final catId = t.categoryId.isEmpty ? 'unknown' : t.categoryId;
      categoryTotals[catId] = (categoryTotals[catId] ?? 0) + t.amount;
    }

    _chartData = categoryTotals.keys.map((catId) {
      final cat = categories.firstWhere((c) => c.id == catId, orElse: () => CategoryModel(id: '', name: 'Uncategorized', icon: '❓', type: ''));
      return {
        'id': catId,
        'name': cat.name,
        'icon': cat.icon,
        'amount': categoryTotals[catId]!,
        'percentage': total > 0 ? (categoryTotals[catId]! / total) * 100 : 0.0,
      };
    }).toList();
    
    _chartData.sort((a, b) => b['amount'].compareTo(a['amount']));
    for (int i = 0; i < _chartData.length; i++) {
      _chartData[i]['color'] = colors[i % colors.length];
    }

    _trendGraph = [];
    _maxTrendAmount = 0;

    if (_trendPeriod == 'monthly') {
      final year = currentDate.year;
      final month = currentDate.month;
      final daysInMonth = DateTime(year, month + 1, 0).day;
      final mTrans = transactions.where((t) {
        final tDate = DateTime.fromMillisecondsSinceEpoch(t.date);
        return tDate.month == month && tDate.year == year;
      }).toList();
      
      for (int i = 1; i <= daysInMonth; i++) {
        final dayTrans = mTrans.where((t) => DateTime.fromMillisecondsSinceEpoch(t.date).day == i).toList();
        final tExp = dayTrans.where((t) => t.type == 'expense').fold(0.0, (a, c) => a + c.amount);
        final tInc = dayTrans.where((t) => t.type == 'income').fold(0.0, (a, c) => a + c.amount);
        final tTotal = _analysisType == 'expense' ? tExp : tInc;
        if (tTotal > _maxTrendAmount) _maxTrendAmount = tTotal;
        _trendGraph.add({'label': "${DateFormat('MMM').format(DateTime(year, month))} ${i.toString().padLeft(2, '0')}", 'total': tTotal});
      }
    } else if (_trendPeriod == 'yearly') {
      final year = currentDate.year;
      for (int m = 1; m <= 12; m++) {
        final mTrans = transactions.where((t) {
          final tDate = DateTime.fromMillisecondsSinceEpoch(t.date);
          return tDate.month == m && tDate.year == year;
        }).toList();
        final tExp = mTrans.where((t) => t.type == 'expense').fold(0.0, (a, c) => a + c.amount);
        final tInc = mTrans.where((t) => t.type == 'income').fold(0.0, (a, c) => a + c.amount);
        final tTotal = _analysisType == 'expense' ? tExp : tInc;
        if (tTotal > _maxTrendAmount) _maxTrendAmount = tTotal;
        _trendGraph.add({'label': DateFormat('MMM').format(DateTime(year, m)), 'total': tTotal});
      }
    } else {
      if (transactions.isNotEmpty) {
        final years = transactions.map((t) => DateTime.fromMillisecondsSinceEpoch(t.date).year).toSet().toList()..sort();
        for (final y in years) {
          final yTrans = transactions.where((t) => DateTime.fromMillisecondsSinceEpoch(t.date).year == y).toList();
          final tExp = yTrans.where((t) => t.type == 'expense').fold(0.0, (a, c) => a + c.amount);
          final tInc = yTrans.where((t) => t.type == 'income').fold(0.0, (a, c) => a + c.amount);
          final tTotal = _analysisType == 'expense' ? tExp : tInc;
          if (tTotal > _maxTrendAmount) _maxTrendAmount = tTotal;
          _trendGraph.add({'label': y.toString(), 'total': tTotal});
        }
      } else {
        _trendGraph.add({'label': DateTime.now().year.toString(), 'total': 0.0});
      }
    }

    _groupedBarData = [];
    _maxBarAmount = 0;
    for (int i = 5; i >= 0; i--) {
      int y = currentDate.year;
      int m = currentDate.month - i;
      while (m < 1) {
        m += 12;
        y -= 1;
      }
      final d = DateTime(y, m, 1);
      final mName = DateFormat('MMM').format(d);

      final mTrans = transactions.where((t) {
        final tDate = DateTime.fromMillisecondsSinceEpoch(t.date);
        return tDate.month == d.month && tDate.year == d.year;
      }).toList();

      final inc = mTrans.where((t) => t.type == 'income').fold(0.0, (acc, curr) => acc + curr.amount);
      final exp = mTrans.where((t) => t.type == 'expense').fold(0.0, (acc, curr) => acc + curr.amount);

      if (inc > _maxBarAmount) _maxBarAmount = inc;
      if (exp > _maxBarAmount) _maxBarAmount = exp;

      _groupedBarData.add({'label': mName, 'income': inc, 'expense': exp});
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final currency = provider.currency;
    final currentDate = provider.currentDate;

    _calculateAnalyticsData(provider);

    final monthlyBalance = _mIncome - _mExpense;

    return AppBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: ListView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Analytics", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: () {
                      provider.refreshData();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

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
                        // Active days = unique days in selected month with ≥1 transaction
                        final activeDaySet = _monthlyTransactions
                            .map((t) => DateTime.fromMillisecondsSinceEpoch(t.date).day)
                            .toSet();
                        final activeDays = activeDaySet.length;
                        final avgIncome  = activeDays > 0 ? _mIncome  / activeDays : 0.0;
                        final avgExpense = activeDays > 0 ? _mExpense / activeDays : 0.0;
                        final monthLabel = DateFormat('MMM yyyy').format(currentDate);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Avg Income", style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.center,
                              child: Text(
                                "${currency.symbol}${avgIncome.formatIndianCurrency()}",
                                style: const TextStyle(color: Color(0xFF00FE06), fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Divider(color: Colors.white.withValues(alpha: 0.07), height: 1),
                            const SizedBox(height: 24),
                            Text("Avg Expense", style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
                            const SizedBox(height: 4),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.center,
                              child: Text(
                                "${currency.symbol}${avgExpense.formatIndianCurrency()}",
                                style: const TextStyle(color: Color(0xFFFE0000), fontSize: 22, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              activeDays == 0
                                  ? "No activity in $monthLabel"
                                  : "$activeDays active day${activeDays == 1 ? '' : 's'} in $monthLabel",
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 9.5),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Pie Chart", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  GestureDetector(
                    onTap: _toggleAnalysisType,
                    child: Container(
                      width: 60,
                      height: 30,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(15)),
                      child: Stack(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              color: _analysisType == 'expense' ? const Color(0xFFFE0000) : const Color(0xFF00FE06),
                            ),
                          ),
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                            left: _analysisType == 'expense' ? 2.0 : 32.0,
                            top: 2,
                            child: Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(13),
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))],
                              ),
                              alignment: Alignment.center,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 400),
                                child: Icon(
                                  _analysisType == 'expense' ? Icons.arrow_downward : Icons.arrow_upward,
                                  key: ValueKey(_analysisType),
                                  size: 11,
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
              const SizedBox(height: 10),              if (_chartData.isNotEmpty)
                _SolidCard(
                  padding: const EdgeInsets.all(24),
                  borderRadius: 28,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _chartData.map((item) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                children: [
                                  Container(width: 12, height: 12, decoration: BoxDecoration(color: item['color'], borderRadius: BorderRadius.circular(6))),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "${item['name']} ",
                                      style: const TextStyle(color: Colors.white, fontSize: 14),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    "${item['percentage'].toStringAsFixed(1)}%",
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(140, 140),
                              painter: ConcentricRingsPainter(rings: _chartData.toList()),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(40),
                  alignment: Alignment.center,
                  child: Text("No ${_analysisType}s recorded yet.", style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16)),
                ),

              const SizedBox(height: 30),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Trend", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 400),
                          curve: Curves.easeOutQuart,
                          left: _trendPeriod == 'yearly' ? 60.0 : (_trendPeriod == 'alltime' ? 120.0 : 0.0),
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 60,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(17),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            _buildTrendBtn('monthly', 'Month'),
                            _buildTrendBtn('yearly', 'Year'),
                            _buildTrendBtn('alltime', 'All'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              _SolidCard(
                borderRadius: 28,
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                height: 220,
                child: _isCalculatingTrend
                  ? const Center(child: LoadingSpinner())
                  : CustomLineChart(
                  data: _trendGraph,
                  maxAmount: _maxTrendAmount,
                  color: _analysisType == 'expense' ? const Color(0xFFFE0000) : const Color(0xFF00FE06),
                  currencySymbol: currency.symbol,
                  showAllLabels: _trendPeriod != 'monthly',
                  isExpense: _analysisType == 'expense',
                ),
              ),

              const SizedBox(height: 30),
              const Text("Income vs Expense", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              _SolidCard(
                borderRadius: 28,
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
                height: 220,
                child: CustomGroupedBarChart(
                  data: _groupedBarData,
                  maxAmount: _maxBarAmount == 0 ? 100 : _maxBarAmount,
                  currencySymbol: currency.symbol,
                ),
              ),
              
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
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
        width: 60,
        height: 34,
        alignment: Alignment.center,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutQuart,
          style: TextStyle(
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

class _SolidCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double height;

  const _SolidCard({
    required this.child,
    this.borderRadius = 20.0,
    this.padding = const EdgeInsets.all(24.0),
    this.margin = const EdgeInsets.symmetric(vertical: 12.0),
    this.height = double.nan,
  });

  @override
  Widget build(BuildContext context) {
    Widget card = Container(
      height: height.isNaN ? null : height,
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Solid dark background
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: const Color(0xFF1E1E1E),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );

    if (margin != EdgeInsets.zero) {
      card = Padding(padding: margin, child: card);
    }
    return card;
  }
}
