import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../core/currency_format.dart';

/// Item representing a category in an AI query result breakdown.
class AiCategoryBreakdownItem {
  final String categoryId;
  final String name;
  final String icon;
  final double amount;
  final double percentage;
  final Color color;

  const AiCategoryBreakdownItem({
    required this.categoryId,
    required this.name,
    required this.icon,
    required this.amount,
    required this.percentage,
    required this.color,
  });
}

/// Item representing one calendar month in a monthly historical series.
class AiMonthlySummaryItem {
  final String monthLabel;     // e.g. "Aug 2026"
  final double amount;         // actual aggregated value
  final double percentage;     // relative to max month (for bar width)
  final bool isCurrentMonth;   // true if still in progress
  final bool hasData;          // false if no transactions recorded

  const AiMonthlySummaryItem({
    required this.monthLabel,
    required this.amount,
    required this.percentage,
    this.isCurrentMonth = false,
    this.hasData = true,
  });
}

/// The calculated, trusted answer from the AI Financial Assistant.
class AiQueryResult {
  final String query;
  final String title;
  final String heroValue;
  final String? heroSubtitle;
  final Color heroColor;
  final String periodLabel;
  final String? comparisonBadge;
  final bool? comparisonIsPositiveForUser; // e.g. expense drop is good (green), expense jump is red
  final List<AiCategoryBreakdownItem> categoryBreakdown;
  final List<String> insights;
  final List<TransactionModel> matchedTransactions;
  final bool isPrediction;
  final String? predictionNote;
  final bool hasError;
  final String? errorMessage;
  // Monthly historical series fields
  final List<AiMonthlySummaryItem> monthlySeries;
  final bool isMonthlyHistorical;
  final bool isSavingsResult;

  const AiQueryResult({
    required this.query,
    required this.title,
    required this.heroValue,
    this.heroSubtitle,
    required this.heroColor,
    required this.periodLabel,
    this.comparisonBadge,
    this.comparisonIsPositiveForUser,
    this.categoryBreakdown = const [],
    this.insights = const [],
    this.matchedTransactions = const [],
    this.isPrediction = false,
    this.predictionNote,
    this.hasError = false,
    this.errorMessage,
    this.monthlySeries = const [],
    this.isMonthlyHistorical = false,
    this.isSavingsResult = false,
  });

  factory AiQueryResult.error({
    required String query,
    required String message,
  }) {
    return AiQueryResult(
      query: query,
      title: "Could not analyze query",
      heroValue: "No match",
      heroColor: Colors.white70,
      periodLabel: "Please try another question",
      hasError: true,
      errorMessage: message,
    );
  }
}

/// Palette of curated accent colors for category breakdowns.
const List<Color> _categoryColors = [
  Color(0xFF00FE06), // Neon Green
  Color(0xFFFE0000), // Neon Red
  Color(0xFF00BCD4), // Cyan
  Color(0xFFFF9800), // Orange
  Color(0xFFFFEB3B), // Yellow
  Color(0xFF9C27B0), // Purple
  Color(0xFFE91E63), // Pink
  Color(0xFF3F51B5), // Indigo
];

/// Senior Financial AI Assistant engine that performs on-device natural language understanding
/// and calculates exact results from genuine user transaction records.
class FinancialAiAssistant {
  static final List<String> suggestedQuestions = [
    "Monthly expenses",
    "Which category increased?",
    "Food every month",
    "Monthly income",
    "Monthly savings",
    "Predict expenses category-wise",
    "Predict food next month",
    "Today's transactions",
    "Compare months",
    "Biggest expense category",
  ];

  /// Processes user's query and produces an [AiQueryResult] grounded entirely in actual records.
  static AiQueryResult processQuery({
    required String query,
    required List<TransactionModel> transactions,
    required List<CategoryModel> categories,
    required CurrencyModel currency,
    DateTime? referenceDate,
  }) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) {
      return AiQueryResult.error(
        query: query,
        message: "Please enter a question about your money.",
      );
    }

    final now = referenceDate ?? DateTime.now();

    // 1. Month-End Projection (most specific future intent — checked first)
    if (_isMonthEndProjectionQuery(cleanQuery)) {
      return _handleMonthEndProjection(cleanQuery, transactions, categories, currency, now);
    }

    // 2. Monthly Historical Series — "every month", "each month", "last N months"
    //    Must be checked BEFORE prediction to prevent "food every month" → forecast conflict.
    if (_isMonthlyHistoricalQuery(cleanQuery)) {
      return _handleMonthlyHistorical(cleanQuery, transactions, categories, currency, now);
    }

    // 3. Future Prediction / Forecasting Intent ("predict", "forecast", "next month", etc.)
    if (_isPredictionQuery(cleanQuery) || _isCategoryWiseQuery(cleanQuery)) {
      return _handlePrediction(cleanQuery, transactions, categories, currency, now);
    }

    // 4. Category Spending Changes / Delta ("which category spending increased or decreased from last month")
    if (_isCategoryComparisonQuery(cleanQuery)) {
      return _handleCategoryComparison(cleanQuery, transactions, categories, currency, now);
    }

    // 5. Period Comparison ("compare my expenses this month with last month")
    if (_isComparisonQuery(cleanQuery)) {
      return _handleComparison(cleanQuery, transactions, categories, currency, now);
    }

    // 5. Biggest / Top Expense Category
    if (_isBiggestCategoryQuery(cleanQuery)) {
      return _handleBiggestCategory(cleanQuery, transactions, categories, currency, now);
    }

    // 6. Average Daily Spending
    if (_isDailyAverageQuery(cleanQuery)) {
      return _handleDailyAverage(cleanQuery, transactions, categories, currency, now);
    }

    // 7. Transaction Threshold ("transactions above ₹1,000 this month")
    final threshold = _extractAmountThreshold(cleanQuery);
    if (threshold != null) {
      return _handleThresholdQuery(cleanQuery, threshold, transactions, categories, currency, now);
    }

    // 8. Transaction Count Intent
    if (_isTransactionCountQuery(cleanQuery)) {
      return _handleTransactionCount(cleanQuery, transactions, categories, currency, now);
    }

    // 9. Category-Specific Spending ("how much did I spend on food this month")
    final matchedCat = _findMatchingCategory(cleanQuery, categories);
    if (matchedCat != null) {
      return _handleCategorySpending(cleanQuery, matchedCat, transactions, categories, currency, now);
    }

    // 10. Income Intent
    if (_isIncomeQuery(cleanQuery)) {
      return _handleIncome(cleanQuery, transactions, categories, currency, now);
    }

    // 11. Default: Spending / Expense Summary
    return _handleGeneralSpending(cleanQuery, transactions, categories, currency, now);
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Intent Classification Helpers
  // ──────────────────────────────────────────────────────────────────────────

  static bool _isPredictionQuery(String q) {
    // Guard: "every month"/"each month" queries are historical, not forecasts.
    if (_isMonthlyHistoricalQuery(q)) return false;
    return q.contains('predict') ||
        q.contains('prediction') ||
        q.contains('forecast') ||
        q.contains('next month') ||
        q.contains('future') ||
        q.contains('might i spend') ||
        q.contains('will i spend') ||
        q.contains('will spend') ||
        q.contains('estimate') ||
        q.contains('projection') ||
        q.contains('projected') ||
        q.contains('upcoming');
  }

  static bool _isCategoryWiseQuery(String q) {
    if (_isMonthlyHistoricalQuery(q)) return false;
    return q.contains('category wise') ||
        q.contains('category-wise') ||
        q.contains('by category') ||
        q.contains('each category') ||
        q.contains('per category') ||
        q.contains('category breakdown') ||
        q.contains('categories breakdown') ||
        q.contains('breakdown of next month') ||
        q.contains('all categories') ||
        q.contains('across categories');
  }

  static bool _isMonthEndProjectionQuery(String q) {
    return q.contains('end of this month') ||
        q.contains('by the end of') ||
        q.contains('finish this month') ||
        q.contains('month end');
  }

  /// Returns true for queries asking for a historical month-by-month series.
  static bool _isMonthlyHistoricalQuery(String q) {
    return q.contains('every month') ||
        q.contains('each month') ||
        q.contains('month by month') ||
        q.contains('monthly spending') ||
        q.contains('monthly expenses') ||
        q.contains('monthly expenditure') ||
        q.contains('monthly income') ||
        q.contains('monthly savings') ||
        q.contains('monthly breakdown') ||
        q.contains('monthly food') ||
        q.contains('monthly travel') ||
        q.contains('monthly shopping') ||
        q.contains('monthly bills') ||
        q.contains('monthly health') ||
        q.contains('per month') ||
        q.contains('for the last') ||
        q.contains('for the past') ||
        q.contains('over the last') ||
        q.contains('last 3 months') ||
        q.contains('last 6 months') ||
        q.contains('last 12 months') ||
        q.contains('last year') ||
        q.contains('which month') ||
        q.contains('highest month') ||
        q.contains('best month') ||
        q.contains('worst month') ||
        q.contains('average monthly') ||
        q.contains('average per month');
  }

  /// Extracts a month window count from phrases like "last 6 months", "past 3 months".
  /// Returns null if no explicit window found (caller should default to all-time).
  static int? _extractMonthCount(String q) {
    final regex = RegExp(r'(?:last|past|over the last|for the last|for the past)\s*(\d+)\s*month', caseSensitive: false);
    final match = regex.firstMatch(q);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '');
    }
    if (q.contains('last year') || q.contains('this year') || q.contains('past year')) return 12;
    if (q.contains('last 3 months')) return 3;
    if (q.contains('last 6 months')) return 6;
    if (q.contains('last 12 months')) return 12;
    return null;
  }

  /// Returns true if the query is about savings (income minus expenses).
  static bool _isSavingsQuery(String q) {
    return q.contains('save') ||
        q.contains('saved') ||
        q.contains('saving') ||
        q.contains('savings') ||
        q.contains('net savings') ||
        q.contains('how much do i save') ||
        q.contains('cash flow') ||
        q.contains('net income');
  }

  /// Returns true if query asks about category spending changes (increases, decreases, comparisons).
  static bool _isCategoryComparisonQuery(String q) {
    if (_isPredictionQuery(q)) return false;

    // Check for "which category", "what category", "where did i spend"
    if (q.contains('which category') ||
        q.contains('what category') ||
        q.contains('where did i spend') ||
        q.contains('what did i spend') ||
        q.contains('category spending') ||
        q.contains('categories spending')) {
      if (q.contains('increase') ||
          q.contains('increas') ||
          q.contains('decreas') ||
          q.contains('decred') || // user typo
          q.contains('more') ||
          q.contains('less') ||
          q.contains('higher') ||
          q.contains('lower') ||
          q.contains('change') ||
          q.contains('last month') ||
          q.contains('compared') ||
          q.contains('vs') ||
          q.contains('from all last') ||
          q.contains('from last')) {
        return true;
      }
    }

    final hasCategoryWord = q.contains('categor');
    final hasDelta = q.contains('increase') ||
        q.contains('increas') ||
        q.contains('decreas') ||
        q.contains('decred') ||
        q.contains('more') ||
        q.contains('less') ||
        q.contains('higher') ||
        q.contains('lower') ||
        q.contains('change') ||
        q.contains('changed') ||
        q.contains('rose') ||
        q.contains('drop');
    final hasComparison = q.contains('last month') ||
        q.contains('previous month') ||
        q.contains('compared') ||
        q.contains('vs') ||
        q.contains('than last') ||
        q.contains('from all last') ||
        q.contains('from last month') ||
        q.contains('over last month');

    if (hasCategoryWord && (hasDelta || hasComparison)) return true;
    if (hasDelta && hasComparison) return true;

    return false;
  }

  static bool _isComparisonQuery(String q) {
    return q.contains('compare') ||
        q.contains('compared to') ||
        q.contains('vs last month') ||
        q.contains('versus') ||
        q.contains('difference between');
  }

  static bool _isBiggestCategoryQuery(String q) {
    return q.contains('biggest') ||
        q.contains('highest expense') ||
        q.contains('top expense') ||
        q.contains('largest category') ||
        q.contains('where do i spend the most') ||
        q.contains('most spending') ||
        q.contains('most expensive category');
  }

  static bool _isDailyAverageQuery(String q) {
    return q.contains('average daily') ||
        q.contains('daily average') ||
        q.contains('daily spending') ||
        q.contains('spend per day') ||
        q.contains('a day') ||
        q.contains('each day');
  }

  static bool _isTransactionCountQuery(String q) {
    return q.contains('how many') ||
        q.contains('count') ||
        q.contains('number of') ||
        q.contains("today's transactions") ||
        q.contains('transactions today') ||
        q.contains('transactions count');
  }

  static bool _isIncomeQuery(String q) {
    return q.contains('earn') ||
        q.contains('earned') ||
        q.contains('income') ||
        q.contains('salary') ||
        q.contains('revenue') ||
        q.contains('received');
  }

  static double? _extractAmountThreshold(String q) {
    final regex = RegExp(
      r'(?:above|over|more than|greater than|exceeding|>|>=)\s*(?:₹|\$)?\s*([0-9]+(?:,[0-9]+)*(?:\.[0-9]+)?)',
      caseSensitive: false,
    );
    final match = regex.firstMatch(q);
    if (match != null) {
      final raw = match.group(1)?.replaceAll(',', '');
      if (raw != null) return double.tryParse(raw);
    }
    return null;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Date Range Resolver
  // ──────────────────────────────────────────────────────────────────────────

  static _DateRange _resolveDateRange(String q, DateTime now) {
    if (q.contains('today')) {
      final start = DateTime(now.year, now.month, now.day);
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      return _DateRange(start, end, "Today (${DateFormat('MMM dd').format(start)})");
    }

    if (q.contains('yesterday')) {
      final y = now.subtract(const Duration(days: 1));
      final start = DateTime(y.year, y.month, y.day);
      final end = DateTime(y.year, y.month, y.day, 23, 59, 59, 999);
      return _DateRange(start, end, "Yesterday (${DateFormat('MMM dd').format(start)})");
    }

    if (q.contains('this week') || q.contains('current week')) {
      final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
      return _DateRange(monday, end, "This Week (${DateFormat('MMM dd').format(monday)} – ${DateFormat('MMM dd').format(end)})");
    }

    if (q.contains('last week')) {
      final thisMonday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      final lastMonday = thisMonday.subtract(const Duration(days: 7));
      final lastSunday = thisMonday.subtract(const Duration(milliseconds: 1));
      return _DateRange(lastMonday, lastSunday, "Last Week (${DateFormat('MMM dd').format(lastMonday)} – ${DateFormat('MMM dd').format(lastSunday)})");
    }

    if (q.contains('last month') || q.contains('previous month')) {
      final start = DateTime(now.year, now.month - 1, 1);
      final end = DateTime(now.year, now.month, 0, 23, 59, 59, 999);
      return _DateRange(start, end, DateFormat('MMMM yyyy').format(start));
    }

    if (q.contains('this year') || q.contains('current year')) {
      final start = DateTime(now.year, 1, 1);
      final end = DateTime(now.year, 12, 31, 23, 59, 59, 999);
      return _DateRange(start, end, "Year ${now.year}");
    }

    // Default: This month to date
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
    final nowDay = now.day;
    return _DateRange(
      start,
      end,
      "Current month to date (${DateFormat('MMM d').format(start)} – ${DateFormat('MMM d').format(DateTime(now.year, now.month, nowDay))})",
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Category Matching
  // ──────────────────────────────────────────────────────────────────────────

  static CategoryModel? _findMatchingCategory(String q, List<CategoryModel> categories) {
    final lowerQ = q.toLowerCase();

    // 1. Whole-word match with user categories (avoids false substring matches)
    for (var cat in categories) {
      final name = cat.name.trim().toLowerCase();
      if (name.isNotEmpty) {
        final pattern = RegExp(r'\b' + RegExp.escape(name) + r'\b');
        if (pattern.hasMatch(lowerQ)) {
          return cat;
        }
      }
    }

    // 2. Synonyms mapping to common finance categories
    final Map<String, List<String>> synonyms = {
      'food': ['food', 'groceries', 'grocery', 'dining', 'dinner', 'lunch', 'breakfast', 'restaurant', 'cafe', 'swiggy', 'zomato', 'eat', 'snacks', 'meal', 'meals'],
      'travel': ['travel', 'transport', 'commute', 'petrol', 'fuel', 'cab', 'uber', 'ola', 'flight', 'train', 'bus', 'fare', 'trip', 'metro'],
      'shopping': ['shopping', 'clothes', 'clothing', 'amazon', 'flipkart', 'myntra', 'shoes', 'electronics', 'purchase'],
      'bills': ['bills', 'bill', 'utilities', 'electricity', 'rent', 'recharge', 'wifi', 'broadband', 'water', 'gas', 'subscription', 'emi', 'loan'],
      'health': ['health', 'medical', 'medicine', 'doctor', 'hospital', 'pharmacy', 'fitness', 'gym', 'healthcare', 'wellness'],
      'entertainment': ['entertainment', 'movie', 'movies', 'cinema', 'games', 'gaming', 'netflix', 'party', 'outing', 'fun', 'leisure'],
      'education': ['education', 'course', 'books', 'school', 'college', 'tuition', 'study', 'learning'],
      'salary': ['salary', 'salaries', 'paycheck', 'pay', 'wage', 'wages'],
      'freelance': ['freelance', 'freelancing', 'gig', 'side income', 'consulting'],
      'misc': ['misc', 'miscellaneous', 'other', 'random'],
    };

    for (var entry in synonyms.entries) {
      for (var word in entry.value) {
        final pattern = RegExp(r'\b' + RegExp.escape(word) + r'\b');
        if (pattern.hasMatch(lowerQ)) {
          // See if there's a category with this synonym or group name
          for (var cat in categories) {
            final catLower = cat.name.toLowerCase();
            if (catLower.contains(entry.key) || entry.value.any((w) => catLower.contains(w))) {
              return cat;
            }
          }
        }
      }
    }

    return null;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // 11 Core Handler Functions
  // ──────────────────────────────────────────────────────────────────────────

  /// 0. Monthly Historical Series (e.g. "How much did I spend every month?",
  ///    "Food spending each month", "Show monthly savings for the last 6 months")
  static AiQueryResult _handleMonthlyHistorical(
    String query,
    List<TransactionModel> transactions,
    List<CategoryModel> categories,
    CurrencyModel currency,
    DateTime now,
  ) {
    final CategoryModel? matchedCat = _findMatchingCategory(query, categories);
    final isSavings = _isSavingsQuery(query) && !_isIncomeQuery(query);
    final isIncome = !isSavings && _isIncomeQuery(query);
    final String targetType = isSavings
        ? 'all'
        : (isIncome ? 'income' : 'expense');

    // Determine the window size (how many months back to look)
    final windowSize = _extractMonthCount(query); // null = all available

    // ── Build a per-month sum map for expense / income / savings ─────────────
    final Map<String, double> expenseSums = {};
    final Map<String, double> incomeSums = {};

    for (final t in transactions) {
      final d = DateTime.fromMillisecondsSinceEpoch(t.date);
      final key = '${d.year}-${d.month.toString().padLeft(2, '0')}';

      if (t.type == 'expense') {
        if (matchedCat != null && t.categoryId != matchedCat.id) continue;
        expenseSums[key] = (expenseSums[key] ?? 0.0) + t.amount;
      } else if (t.type == 'income') {
        if (!isSavings && matchedCat != null && t.categoryId != matchedCat.id) continue;
        incomeSums[key] = (incomeSums[key] ?? 0.0) + t.amount;
      }
    }

    // Build union of all month keys from both maps
    final allKeys = <String>{...expenseSums.keys, ...incomeSums.keys}.toList()..sort();

    // Trim to window if requested (most recent N months)
    final trimmedKeys = windowSize != null && allKeys.length > windowSize
        ? allKeys.sublist(allKeys.length - windowSize)
        : allKeys;

    if (trimmedKeys.isEmpty) {
      final typeLabel = isSavings ? 'savings' : (isIncome ? 'income' : 'spending');
      return AiQueryResult(
        query: query,
        title: matchedCat != null
            ? '${matchedCat.icon} Monthly ${matchedCat.name} ${isIncome ? "Income" : "Spending"}'
            : 'Monthly ${isSavings ? "Savings" : (isIncome ? "Income" : "Spending")}',
        heroValue: 'No data',
        heroColor: Colors.white70,
        periodLabel: 'No recorded $typeLabel found',
        isMonthlyHistorical: true,
        isSavingsResult: isSavings,
        insights: [
          'No historical $typeLabel records found.',
          'Start recording transactions to see monthly trends.',
        ],
      );
    }

    // Compute per-month amounts
    final Map<String, double> monthAmounts = {};
    for (final k in trimmedKeys) {
      if (isSavings) {
        final inc = incomeSums[k] ?? 0.0;
        final exp = expenseSums[k] ?? 0.0;
        monthAmounts[k] = inc - exp;
      } else if (isIncome) {
        monthAmounts[k] = incomeSums[k] ?? 0.0;
      } else {
        monthAmounts[k] = expenseSums[k] ?? 0.0;
      }
    }

    // Build label helper
    String monthLabel(String key) {
      final parts = key.split('-');
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      return DateFormat('MMM yyyy').format(DateTime(y, m));
    }

    // Current month key
    final curKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    // Stats
    final values = monthAmounts.values.toList();
    final total = values.fold<double>(0.0, (s, v) => s + v);
    final count = values.length;
    final average = count > 0 ? total / count : 0.0;
    final maxAbs = values.map((v) => v.abs()).fold<double>(0.0, (a, b) => b > a ? b : a);

    // Best / worst (for expense: lowest is best; for income/savings: highest is best)
    String? bestMonth;
    String? worstMonth;
    double bestAmt = double.negativeInfinity;
    double worstAmt = double.infinity;

    for (final k in trimmedKeys) {
      final amt = monthAmounts[k]!;
      if (isIncome || isSavings) {
        if (amt > bestAmt) { bestAmt = amt; bestMonth = monthLabel(k); }
        if (amt < worstAmt) { worstAmt = amt; worstMonth = monthLabel(k); }
      } else {
        // expense: highest spending = worst for user
        if (amt > bestAmt) { bestAmt = amt; worstMonth = monthLabel(k); }
        if (amt < worstAmt) { worstAmt = amt; bestMonth = monthLabel(k); }
      }
    }

    // Build AiMonthlySummaryItem list
    final series = <AiMonthlySummaryItem>[];
    for (final k in trimmedKeys) {
      final amt = monthAmounts[k]!;
      final pct = maxAbs > 0 ? (amt.abs() / maxAbs) * 100.0 : 0.0;
      series.add(AiMonthlySummaryItem(
        monthLabel: monthLabel(k),
        amount: amt,
        percentage: pct,
        isCurrentMonth: k == curKey,
        hasData: (expenseSums[k] ?? 0) > 0 || (incomeSums[k] ?? 0) > 0,
      ));
    }

    // Collect matching transactions for drill-down
    final allMatchedTrans = transactions.where((t) {
      final d = DateTime.fromMillisecondsSinceEpoch(t.date);
      final k = '${d.year}-${d.month.toString().padLeft(2, '0')}';
      if (!trimmedKeys.contains(k)) return false;
      if (isSavings) return t.type == 'expense' || t.type == 'income';
      if (t.type != targetType) return false;
      if (matchedCat != null && t.categoryId != matchedCat.id) return false;
      return true;
    }).toList();

    // Insights
    final sym = currency.symbol;
    final typeLabel = isSavings ? 'Savings' : (isIncome ? 'Income' : 'Spending');
    final insights = <String>[
      '${trimmedKeys.length} month${trimmedKeys.length == 1 ? '' : 's'} analyzed',
      'Average: $sym${average.abs().formatIndianCurrency()}/month',
      if (bestMonth != null) 'Lowest spending: $sym${worstAmt.formatIndianCurrency()} ($bestMonth)',
      if (worstMonth != null) '${isIncome || isSavings ? "Best" : "Highest spending"}: $sym${bestAmt.abs().formatIndianCurrency()} ($worstMonth)',
    ];

    // Hero: show average if query mentions "average", else total
    final showAverage = query.contains('average') || query.contains('avg');
    final heroVal = showAverage
        ? '$sym${average.abs().formatIndianCurrency()}/mo avg'
        : (bestAmt >= 0
            ? '$sym${bestAmt.formatIndianCurrency()}'
            : '-$sym${bestAmt.abs().formatIndianCurrency()}');

    final heroColor = isSavings
        ? (bestAmt >= 0 ? const Color(0xFF00FE06) : const Color(0xFFFE0000))
        : (isIncome ? const Color(0xFF00FE06) : const Color(0xFFFE0000));

    final catLabel = matchedCat != null ? '${matchedCat.icon} ${matchedCat.name} ' : '';
    final title = showAverage
        ? 'Average Monthly $catLabel$typeLabel'
        : '${isIncome || isSavings ? "Best" : "Highest"} Month: $catLabel$typeLabel';

    final periodLabel = windowSize != null
        ? 'Last $windowSize months'
        : '${trimmedKeys.length} months of data';

    return AiQueryResult(
      query: query,
      title: title,
      heroValue: heroVal,
      heroSubtitle: 'Best: ${bestMonth ?? '-'} · Worst: ${worstMonth ?? '-'}',
      heroColor: heroColor,
      periodLabel: periodLabel,
      isMonthlyHistorical: true,
      isSavingsResult: isSavings,
      monthlySeries: series,
      insights: insights,
      matchedTransactions: allMatchedTrans,
    );
  }

  /// 1. General spending summary (e.g. "How much did I spend this month?")
  static AiQueryResult _handleGeneralSpending(
    String query,
    List<TransactionModel> transactions,
    List<CategoryModel> categories,
    CurrencyModel currency,
    DateTime now,
  ) {
    final range = _resolveDateRange(query, now);
    final targetTrans = transactions.where((t) {
      if (t.type != 'expense') return false;
      final d = DateTime.fromMillisecondsSinceEpoch(t.date);
      return (d.isAfter(range.start) || d.isAtSameMomentAs(range.start)) &&
          (d.isBefore(range.end) || d.isAtSameMomentAs(range.end));
    }).toList();

    final total = targetTrans.fold<double>(0.0, (sum, t) => sum + t.amount);

    // Calculate previous period for comparison (last month)
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = DateTime(now.year, now.month, 0, 23, 59, 59, 999);
    final lastMonthTotal = transactions.where((t) {
      if (t.type != 'expense') return false;
      final d = DateTime.fromMillisecondsSinceEpoch(t.date);
      return (d.isAfter(lastMonthStart) || d.isAtSameMomentAs(lastMonthStart)) &&
          (d.isBefore(lastMonthEnd) || d.isAtSameMomentAs(lastMonthEnd));
    }).fold<double>(0.0, (sum, t) => sum + t.amount);

    String? comparisonBadge;
    bool? comparisonIsPositiveForUser;
    if (lastMonthTotal > 0 && total > 0) {
      final diffPct = ((total - lastMonthTotal) / lastMonthTotal) * 100;
      final isUp = diffPct > 0;
      comparisonBadge = "${isUp ? '+' : ''}${diffPct.toStringAsFixed(1)}% vs last month";
      // An increase in expenses is marked red (negative for user), drop is green (positive)
      comparisonIsPositiveForUser = !isUp;
    }

    // Build category breakdown
    final breakdown = _buildCategoryBreakdown(targetTrans, total, categories);

    // Calculate active days & daily average
    final activeDays = targetTrans.map((t) {
      final d = DateTime.fromMillisecondsSinceEpoch(t.date);
      return "${d.year}-${d.month}-${d.day}";
    }).toSet().length;

    final dailyAvg = activeDays > 0 ? total / activeDays : (now.day > 0 ? total / now.day : 0.0);

    final insights = <String>[];
    if (activeDays > 0) {
      insights.add("Average daily spending: ${currency.symbol}${dailyAvg.formatIndianCurrency()}");
    }
    insights.add("${targetTrans.length} expense record${targetTrans.length == 1 ? '' : 's'} recorded");
    if (breakdown.isNotEmpty) {
      insights.add("Top category: ${breakdown.first.icon} ${breakdown.first.name} (${breakdown.first.percentage.toStringAsFixed(1)}%)");
    }

    return AiQueryResult(
      query: query,
      title: "Your spending this month",
      heroValue: "${currency.symbol}${total.formatIndianCurrency()}",
      heroColor: const Color(0xFFFE0000),
      periodLabel: "Period: ${range.label}",
      comparisonBadge: comparisonBadge,
      comparisonIsPositiveForUser: comparisonIsPositiveForUser,
      categoryBreakdown: breakdown,
      insights: insights,
      matchedTransactions: targetTrans,
    );
  }

  /// 2. Income summary (e.g. "How much did I earn this month?")
  static AiQueryResult _handleIncome(
    String query,
    List<TransactionModel> transactions,
    List<CategoryModel> categories,
    CurrencyModel currency,
    DateTime now,
  ) {
    final range = _resolveDateRange(query, now);
    final targetTrans = transactions.where((t) {
      if (t.type != 'income') return false;
      final d = DateTime.fromMillisecondsSinceEpoch(t.date);
      return (d.isAfter(range.start) || d.isAtSameMomentAs(range.start)) &&
          (d.isBefore(range.end) || d.isAtSameMomentAs(range.end));
    }).toList();

    final total = targetTrans.fold<double>(0.0, (sum, t) => sum + t.amount);
    final breakdown = _buildCategoryBreakdown(targetTrans, total, categories);

    final insights = <String>[
      "${targetTrans.length} income credit${targetTrans.length == 1 ? '' : 's'} received",
    ];
    if (targetTrans.isNotEmpty) {
      final avgDeposit = total / targetTrans.length;
      insights.add("Average per deposit: ${currency.symbol}${avgDeposit.formatIndianCurrency()}");
    }

    return AiQueryResult(
      query: query,
      title: "Your income this month",
      heroValue: "${currency.symbol}${total.formatIndianCurrency()}",
      heroColor: const Color(0xFF00FE06),
      periodLabel: "Period: ${range.label}",
      categoryBreakdown: breakdown,
      insights: insights,
      matchedTransactions: targetTrans,
    );
  }

  /// 3. Transaction count (e.g. "How many transactions did I make today?")
  static AiQueryResult _handleTransactionCount(
    String query,
    List<TransactionModel> transactions,
    List<CategoryModel> categories,
    CurrencyModel currency,
    DateTime now,
  ) {
    final range = _resolveDateRange(query, now);
    final targetTrans = transactions.where((t) {
      final d = DateTime.fromMillisecondsSinceEpoch(t.date);
      return (d.isAfter(range.start) || d.isAtSameMomentAs(range.start)) &&
          (d.isBefore(range.end) || d.isAtSameMomentAs(range.end));
    }).toList();

    final expenseSum = targetTrans.where((t) => t.type == 'expense').fold<double>(0.0, (s, t) => s + t.amount);
    final incomeSum = targetTrans.where((t) => t.type == 'income').fold<double>(0.0, (s, t) => s + t.amount);

    final insights = <String>[
      "Total spent: ${currency.symbol}${expenseSum.formatIndianCurrency()}",
      if (incomeSum > 0) "Total earned: ${currency.symbol}${incomeSum.formatIndianCurrency()}",
    ];

    return AiQueryResult(
      query: query,
      title: query.contains('today') ? "Today's transactions" : "Transactions in period",
      heroValue: "${targetTrans.length} transaction${targetTrans.length == 1 ? '' : 's'}",
      heroColor: Colors.white,
      periodLabel: "Period: ${range.label}",
      insights: insights,
      matchedTransactions: targetTrans,
    );
  }

  /// 4. Category-specific spending (e.g. "How much did I spend on food this month?")
  static AiQueryResult _handleCategorySpending(
    String query,
    CategoryModel category,
    List<TransactionModel> transactions,
    List<CategoryModel> categories,
    CurrencyModel currency,
    DateTime now,
  ) {
    final range = _resolveDateRange(query, now);
    final targetTrans = transactions.where((t) {
      if (t.categoryId != category.id) return false;
      final d = DateTime.fromMillisecondsSinceEpoch(t.date);
      return (d.isAfter(range.start) || d.isAtSameMomentAs(range.start)) &&
          (d.isBefore(range.end) || d.isAtSameMomentAs(range.end));
    }).toList();

    final catTotal = targetTrans.fold<double>(0.0, (sum, t) => sum + t.amount);

    // Calculate total expenses for percentage of budget
    final allMonthExpense = transactions.where((t) {
      if (t.type != 'expense') return false;
      final d = DateTime.fromMillisecondsSinceEpoch(t.date);
      return (d.isAfter(range.start) || d.isAtSameMomentAs(range.start)) &&
          (d.isBefore(range.end) || d.isAtSameMomentAs(range.end));
    }).fold<double>(0.0, (sum, t) => sum + t.amount);

    final pctOfTotal = allMonthExpense > 0 ? (catTotal / allMonthExpense) * 100 : 0.0;

    final insights = <String>[
      "${category.name} accounts for ${pctOfTotal.toStringAsFixed(1)}% of your expenses",
      "${targetTrans.length} transaction${targetTrans.length == 1 ? '' : 's'} recorded",
    ];

    if (targetTrans.isNotEmpty) {
      final avgPerTx = catTotal / targetTrans.length;
      insights.add("Average per transaction: ${currency.symbol}${avgPerTx.formatIndianCurrency()}");
    }

    return AiQueryResult(
      query: query,
      title: "${category.icon} ${category.name} spending",
      heroValue: "${currency.symbol}${catTotal.formatIndianCurrency()}",
      heroColor: const Color(0xFFFE0000),
      periodLabel: "Period: ${range.label}",
      categoryBreakdown: [
        AiCategoryBreakdownItem(
          categoryId: category.id,
          name: category.name,
          icon: category.icon,
          amount: catTotal,
          percentage: pctOfTotal,
          color: const Color(0xFFFE0000),
        ),
      ],
      insights: insights,
      matchedTransactions: targetTrans,
    );
  }

  /// 4b. Category-level spending changes (e.g. "which category spending has been increased from all last month")
  static AiQueryResult _handleCategoryComparison(
    String query,
    List<TransactionModel> transactions,
    List<CategoryModel> categories,
    CurrencyModel currency,
    DateTime now,
  ) {
    final curStart = DateTime(now.year, now.month, 1);
    final curEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
    final lastStart = DateTime(now.year, now.month - 1, 1);
    final lastEnd = DateTime(now.year, now.month, 0, 23, 59, 59, 999);

    final curMonthName = DateFormat('MMMM').format(curStart);
    final lastMonthName = DateFormat('MMMM').format(lastStart);

    final curTrans = transactions.where((t) {
      if (t.type != 'expense') return false;
      final d = DateTime.fromMillisecondsSinceEpoch(t.date);
      return (d.isAfter(curStart) || d.isAtSameMomentAs(curStart)) && (d.isBefore(curEnd) || d.isAtSameMomentAs(curEnd));
    }).toList();

    final lastTrans = transactions.where((t) {
      if (t.type != 'expense') return false;
      final d = DateTime.fromMillisecondsSinceEpoch(t.date);
      return (d.isAfter(lastStart) || d.isAtSameMomentAs(lastStart)) && (d.isBefore(lastEnd) || d.isAtSameMomentAs(lastEnd));
    }).toList();

    // Sum by category
    final Map<String, double> curCatSums = {};
    for (final t in curTrans) {
      curCatSums[t.categoryId] = (curCatSums[t.categoryId] ?? 0.0) + t.amount;
    }

    final Map<String, double> lastCatSums = {};
    for (final t in lastTrans) {
      lastCatSums[t.categoryId] = (lastCatSums[t.categoryId] ?? 0.0) + t.amount;
    }

    final allCatIds = <String>{...curCatSums.keys, ...lastCatSums.keys};

    if (allCatIds.isEmpty) {
      return AiQueryResult(
        query: query,
        title: "Category Spending Changes",
        heroValue: "No Data",
        heroSubtitle: "No expense records found for $curMonthName or $lastMonthName.",
        heroColor: Colors.white70,
        periodLabel: "$curMonthName vs $lastMonthName",
        insights: const ["No transactions recorded in this period to compare."],
        matchedTransactions: const [],
      );
    }

    final Map<String, CategoryModel> catMap = {for (var c in categories) c.id: c};

    final deltas = allCatIds.map((catId) {
      final cur = curCatSums[catId] ?? 0.0;
      final last = lastCatSums[catId] ?? 0.0;
      final diff = cur - last;
      final pct = last > 0 ? (diff / last) * 100.0 : (cur > 0 ? 100.0 : 0.0);
      final cat = catMap[catId] ?? CategoryModel(id: catId, name: 'Other', icon: '📝', type: 'expense');
      return _CategoryDelta(
        category: cat,
        curAmt: cur,
        lastAmt: last,
        diff: diff,
        pct: pct,
      );
    }).toList();

    final sym = currency.symbol;

    final lowerQ = query.toLowerCase();
    final mentionsIncrease = lowerQ.contains('increase') ||
        lowerQ.contains('increas') ||
        lowerQ.contains('more') ||
        lowerQ.contains('higher') ||
        lowerQ.contains('rose') ||
        lowerQ.contains('rise');
    final mentionsDecrease = lowerQ.contains('decrease') ||
        lowerQ.contains('decreas') ||
        lowerQ.contains('decred') || // user typo
        lowerQ.contains('less') ||
        lowerQ.contains('lower') ||
        lowerQ.contains('drop') ||
        lowerQ.contains('fell') ||
        lowerQ.contains('saved');

    final isIncreaseOnly = mentionsIncrease && !mentionsDecrease;
    final isDecreaseOnly = mentionsDecrease && !mentionsIncrease;

    final increased = deltas.where((d) => d.diff > 0).toList()..sort((a, b) => b.diff.compareTo(a.diff));
    final decreased = deltas.where((d) => d.diff < 0).toList()..sort((a, b) => a.diff.compareTo(b.diff));

    final insights = <String>[];
    String heroValue;
    String heroSubtitle;
    Color heroColor;
    String title;
    String? comparisonBadge;
    bool comparisonIsPositiveForUser;
    List<AiCategoryBreakdownItem> breakdownItems = [];
    List<TransactionModel> matchedTrans = [];

    if (isIncreaseOnly) {
      title = "Categories With Increased Spending";
      if (increased.isEmpty) {
        heroValue = "No Increases";
        heroSubtitle = "Great news! No category spending increased vs $lastMonthName.";
        heroColor = const Color(0xFF00FE06);
        comparisonBadge = null;
        comparisonIsPositiveForUser = true;
        insights.add("All categories stayed flat or decreased compared to $lastMonthName.");
      } else {
        final top = increased.first;
        heroValue = "+$sym${top.diff.formatIndianCurrency()} (+${top.pct.toStringAsFixed(1)}%)";
        heroSubtitle = "${top.category.icon} ${top.category.name} increased most ($sym${top.curAmt.formatIndianCurrency()} vs $sym${top.lastAmt.formatIndianCurrency()})";
        heroColor = const Color(0xFFFE0000);
        comparisonBadge = "+$sym${top.diff.formatIndianCurrency()}";
        comparisonIsPositiveForUser = false;

        insights.add("${increased.length} categor${increased.length == 1 ? 'y' : 'ies'} increased spending vs $lastMonthName:");
        for (final d in increased) {
          if (d.lastAmt == 0) {
            insights.add("${d.category.icon} ${d.category.name}: $sym${d.curAmt.formatIndianCurrency()} · New spending (+100.0%)");
          } else {
            insights.add("${d.category.icon} ${d.category.name}: $sym${d.curAmt.formatIndianCurrency()} (was $sym${d.lastAmt.formatIndianCurrency()}) · Increased by $sym${d.diff.formatIndianCurrency()} (+${d.pct.toStringAsFixed(1)}%)");
          }
        }

        breakdownItems = increased.map((d) {
          return AiCategoryBreakdownItem(
            categoryId: d.category.id,
            name: d.category.name,
            icon: d.category.icon,
            amount: d.diff,
            percentage: d.pct.clamp(0.0, 100.0),
            color: const Color(0xFFFE0000),
          );
        }).toList();

        final incCatIds = increased.map((d) => d.category.id).toSet();
        matchedTrans = curTrans.where((t) => incCatIds.contains(t.categoryId)).toList();
      }
    } else if (isDecreaseOnly) {
      title = "Categories With Decreased Spending";
      if (decreased.isEmpty) {
        heroValue = "No Decreases";
        heroSubtitle = "No category spending decreased vs $lastMonthName.";
        heroColor = Colors.white70;
        comparisonBadge = null;
        comparisonIsPositiveForUser = false;
        insights.add("No categories saw reduced spending compared to $lastMonthName.");
      } else {
        final top = decreased.first;
        heroValue = "-$sym${top.diff.abs().formatIndianCurrency()} (-${top.pct.abs().toStringAsFixed(1)}%)";
        heroSubtitle = "${top.category.icon} ${top.category.name} dropped most ($sym${top.curAmt.formatIndianCurrency()} vs $sym${top.lastAmt.formatIndianCurrency()})";
        heroColor = const Color(0xFF00FE06);
        comparisonBadge = "-$sym${top.diff.abs().formatIndianCurrency()}";
        comparisonIsPositiveForUser = true;

        insights.add("${decreased.length} categor${decreased.length == 1 ? 'y' : 'ies'} reduced spending vs $lastMonthName:");
        for (final d in decreased) {
          if (d.curAmt == 0) {
            insights.add("${d.category.icon} ${d.category.name}: ${sym}0 (was $sym${d.lastAmt.formatIndianCurrency()}) · Avoided spending (-100.0%)");
          } else {
            insights.add("${d.category.icon} ${d.category.name}: $sym${d.curAmt.formatIndianCurrency()} (was $sym${d.lastAmt.formatIndianCurrency()}) · Decreased by $sym${d.diff.abs().formatIndianCurrency()} (-${d.pct.abs().toStringAsFixed(1)}%)");
          }
        }

        breakdownItems = decreased.map((d) {
          return AiCategoryBreakdownItem(
            categoryId: d.category.id,
            name: d.category.name,
            icon: d.category.icon,
            amount: d.diff.abs(),
            percentage: d.pct.abs().clamp(0.0, 100.0),
            color: const Color(0xFF00FE06),
          );
        }).toList();

        final decCatIds = decreased.map((d) => d.category.id).toSet();
        matchedTrans = curTrans.where((t) => decCatIds.contains(t.categoryId)).toList();
      }
    } else {
      // Both / General changes
      title = "Category Spending Changes vs $lastMonthName";
      final topInc = increased.isNotEmpty ? increased.first : null;
      final topDec = decreased.isNotEmpty ? decreased.first : null;

      if (topInc != null && topDec != null) {
        heroValue = "+$sym${topInc.diff.formatIndianCurrency()} (+${topInc.pct.toStringAsFixed(1)}%)";
        heroSubtitle = "Top up: ${topInc.category.icon} ${topInc.category.name} · Top drop: ${topDec.category.icon} ${topDec.category.name} (-$sym${topDec.diff.abs().formatIndianCurrency()})";
        heroColor = topInc.diff.abs() >= topDec.diff.abs() ? const Color(0xFFFE0000) : const Color(0xFF00FE06);
        comparisonBadge = "+$sym${topInc.diff.formatIndianCurrency()}";
        comparisonIsPositiveForUser = false;
      } else if (topInc != null) {
        heroValue = "+$sym${topInc.diff.formatIndianCurrency()} (+${topInc.pct.toStringAsFixed(1)}%)";
        heroSubtitle = "${topInc.category.icon} ${topInc.category.name} increased most vs $lastMonthName";
        heroColor = const Color(0xFFFE0000);
        comparisonBadge = "+$sym${topInc.diff.formatIndianCurrency()}";
        comparisonIsPositiveForUser = false;
      } else if (topDec != null) {
        heroValue = "-$sym${topDec.diff.abs().formatIndianCurrency()} (-${topDec.pct.abs().toStringAsFixed(1)}%)";
        heroSubtitle = "${topDec.category.icon} ${topDec.category.name} decreased most vs $lastMonthName";
        heroColor = const Color(0xFF00FE06);
        comparisonBadge = "-$sym${topDec.diff.abs().formatIndianCurrency()}";
        comparisonIsPositiveForUser = true;
      } else {
        heroValue = "No Changes";
        heroSubtitle = "Category spendings are identical to $lastMonthName.";
        heroColor = Colors.white70;
        comparisonBadge = null;
        comparisonIsPositiveForUser = true;
      }

      insights.add("📊 Summary: ${increased.length} increased, ${decreased.length} decreased vs $lastMonthName.");
      for (final d in increased) {
        if (d.lastAmt == 0) {
          insights.add("${d.category.icon} ${d.category.name}: $sym${d.curAmt.formatIndianCurrency()} · New spending (+100.0%)");
        } else {
          insights.add("${d.category.icon} ${d.category.name}: $sym${d.curAmt.formatIndianCurrency()} (was $sym${d.lastAmt.formatIndianCurrency()}) · Increased by $sym${d.diff.formatIndianCurrency()} (+${d.pct.toStringAsFixed(1)}%)");
        }
      }
      for (final d in decreased) {
        if (d.curAmt == 0) {
          insights.add("${d.category.icon} ${d.category.name}: ${sym}0 (was $sym${d.lastAmt.formatIndianCurrency()}) · Avoided spending (-100.0%)");
        } else {
          insights.add("${d.category.icon} ${d.category.name}: $sym${d.curAmt.formatIndianCurrency()} (was $sym${d.lastAmt.formatIndianCurrency()}) · Decreased by $sym${d.diff.abs().formatIndianCurrency()} (-${d.pct.abs().toStringAsFixed(1)}%)");
        }
      }

      final allChanged = [...increased, ...decreased];
      breakdownItems = allChanged.map((d) {
        return AiCategoryBreakdownItem(
          categoryId: d.category.id,
          name: d.category.name,
          icon: d.category.icon,
          amount: d.diff.abs(),
          percentage: d.pct.abs().clamp(0.0, 100.0),
          color: d.diff > 0 ? const Color(0xFFFE0000) : const Color(0xFF00FE06),
        );
      }).toList();

      matchedTrans = curTrans;
    }

    return AiQueryResult(
      query: query,
      title: title,
      heroValue: heroValue,
      heroSubtitle: heroSubtitle,
      heroColor: heroColor,
      periodLabel: "$curMonthName vs $lastMonthName",
      comparisonBadge: comparisonBadge,
      comparisonIsPositiveForUser: comparisonIsPositiveForUser,
      categoryBreakdown: breakdownItems,
      insights: insights,
      matchedTransactions: matchedTrans,
    );
  }

  /// 5. Period comparison (e.g. "Compare my expenses this month with last month")
  static AiQueryResult _handleComparison(
    String query,
    List<TransactionModel> transactions,
    List<CategoryModel> categories,
    CurrencyModel currency,
    DateTime now,
  ) {
    final curStart = DateTime(now.year, now.month, 1);
    final curEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
    final lastStart = DateTime(now.year, now.month - 1, 1);
    final lastEnd = DateTime(now.year, now.month, 0, 23, 59, 59, 999);

    final curTrans = transactions.where((t) {
      if (t.type != 'expense') return false;
      final d = DateTime.fromMillisecondsSinceEpoch(t.date);
      return (d.isAfter(curStart) || d.isAtSameMomentAs(curStart)) && (d.isBefore(curEnd) || d.isAtSameMomentAs(curEnd));
    }).toList();

    final lastTrans = transactions.where((t) {
      if (t.type != 'expense') return false;
      final d = DateTime.fromMillisecondsSinceEpoch(t.date);
      return (d.isAfter(lastStart) || d.isAtSameMomentAs(lastStart)) && (d.isBefore(lastEnd) || d.isAtSameMomentAs(lastEnd));
    }).toList();

    final curTotal = curTrans.fold<double>(0.0, (s, t) => s + t.amount);
    final lastTotal = lastTrans.fold<double>(0.0, (s, t) => s + t.amount);
    final diff = curTotal - lastTotal;
    final diffPct = lastTotal > 0 ? (diff / lastTotal) * 100 : (curTotal > 0 ? 100.0 : 0.0);

    final curMonthName = DateFormat('MMMM').format(curStart);
    final lastMonthName = DateFormat('MMMM').format(lastStart);

    final isHigher = diff > 0;
    final sign = isHigher ? "+" : "-";

    final insights = <String>[
      "$curMonthName (This month): ${currency.symbol}${curTotal.formatIndianCurrency()}",
      "$lastMonthName (Last month): ${currency.symbol}${lastTotal.formatIndianCurrency()}",
      "Net difference: $sign${currency.symbol}${diff.abs().formatIndianCurrency()} ($sign${diffPct.abs().toStringAsFixed(1)}%)",
    ];

    // Compute top category increase and drop for additional insight
    final Map<String, double> curCatSums = {};
    for (final t in curTrans) {
      curCatSums[t.categoryId] = (curCatSums[t.categoryId] ?? 0.0) + t.amount;
    }
    final Map<String, double> lastCatSums = {};
    for (final t in lastTrans) {
      lastCatSums[t.categoryId] = (lastCatSums[t.categoryId] ?? 0.0) + t.amount;
    }
    final allCatIds = <String>{...curCatSums.keys, ...lastCatSums.keys};
    final catLookup = {for (var c in categories) c.id: c};
    final deltas = allCatIds.map((id) {
      final cur = curCatSums[id] ?? 0.0;
      final last = lastCatSums[id] ?? 0.0;
      final d = cur - last;
      final p = last > 0 ? (d / last) * 100 : (cur > 0 ? 100.0 : 0.0);
      final cat = catLookup[id] ?? CategoryModel(id: id, name: 'Other', icon: '📝', type: 'expense');
      return _CategoryDelta(category: cat, curAmt: cur, lastAmt: last, diff: d, pct: p);
    }).toList();

    final topInc = deltas.where((d) => d.diff > 0).toList()..sort((a, b) => b.diff.compareTo(a.diff));
    final topDec = deltas.where((d) => d.diff < 0).toList()..sort((a, b) => a.diff.compareTo(b.diff));

    if (topInc.isNotEmpty) {
      final t = topInc.first;
      insights.add("Top increase: ${t.category.icon} ${t.category.name} (+${currency.symbol}${t.diff.formatIndianCurrency()}, +${t.pct.toStringAsFixed(1)}%)");
    }
    if (topDec.isNotEmpty) {
      final t = topDec.first;
      insights.add("Top decrease: ${t.category.icon} ${t.category.name} (-${currency.symbol}${t.diff.abs().formatIndianCurrency()}, -${t.pct.abs().toStringAsFixed(1)}%)");
    }

    return AiQueryResult(
      query: query,
      title: "Monthly Expense Comparison",
      heroValue: "$sign${diffPct.abs().toStringAsFixed(1)}%",
      heroSubtitle: isHigher ? "Spending increased vs last month" : "Spending decreased vs last month",
      heroColor: isHigher ? const Color(0xFFFE0000) : const Color(0xFF00FE06),
      periodLabel: "$curMonthName vs $lastMonthName",
      comparisonBadge: "$sign${currency.symbol}${diff.abs().formatIndianCurrency()}",
      comparisonIsPositiveForUser: !isHigher,
      insights: insights,
      matchedTransactions: curTrans,
    );
  }

  /// 6. Biggest / top expense category (e.g. "What is my biggest expense category?")
  static AiQueryResult _handleBiggestCategory(
    String query,
    List<TransactionModel> transactions,
    List<CategoryModel> categories,
    CurrencyModel currency,
    DateTime now,
  ) {
    final range = _resolveDateRange(query, now);
    final targetTrans = transactions.where((t) {
      if (t.type != 'expense') return false;
      final d = DateTime.fromMillisecondsSinceEpoch(t.date);
      return (d.isAfter(range.start) || d.isAtSameMomentAs(range.start)) &&
          (d.isBefore(range.end) || d.isAtSameMomentAs(range.end));
    }).toList();

    final total = targetTrans.fold<double>(0.0, (sum, t) => sum + t.amount);
    final breakdown = _buildCategoryBreakdown(targetTrans, total, categories);

    if (breakdown.isEmpty) {
      return AiQueryResult(
        query: query,
        title: "Biggest Expense Category",
        heroValue: "No expenses",
        heroColor: Colors.white70,
        periodLabel: "Period: ${range.label}",
        insights: const ["No expense records found for this period."],
        matchedTransactions: const [],
      );
    }

    final top = breakdown.first;
    final topTrans = targetTrans.where((t) => t.categoryId == top.categoryId).toList();

    final insights = <String>[
      "Spent: ${currency.symbol}${top.amount.formatIndianCurrency()} (${top.percentage.toStringAsFixed(1)}% of total)",
      "Total overall spending: ${currency.symbol}${total.formatIndianCurrency()}",
      if (breakdown.length > 1) "Runner-up: ${breakdown[1].icon} ${breakdown[1].name} (${currency.symbol}${breakdown[1].amount.formatIndianCurrency()})",
    ];

    return AiQueryResult(
      query: query,
      title: "Top Expense: ${top.name}",
      heroValue: "${top.icon} ${currency.symbol}${top.amount.formatIndianCurrency()}",
      heroSubtitle: "${top.percentage.toStringAsFixed(1)}% of all expenses",
      heroColor: const Color(0xFFFE0000),
      periodLabel: "Period: ${range.label}",
      categoryBreakdown: breakdown,
      insights: insights,
      matchedTransactions: topTrans,
    );
  }

  /// 7. Average daily spending (e.g. "What is my average daily spending?")
  static AiQueryResult _handleDailyAverage(
    String query,
    List<TransactionModel> transactions,
    List<CategoryModel> categories,
    CurrencyModel currency,
    DateTime now,
  ) {
    final range = _resolveDateRange(query, now);
    final inRangeTrans = transactions.where((t) {
      final d = DateTime.fromMillisecondsSinceEpoch(t.date);
      return (d.isAfter(range.start) || d.isAtSameMomentAs(range.start)) &&
          (d.isBefore(range.end) || d.isAtSameMomentAs(range.end));
    }).toList();

    final isBalance = query.contains('balance') || query.contains('net');
    final isIncome = !isBalance && _isIncomeQuery(query);

    final expenseTrans = inRangeTrans.where((t) => t.type == 'expense').toList();
    final incomeTrans = inRangeTrans.where((t) => t.type == 'income').toList();

    final totalExpense = expenseTrans.fold<double>(0.0, (sum, t) => sum + t.amount);
    final totalIncome = incomeTrans.fold<double>(0.0, (sum, t) => sum + t.amount);
    final netTotal = totalIncome - totalExpense;

    final calendarDays = max(1, now.day);
    final activeDaySet = (isIncome ? incomeTrans : (isBalance ? inRangeTrans : expenseTrans)).map((t) {
      final d = DateTime.fromMillisecondsSinceEpoch(t.date);
      return "${d.year}-${d.month}-${d.day}";
    }).toSet();
    final activeDays = activeDaySet.length;

    if (isBalance) {
      final dailyAvgActive = activeDays > 0 ? netTotal / activeDays : 0.0;
      final avgIncActive = activeDays > 0 ? totalIncome / activeDays : 0.0;
      final avgExpActive = activeDays > 0 ? totalExpense / activeDays : 0.0;

      final insights = <String>[
        "Avg daily income: ${currency.symbol}${avgIncActive.formatIndianCurrency()}/day",
        "Avg daily expense: ${currency.symbol}${avgExpActive.formatIndianCurrency()}/day",
        "Net total so far: ${currency.symbol}${netTotal.abs().formatIndianCurrency()}",
      ];

      return AiQueryResult(
        query: query,
        title: "Average Daily Balance",
        heroValue: "${dailyAvgActive < 0 ? '-' : ''}${currency.symbol}${dailyAvgActive.abs().formatIndianCurrency()}/day",
        heroSubtitle: dailyAvgActive >= 0 ? "Positive daily net cash flow" : "Negative daily net cash flow",
        heroColor: dailyAvgActive < 0 ? const Color(0xFFFE0000) : Colors.white,
        periodLabel: "Period: ${range.label}",
        insights: insights,
        matchedTransactions: inRangeTrans,
      );
    } else if (isIncome) {
      final dailyAvgActive = activeDays > 0 ? totalIncome / activeDays : 0.0;
      final insights = <String>[
        "Total earned so far: ${currency.symbol}${totalIncome.formatIndianCurrency()}",
        "Active earning days: $activeDays of $calendarDays elapsed days",
      ];

      return AiQueryResult(
        query: query,
        title: "Average Daily Income",
        heroValue: "${currency.symbol}${dailyAvgActive.formatIndianCurrency()}/day",
        heroSubtitle: "Based on $activeDays active earning days",
        heroColor: const Color(0xFF00FE06),
        periodLabel: "Period: ${range.label}",
        insights: insights,
        matchedTransactions: incomeTrans,
      );
    } else {
      final dailyAvgActive = activeDays > 0 ? totalExpense / activeDays : 0.0;
      final dailyAvgCalendar = totalExpense / calendarDays;

      final insights = <String>[
        "Total spent so far: ${currency.symbol}${totalExpense.formatIndianCurrency()}",
        "Active spending days: $activeDays of $calendarDays elapsed days",
        "Per calendar day: ${currency.symbol}${dailyAvgCalendar.formatIndianCurrency()}/day",
      ];

      return AiQueryResult(
        query: query,
        title: "Average Daily Spending",
        heroValue: "${currency.symbol}${dailyAvgActive.formatIndianCurrency()}/day",
        heroSubtitle: "Based on $activeDays active spending days",
        heroColor: Colors.white,
        periodLabel: "Period: ${range.label}",
        insights: insights,
        matchedTransactions: expenseTrans,
      );
    }
  }

  /// 8. Transactions above threshold (e.g. "Show transactions above ₹1,000 this month")
  static AiQueryResult _handleThresholdQuery(
    String query,
    double threshold,
    List<TransactionModel> transactions,
    List<CategoryModel> categories,
    CurrencyModel currency,
    DateTime now,
  ) {
    final range = _resolveDateRange(query, now);
    final targetTrans = transactions.where((t) {
      final d = DateTime.fromMillisecondsSinceEpoch(t.date);
      final inRange = (d.isAfter(range.start) || d.isAtSameMomentAs(range.start)) &&
          (d.isBefore(range.end) || d.isAtSameMomentAs(range.end));
      return inRange && t.amount >= threshold;
    }).toList();

    targetTrans.sort((a, b) => b.amount.compareTo(a.amount));
    final total = targetTrans.fold<double>(0.0, (sum, t) => sum + t.amount);

    final insights = <String>[
      "Total value: ${currency.symbol}${total.formatIndianCurrency()}",
      if (targetTrans.isNotEmpty) "Highest: ${currency.symbol}${targetTrans.first.amount.formatIndianCurrency()}",
      "${targetTrans.length} record${targetTrans.length == 1 ? '' : 's'} matching threshold",
    ];

    return AiQueryResult(
      query: query,
      title: "Transactions above ${currency.symbol}${threshold.toInt()}",
      heroValue: "${targetTrans.length} transaction${targetTrans.length == 1 ? '' : 's'}",
      heroColor: Colors.white,
      periodLabel: "Period: ${range.label}",
      insights: insights,
      matchedTransactions: targetTrans,
    );
  }

  /// 9. Future expense/income prediction (e.g. "Predict next month income" or "Predict my food expenses for next month")
  /// 9. Future expense/income prediction (supports overall, category-wise breakdown, or specific category)
  static AiQueryResult _handlePrediction(
    String query,
    List<TransactionModel> transactions,
    List<CategoryModel> categories,
    CurrencyModel currency,
    DateTime now,
  ) {
    CategoryModel? matchedCat = _findMatchingCategory(query, categories);
    final isCategoryWise = _isCategoryWiseQuery(query);

    // If query asks for "category wise" without explicitly naming a specific category,
    // ensure matchedCat is null so we produce the multi-category breakdown
    if (isCategoryWise && matchedCat != null) {
      final mentionsSpecificCat = categories.any((c) =>
          c.name.isNotEmpty &&
          c.name.toLowerCase() != 'category' &&
          c.name.toLowerCase() != 'wise' &&
          RegExp(r'\b' + RegExp.escape(c.name.toLowerCase()) + r'\b').hasMatch(query.toLowerCase()));
      if (!mentionsSpecificCat) {
        matchedCat = null;
      }
    }

    // Determine target type: if category is matched, inherit its type
    final isIncome = matchedCat != null
        ? matchedCat.type == 'income'
        : _isIncomeQuery(query);
    final targetType = matchedCat != null
        ? matchedCat.type
        : (isIncome ? 'income' : 'expense');
    final typeLabel = isIncome ? 'Income' : 'Expenses';

    // Group historical transactions across all past completed months
    final Map<String, double> monthlySums = {};

    for (var t in transactions) {
      if (t.type != targetType) continue;
      if (matchedCat != null && t.categoryId != matchedCat.id) continue;

      final d = DateTime.fromMillisecondsSinceEpoch(t.date);
      // Exclude current month and future dates
      if (d.year > now.year || (d.year == now.year && d.month >= now.month)) {
        continue;
      }

      final key = "${d.year}-${d.month.toString().padLeft(2, '0')}";
      monthlySums[key] = (monthlySums[key] ?? 0.0) + t.amount;
    }

    // Sort chronologically (oldest to newest)
    final sortedKeys = monthlySums.keys.toList()..sort();
    final historicalEntries = sortedKeys
        .map((k) => MapEntry(k, monthlySums[k]!))
        .where((e) => e.value > 0)
        .toList();

    // Next month label
    int nextMonthNum = now.month + 1;
    int nextYearNum = now.year;
    if (nextMonthNum > 12) {
      nextMonthNum = 1;
      nextYearNum += 1;
    }
    final nextMonthDate = DateTime(nextYearNum, nextMonthNum, 1);
    final nextMonthName = DateFormat('MMMM yyyy').format(nextMonthDate);
    final daysInNextMonth = DateTime(nextYearNum, nextMonthNum + 1, 0).day;

    // Current month pacing fallback
    final curStart = DateTime(now.year, now.month, 1);
    final curEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
    final curTrans = transactions.where((t) {
      if (t.type != targetType) return false;
      if (matchedCat != null && t.categoryId != matchedCat.id) return false;
      final d = DateTime.fromMillisecondsSinceEpoch(t.date);
      return (d.isAfter(curStart) || d.isAtSameMomentAs(curStart)) && (d.isBefore(curEnd) || d.isAtSameMomentAs(curEnd));
    }).toList();

    final curAmount = curTrans.fold<double>(0.0, (s, t) => s + t.amount);

    if (historicalEntries.isEmpty) {
      if (curAmount > 0 && now.day > 0) {
        final dailyPace = curAmount / now.day;
        final roughEstimate = dailyPace * daysInNextMonth;

        final insights = <String>[
          "Pacing from current month: ${currency.symbol}${dailyPace.formatIndianCurrency()}/day",
          "Current month $typeLabel to date: ${currency.symbol}${curAmount.formatIndianCurrency()}",
          if (matchedCat != null) "Category: ${matchedCat.icon} ${matchedCat.name}",
        ];

        return AiQueryResult(
          query: query,
          title: matchedCat != null ? "${matchedCat.icon} Predicted ${matchedCat.name} $typeLabel" : "Predicted $typeLabel for $nextMonthName",
          heroValue: "~${currency.symbol}${roughEstimate.formatIndianCurrency()}",
          heroSubtitle: "Preliminary estimate based on current pacing",
          heroColor: isIncome ? const Color(0xFF00FE06) : const Color(0xFFFF9800),
          periodLabel: "Forecast for $nextMonthName",
          isPrediction: true,
          predictionNote: "Notice: No past completed months recorded yet for this criteria. Projection is based on current month's pacing.",
          insights: insights,
          matchedTransactions: curTrans,
        );
      } else {
        return AiQueryResult(
          query: query,
          title: matchedCat != null ? "${matchedCat.icon} ${matchedCat.name} Forecast Unavailable" : "$typeLabel Forecast Unavailable",
          heroValue: "Insufficient Data",
          heroSubtitle: matchedCat != null ? "No recorded transactions found for ${matchedCat.name}" : "Need recorded transactions to predict",
          heroColor: Colors.white70,
          periodLabel: "Forecast for $nextMonthName",
          isPrediction: true,
          predictionNote: "Statistical forecasting requires historical records over billing cycles. Once you record transactions, AI forecasts will activate.",
          insights: [
            "No historical ${typeLabel.toLowerCase()} records found${matchedCat != null ? ' for ${matchedCat.name}' : ''}.",
            "Record at least one transaction to unlock projections.",
          ],
        );
      }
    }

    // Historical calculations
    final totalAllTime = historicalEntries.fold<double>(0.0, (sum, e) => sum + e.value);
    final allTimeAvg = totalAllTime / historicalEntries.length;

    double forecastAvg = 0;
    double forecastLow = 0;
    double forecastHigh = 0;
    final insights = <String>[];

    if (historicalEntries.length >= 2) {
      double weightedSum = 0;
      double weightTotal = 0;
      for (int i = 0; i < historicalEntries.length; i++) {
        final weight = (i + 1).toDouble();
        weightedSum += historicalEntries[i].value * weight;
        weightTotal += weight;
      }
      forecastAvg = weightedSum / weightTotal;

      double varianceSum = 0;
      for (var e in historicalEntries) {
        final diff = e.value - allTimeAvg;
        varianceSum += diff * diff;
      }
      final stdDev = sqrt(varianceSum / historicalEntries.length);
      forecastLow = max(0.0, forecastAvg - (0.5 * stdDev));
      forecastHigh = forecastAvg + (0.5 * stdDev);

      insights.add("Expected range: ${currency.symbol}${forecastLow.formatIndianCurrency()} – ${currency.symbol}${forecastHigh.formatIndianCurrency()}");
      insights.add("Historical basis: All ${historicalEntries.length} past recorded months analyzed");
      insights.add("All-time monthly average: ${currency.symbol}${allTimeAvg.formatIndianCurrency()}/mo");

      if (historicalEntries.length >= 3) {
        final diffFromBaseline = ((forecastAvg - allTimeAvg) / allTimeAvg) * 100;
        final sign = diffFromBaseline >= 0 ? "+" : "";
        insights.add("Recent trajectory: $sign${diffFromBaseline.toStringAsFixed(1)}% vs your long-term baseline");
      }
    } else {
      // Exactly 1 historical completed month
      forecastAvg = historicalEntries.first.value;
      forecastLow = forecastAvg * 0.85;
      forecastHigh = forecastAvg * 1.15;
      insights.add("Expected range: ${currency.symbol}${forecastLow.formatIndianCurrency()} – ${currency.symbol}${forecastHigh.formatIndianCurrency()}");
      insights.add("Historical basis: 1 past completed month (${historicalEntries.first.key})");
    }

    // Build Category-Wise Breakdown when matchedCat is null
    final categoryBreakdown = <AiCategoryBreakdownItem>[];

    if (matchedCat == null) {
      final targetCategories = categories.where((c) => c.type == targetType).toList();

      for (int idx = 0; idx < targetCategories.length; idx++) {
        final cat = targetCategories[idx];
        final Map<String, double> catMonthlySums = {};
        for (var t in transactions) {
          if (t.type != targetType || t.categoryId != cat.id) continue;
          final d = DateTime.fromMillisecondsSinceEpoch(t.date);
          if (d.year > now.year || (d.year == now.year && d.month >= now.month)) continue;
          final key = "${d.year}-${d.month.toString().padLeft(2, '0')}";
          catMonthlySums[key] = (catMonthlySums[key] ?? 0.0) + t.amount;
        }

        final catEntries = (catMonthlySums.keys.toList()..sort())
            .map((k) => catMonthlySums[k]!)
            .where((v) => v > 0)
            .toList();

        double catForecast = 0.0;
        if (catEntries.length >= 2) {
          double wSum = 0;
          double wTot = 0;
          for (int i = 0; i < catEntries.length; i++) {
            final w = (i + 1).toDouble();
            wSum += catEntries[i] * w;
            wTot += w;
          }
          catForecast = wSum / wTot;
        } else if (catEntries.length == 1) {
          catForecast = catEntries.first;
        } else {
          // Check current month pacing
          final catCur = transactions.where((t) {
            if (t.type != targetType || t.categoryId != cat.id) return false;
            final d = DateTime.fromMillisecondsSinceEpoch(t.date);
            return (d.isAfter(curStart) || d.isAtSameMomentAs(curStart)) && (d.isBefore(curEnd) || d.isAtSameMomentAs(curEnd));
          }).fold<double>(0.0, (s, t) => s + t.amount);

          if (catCur > 0 && now.day > 0) {
            catForecast = (catCur / now.day) * daysInNextMonth;
          }
        }

        if (catForecast > 0) {
          categoryBreakdown.add(
            AiCategoryBreakdownItem(
              categoryId: cat.id,
              name: cat.name,
              icon: cat.icon.isNotEmpty ? cat.icon : '🏷️',
              amount: catForecast,
              percentage: 0.0,
              color: _categoryColors[idx % _categoryColors.length],
            ),
          );
        }
      }

      categoryBreakdown.sort((a, b) => b.amount.compareTo(a.amount));
      final catTotalSum = categoryBreakdown.fold<double>(0.0, (s, c) => s + c.amount);

      if (catTotalSum > 0) {
        for (int i = 0; i < categoryBreakdown.length; i++) {
          final item = categoryBreakdown[i];
          final pct = (item.amount / catTotalSum) * 100;
          categoryBreakdown[i] = AiCategoryBreakdownItem(
            categoryId: item.categoryId,
            name: item.name,
            icon: item.icon,
            amount: item.amount,
            percentage: pct,
            color: item.color,
          );
        }
      }
    }

    // Contextual Titles & Subtitles
    final String title;
    final String heroSubtitle;
    final String note;

    if (matchedCat != null) {
      title = "${matchedCat.icon} Predicted ${matchedCat.name} $typeLabel";
      heroSubtitle = "Estimated range: ${currency.symbol}${forecastLow.toInt()} – ${currency.symbol}${forecastHigh.toInt()}";
      note = "Statistical forecast for ${matchedCat.name} synthesized across your transaction history (${historicalEntries.length} completed months).";

      // Compute category share of overall spending
      final totalHistoricalOverall = transactions.where((t) {
        if (t.type != targetType) return false;
        final d = DateTime.fromMillisecondsSinceEpoch(t.date);
        return d.year < now.year || (d.year == now.year && d.month < now.month);
      }).fold<double>(0.0, (s, t) => s + t.amount);

      if (totalHistoricalOverall > 0) {
        final share = (totalAllTime / totalHistoricalOverall) * 100;
        insights.add("Accounts for ~${share.toStringAsFixed(1)}% of your overall monthly ${typeLabel.toLowerCase()}");
      }
    } else if (isCategoryWise) {
      title = "Predicted $typeLabel by Category";
      heroSubtitle = "Category breakdown forecast for $nextMonthName";
      note = "Category-wise forecast modeling historical spending distributions across ${categoryBreakdown.length} active categories for $nextMonthName.";
      if (categoryBreakdown.isNotEmpty) {
        insights.insert(0, "Top projected category: ${categoryBreakdown.first.icon} ${categoryBreakdown.first.name} (~${currency.symbol}${categoryBreakdown.first.amount.formatIndianCurrency()})");
      }
    } else {
      title = "Predicted $typeLabel for $nextMonthName";
      heroSubtitle = "Estimated range: ${currency.symbol}${forecastLow.toInt()} – ${currency.symbol}${forecastHigh.toInt()}";
      note = "Statistical forecast synthesized across your entire transaction history (${historicalEntries.length} completed months), combining long-term baseline stability with recent recency weighting.";
      if (categoryBreakdown.isNotEmpty) {
        insights.add("Top projected category: ${categoryBreakdown.first.icon} ${categoryBreakdown.first.name} (${categoryBreakdown.first.percentage.toStringAsFixed(1)}%)");
      }
    }

    return AiQueryResult(
      query: query,
      title: title,
      heroValue: "~${currency.symbol}${forecastAvg.formatIndianCurrency()}",
      heroSubtitle: heroSubtitle,
      heroColor: isIncome ? const Color(0xFF00FE06) : Colors.white,
      periodLabel: "Forecast for $nextMonthName",
      isPrediction: true,
      predictionNote: note,
      categoryBreakdown: categoryBreakdown,
      insights: insights,
      matchedTransactions: transactions.where((t) {
        if (t.type != targetType) return false;
        if (matchedCat != null && t.categoryId != matchedCat.id) return false;
        return true;
      }).toList(),
    );
  }

  /// 10. Month-end projection ("How much will I spend by the end of this month?" or "How much will I spend on food by end of this month?")
  static AiQueryResult _handleMonthEndProjection(
    String query,
    List<TransactionModel> transactions,
    List<CategoryModel> categories,
    CurrencyModel currency,
    DateTime now,
  ) {
    final matchedCat = _findMatchingCategory(query, categories);
    final isIncome = matchedCat != null
        ? matchedCat.type == 'income'
        : _isIncomeQuery(query);
    final targetType = matchedCat != null
        ? matchedCat.type
        : (isIncome ? 'income' : 'expense');
    final typeLabel = isIncome ? 'Income' : 'Spending';

    final curStart = DateTime(now.year, now.month, 1);
    final curEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysElapsed = max(1, now.day);
    final remainingDays = daysInMonth - daysElapsed;

    final targetTrans = transactions.where((t) {
      if (t.type != targetType) return false;
      if (matchedCat != null && t.categoryId != matchedCat.id) return false;
      final d = DateTime.fromMillisecondsSinceEpoch(t.date);
      return (d.isAfter(curStart) || d.isAtSameMomentAs(curStart)) && (d.isBefore(curEnd) || d.isAtSameMomentAs(curEnd));
    }).toList();

    final totalAmount = targetTrans.fold<double>(0.0, (s, t) => s + t.amount);
    final currentDailyPace = totalAmount / daysElapsed;

    // Collect ALL historical completed months for this category (or overall)
    final Map<String, double> historicalMonthlySums = {};
    for (var t in transactions) {
      if (t.type != targetType) continue;
      if (matchedCat != null && t.categoryId != matchedCat.id) continue;
      final d = DateTime.fromMillisecondsSinceEpoch(t.date);
      if (d.year > now.year || (d.year == now.year && d.month >= now.month)) continue;
      final key = "${d.year}-${d.month.toString().padLeft(2, '0')}";
      historicalMonthlySums[key] = (historicalMonthlySums[key] ?? 0.0) + t.amount;
    }

    final double projectedMonthEnd;
    final String subtitle;
    final String note;
    final monthName = DateFormat('MMMM').format(curStart);
    final insights = <String>[
      "${isIncome ? 'Earned' : 'Spent'} so far: ${currency.symbol}${totalAmount.formatIndianCurrency()} (Day $daysElapsed of $daysInMonth)",
      "Current daily pace: ${currency.symbol}${currentDailyPace.formatIndianCurrency()}/day",
      "Remaining days: $remainingDays days left in $monthName",
    ];

    if (historicalMonthlySums.isNotEmpty) {
      final totalHistorical = historicalMonthlySums.values.fold<double>(0.0, (s, a) => s + a);
      final histMonthlyAvg = totalHistorical / historicalMonthlySums.length;
      final histDailyPace = histMonthlyAvg / daysInMonth;

      final currentWeight = daysElapsed / daysInMonth;
      final histWeight = 1.0 - currentWeight;
      final blendedRemainingDaily = (currentDailyPace * currentWeight) + (histDailyPace * histWeight);
      projectedMonthEnd = totalAmount + (blendedRemainingDaily * remainingDays);

      subtitle = "Blended pace using ${historicalMonthlySums.length} past months (${currency.symbol}${blendedRemainingDaily.toInt()}/day)";
      note = matchedCat != null
          ? "Forecast balances current ${matchedCat.name} pacing (${(currentWeight * 100).toInt()}%) with your all-time average across ${historicalMonthlySums.length} past months (${(histWeight * 100).toInt()}%)."
          : "Forecast balances current pacing (${(currentWeight * 100).toInt()}%) with your all-time average across ${historicalMonthlySums.length} past months (${(histWeight * 100).toInt()}%).";
      insights.add("All-time monthly average: ${currency.symbol}${histMonthlyAvg.formatIndianCurrency()}/mo");
    } else {
      projectedMonthEnd = totalAmount + (currentDailyPace * remainingDays);
      subtitle = "At current pace of ${currency.symbol}${currentDailyPace.toInt()}/day";
      note = "Based on linear run-rate pacing of your ${matchedCat != null ? matchedCat.name : typeLabel.toLowerCase()} through day $daysElapsed of $daysInMonth.";
    }

    final title = matchedCat != null
        ? "${matchedCat.icon} Projected ${matchedCat.name} $typeLabel for $monthName"
        : "Projected $monthName Total $typeLabel";

    return AiQueryResult(
      query: query,
      title: title,
      heroValue: "~${currency.symbol}${projectedMonthEnd.formatIndianCurrency()}",
      heroSubtitle: subtitle,
      heroColor: isIncome ? const Color(0xFF00FE06) : const Color(0xFFFE0000),
      periodLabel: "Month-end pacing forecast",
      isPrediction: true,
      predictionNote: note,
      insights: insights,
      matchedTransactions: targetTrans,
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Helper: Build Category Breakdown List
  // ──────────────────────────────────────────────────────────────────────────

  static List<AiCategoryBreakdownItem> _buildCategoryBreakdown(
    List<TransactionModel> targetTransactions,
    double totalAmount,
    List<CategoryModel> categories,
  ) {
    if (targetTransactions.isEmpty || totalAmount <= 0) return [];

    final Map<String, double> categorySums = {};
    for (var t in targetTransactions) {
      final catId = t.categoryId.isEmpty ? 'unknown' : t.categoryId;
      categorySums[catId] = (categorySums[catId] ?? 0.0) + t.amount;
    }

    final catLookup = {for (var c in categories) c.id: c};
    final sortedKeys = categorySums.keys.toList()..sort((a, b) => categorySums[b]!.compareTo(categorySums[a]!));

    final List<AiCategoryBreakdownItem> breakdown = [];
    for (int i = 0; i < sortedKeys.length; i++) {
      final catId = sortedKeys[i];
      final amt = categorySums[catId]!;
      final cat = catLookup[catId] ?? CategoryModel(id: '', name: 'Uncategorized', icon: '📦', type: '');
      final pct = (amt / totalAmount) * 100;
      final color = _categoryColors[i % _categoryColors.length];

      breakdown.add(AiCategoryBreakdownItem(
        categoryId: catId,
        name: cat.name,
        icon: cat.icon,
        amount: amt,
        percentage: pct,
        color: color,
      ));
    }

    return breakdown;
  }
}

class _DateRange {
  final DateTime start;
  final DateTime end;
  final String label;

  _DateRange(this.start, this.end, this.label);
}

class _CategoryDelta {
  final CategoryModel category;
  final double curAmt;
  final double lastAmt;
  final double diff;
  final double pct;

  const _CategoryDelta({
    required this.category,
    required this.curAmt,
    required this.lastAmt,
    required this.diff,
    required this.pct,
  });
}

