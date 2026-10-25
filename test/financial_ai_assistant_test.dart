import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_money_flutter/models/models.dart';
import 'package:my_money_flutter/services/financial_ai_assistant.dart';

void main() {
  group('FinancialAiAssistant Engine Tests', () {
    final currency = CurrencyModel(code: 'INR', symbol: '₹', name: 'Indian Rupee');

    final foodCategory = CategoryModel(id: 'c1', name: 'Food', icon: '🍔', type: 'expense');
    final travelCategory = CategoryModel(id: 'c2', name: 'Travel', icon: '🚕', type: 'expense');
    final salaryCategory = CategoryModel(id: 'c3', name: 'Salary', icon: '💰', type: 'income');
    final categories = [foodCategory, travelCategory, salaryCategory];

    final fixedNow = DateTime(2026, 9, 28, 14, 0, 0);

    final transactions = [
      // September 2026 (this month)
      TransactionModel(
        id: 't1',
        amount: 500.0,
        type: 'expense',
        categoryId: 'c1',
        accountId: 'a1',
        note: 'Lunch with colleagues',
        date: DateTime(2026, 9, 28, 12, 30).millisecondsSinceEpoch, // today
      ),
      TransactionModel(
        id: 't2',
        amount: 2500.0,
        type: 'expense',
        categoryId: 'c1',
        accountId: 'a1',
        note: 'Supermarket grocery',
        date: DateTime(2026, 9, 15, 10, 0).millisecondsSinceEpoch,
      ),
      TransactionModel(
        id: 't3',
        amount: 1200.0,
        type: 'expense',
        categoryId: 'c2',
        accountId: 'a1',
        note: 'Cab ride',
        date: DateTime(2026, 9, 20, 18, 0).millisecondsSinceEpoch,
      ),
      TransactionModel(
        id: 't4',
        amount: 45000.0,
        type: 'income',
        categoryId: 'c3',
        accountId: 'a1',
        note: 'Monthly salary',
        date: DateTime(2026, 9, 1, 9, 0).millisecondsSinceEpoch,
      ),
      // August 2026 (last month)
      TransactionModel(
        id: 't5',
        amount: 2000.0,
        type: 'expense',
        categoryId: 'c1',
        accountId: 'a1',
        note: 'Groceries August',
        date: DateTime(2026, 8, 10).millisecondsSinceEpoch,
      ),
      TransactionModel(
        id: 't6',
        amount: 1000.0,
        type: 'expense',
        categoryId: 'c2',
        accountId: 'a1',
        note: 'Fuel August',
        date: DateTime(2026, 8, 20).millisecondsSinceEpoch,
      ),
      // July 2026 (2 months ago)
      TransactionModel(
        id: 't7',
        amount: 2200.0,
        type: 'expense',
        categoryId: 'c1',
        accountId: 'a1',
        note: 'Groceries July',
        date: DateTime(2026, 7, 12).millisecondsSinceEpoch,
      ),
    ];

    test('1. Total spending this month', () {
      final res = FinancialAiAssistant.processQuery(
        query: 'How much did I spend this month?',
        transactions: transactions,
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      // t1 (500) + t2 (2500) + t3 (1200) = 4200
      expect(res.heroValue, contains('4,200'));
      expect(res.categoryBreakdown.length, 2);
      expect(res.matchedTransactions.length, 3);
      expect(res.isPrediction, isFalse);
    });

    test('2. How many transactions did I make today?', () {
      final res = FinancialAiAssistant.processQuery(
        query: 'How many transactions did I make today?',
        transactions: transactions,
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      // Only t1 is on Sep 28
      expect(res.heroValue, '1 transaction');
      expect(res.matchedTransactions.length, 1);
      expect(res.matchedTransactions.first.id, 't1');
    });

    test('3. How much did I spend on food this month?', () {
      final res = FinancialAiAssistant.processQuery(
        query: 'How much did I spend on food this month?',
        transactions: transactions,
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      // t1 (500) + t2 (2500) = 3000
      expect(res.heroValue, contains('3,000'));
      expect(res.matchedTransactions.length, 2);
      expect(res.title.toLowerCase(), contains('food'));
    });

    test('4. Compare my expenses this month with last month', () {
      final res = FinancialAiAssistant.processQuery(
        query: 'Compare my expenses this month with last month.',
        transactions: transactions,
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      // This month = 4200, Last month = 3000 -> Diff = +1200 (+40.0%)
      expect(res.title, 'Monthly Expense Comparison');
      expect(res.heroValue, contains('+40.0%'));
      expect(res.comparisonBadge, contains('1,200'));
    });

    test('5. What is my biggest expense category?', () {
      final res = FinancialAiAssistant.processQuery(
        query: 'What is my biggest expense category?',
        transactions: transactions,
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      // Food = 3000, Travel = 1200 -> Food is biggest
      expect(res.title, contains('Food'));
      expect(res.heroValue, contains('3,000'));
      expect(res.categoryBreakdown.first.name, 'Food');
    });

    test('6. What is my average daily spending?', () {
      final res = FinancialAiAssistant.processQuery(
        query: 'What is my average daily spending?',
        transactions: transactions,
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      // 4200 across 3 active days = 1400/day
      expect(res.title, 'Average Daily Spending');
      expect(res.heroValue, contains('1,400'));
    });

    test('7. How much did I earn this month?', () {
      final res = FinancialAiAssistant.processQuery(
        query: 'How much did I earn this month?',
        transactions: transactions,
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      expect(res.heroValue, contains('45,000'));
      expect(res.matchedTransactions.length, 1);
    });

    test('8. Show transactions above ₹1,000 this month.', () {
      final res = FinancialAiAssistant.processQuery(
        query: 'Show transactions above ₹1,000 this month.',
        transactions: transactions,
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      // t2 (2500), t3 (1200), t4 (45000) are all >= 1000
      expect(res.matchedTransactions.length, 3);
      expect(res.heroValue, '3 transactions');
    });

    test('9. Predict my food expenses for next month', () {
      final res = FinancialAiAssistant.processQuery(
        query: 'Predict my food expenses for next month',
        transactions: transactions,
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      expect(res.isPrediction, isTrue);
      expect(res.predictionNote, isNotNull);
      expect(res.title, contains('Food'));
    });

    test('10. How much will I spend by the end of this month?', () {
      final res = FinancialAiAssistant.processQuery(
        query: 'How much will I spend by the end of this month?',
        transactions: transactions,
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      expect(res.isPrediction, isTrue);
      expect(res.title, contains('Projected'));
      expect(res.heroValue, startsWith('~₹'));
    });

    test('11. Handles empty dataset gracefully', () {
      final res = FinancialAiAssistant.processQuery(
        query: 'How much did I spend this month?',
        transactions: [],
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      expect(res.heroValue, contains('0.00'));
      expect(res.matchedTransactions, isEmpty);
    });

    test('12. Predict next month income predicts income instead of expenses', () {
      final res = FinancialAiAssistant.processQuery(
        query: 'predict next month income',
        transactions: transactions,
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      expect(res.isPrediction, isTrue);
      expect(res.title.toLowerCase(), contains('income'));
      expect(res.title.toLowerCase(), isNot(contains('expense')));
      expect(res.heroColor, const Color(0xFF00FE06));
      expect(res.matchedTransactions.every((t) => t.type == 'income'), isTrue);
    });

    test('13. Predict expenses category-wise returns full category breakdown', () {
      final res = FinancialAiAssistant.processQuery(
        query: 'Predict expenses category-wise',
        transactions: transactions,
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      expect(res.isPrediction, isTrue);
      expect(res.title.toLowerCase(), contains('category'));
      expect(res.categoryBreakdown, isNotEmpty);
      expect(res.categoryBreakdown.any((c) => c.name.toLowerCase().contains('food')), isTrue);
      expect(res.categoryBreakdown.any((c) => c.name.toLowerCase().contains('travel')), isTrue);
      expect(res.heroValue, startsWith('~₹'));
    });

    test('14. Category-specific prediction for Travel', () {
      final res = FinancialAiAssistant.processQuery(
        query: 'Predict travel expenses for next month',
        transactions: transactions,
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      expect(res.isPrediction, isTrue);
      expect(res.title.toLowerCase(), contains('travel'));
      expect(res.matchedTransactions.every((t) => t.categoryId == travelCategory.id), isTrue);
    });

    test('15. Category-specific prediction for Salary (income category)', () {
      final res = FinancialAiAssistant.processQuery(
        query: 'predict next month salary',
        transactions: transactions,
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      expect(res.isPrediction, isTrue);
      expect(res.title.toLowerCase(), contains('salary'));
      expect(res.heroColor, const Color(0xFF00FE06));
      expect(res.matchedTransactions.every((t) => t.categoryId == salaryCategory.id), isTrue);
    });

    test('16. Short category prediction query: predict food', () {
      final res = FinancialAiAssistant.processQuery(
        query: 'predict food',
        transactions: transactions,
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      expect(res.isPrediction, isTrue);
      expect(res.title.toLowerCase(), contains('food'));
      expect(res.matchedTransactions.every((t) => t.categoryId == foodCategory.id), isTrue);
    });

    test('17. Monthly historical general expenses: How much did I spend every month?', () {
      final res = FinancialAiAssistant.processQuery(
        query: 'How much did I spend every month?',
        transactions: transactions,
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      expect(res.isMonthlyHistorical, isTrue);
      expect(res.isPrediction, isFalse);
      expect(res.monthlySeries.length, greaterThanOrEqualTo(2));
      expect(res.matchedTransactions.length, 6); // t1, t2, t3, t5, t6, t7
      expect(res.matchedTransactions.every((t) => t.type == 'expense'), isTrue);
    });

    test('18. Monthly spending for explicit window: last 3 months', () {
      final res = FinancialAiAssistant.processQuery(
        query: 'Show my monthly spending for the last 3 months',
        transactions: transactions,
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      expect(res.isMonthlyHistorical, isTrue);
      expect(res.monthlySeries.length, 3);
      expect(res.periodLabel, contains('3'));
    });

    test('19. Average monthly expenditure query', () {
      final res = FinancialAiAssistant.processQuery(
        query: 'What is my average monthly expenditure?',
        transactions: transactions,
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      expect(res.isMonthlyHistorical, isTrue);
      expect(res.heroValue.toLowerCase(), contains('avg'));
      expect(res.title.toLowerCase(), contains('average'));
    });

    test('20. Best/worst month query: Which month did I spend the most?', () {
      final res = FinancialAiAssistant.processQuery(
        query: 'Which month did I spend the most?',
        transactions: transactions,
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      expect(res.isMonthlyHistorical, isTrue);
      expect(res.heroSubtitle, contains('Best:'));
      expect(res.heroSubtitle, contains('Worst:'));
    });

    test('21. Category spending every month: How much did I spend on food every month?', () {
      final res = FinancialAiAssistant.processQuery(
        query: 'How much did I spend on food every month?',
        transactions: transactions,
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      expect(res.isMonthlyHistorical, isTrue);
      expect(res.title.toLowerCase(), contains('food'));
      expect(res.matchedTransactions.every((t) => t.categoryId == foodCategory.id), isTrue);
      expect(res.monthlySeries.isNotEmpty, isTrue);
    });

    test('22. Monthly food spending for last 6 months', () {
      final res = FinancialAiAssistant.processQuery(
        query: 'Monthly food spending for last 6 months',
        transactions: transactions,
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      expect(res.isMonthlyHistorical, isTrue);
      expect(res.monthlySeries.length, lessThanOrEqualTo(6));
      expect(res.matchedTransactions.every((t) => t.categoryId == foodCategory.id), isTrue);
    });

    test('23. Monthly travel spending', () {
      final res = FinancialAiAssistant.processQuery(
        query: 'Show my monthly travel spending',
        transactions: transactions,
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      expect(res.isMonthlyHistorical, isTrue);
      expect(res.title.toLowerCase(), contains('travel'));
      expect(res.matchedTransactions.every((t) => t.categoryId == travelCategory.id), isTrue);
    });

    test('24. Monthly income query', () {
      final res = FinancialAiAssistant.processQuery(
        query: 'Show my monthly income',
        transactions: transactions,
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      expect(res.isMonthlyHistorical, isTrue);
      expect(res.heroColor, const Color(0xFF00FE06));
      expect(res.matchedTransactions.every((t) => t.type == 'income'), isTrue);
    });

    test('25. Monthly savings query: How much did I save each month?', () {
      final res = FinancialAiAssistant.processQuery(
        query: 'How much did I save each month?',
        transactions: transactions,
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      expect(res.isMonthlyHistorical, isTrue);
      expect(res.title.toLowerCase(), contains('savings'));
      expect(res.insights, isNotEmpty);
    });

    test('26. Intent Conflict Guard: Food every month -> Historical, not prediction', () {
      final res = FinancialAiAssistant.processQuery(
        query: 'Food every month',
        transactions: transactions,
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      expect(res.isMonthlyHistorical, isTrue);
      expect(res.isPrediction, isFalse);
    });

    test('27. Intent Conflict Guard: Food next month -> Prediction, not historical', () {
      final res = FinancialAiAssistant.processQuery(
        query: 'Food next month',
        transactions: transactions,
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      expect(res.isPrediction, isTrue);
      expect(res.isMonthlyHistorical, isFalse);
    });

    test('28. Monthly historical with vs or comparison', () {
      final res = FinancialAiAssistant.processQuery(
        query: 'monthly spending over the last 3 months',
        transactions: transactions,
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      expect(res.isMonthlyHistorical, isTrue);
      expect(res.monthlySeries.length, 3);
      expect(res.insights, isNotEmpty);
    });

    test('29. Edge Case: Monthly spending with empty transactions list', () {
      final res = FinancialAiAssistant.processQuery(
        query: 'Monthly spending',
        transactions: [],
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      expect(res.isMonthlyHistorical, isTrue);
      expect(res.hasError, isFalse);
      expect(res.monthlySeries.isEmpty, isTrue);
      expect(res.matchedTransactions.isEmpty, isTrue);
    });

    test('30. Edge Case: Empty or blank query returns handled error result', () {
      final res = FinancialAiAssistant.processQuery(
        query: '   ',
        transactions: transactions,
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      expect(res.hasError, isTrue);
      expect(res.errorMessage, isNotEmpty);
    });

    test('31. Which category spending has been increased from all last month', () {
      final res = FinancialAiAssistant.processQuery(
        query: 'Which category spending has been increased from all last month',
        transactions: transactions,
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      // Food: 3000 this month vs 2000 last month -> +1000 (+50.0%)
      // Travel: 1200 this month vs 1000 last month -> +200 (+20.0%)
      expect(res.heroValue, contains('1,000'));
      expect(res.heroValue, contains('50.0%'));
      expect(res.heroSubtitle?.toLowerCase(), contains('food'));
      expect(res.heroColor, const Color(0xFFFE0000));
      expect(res.categoryBreakdown.length, 2);
      expect(res.categoryBreakdown.first.name.toLowerCase(), contains('food'));

      // Verifies amount and percentage are provided in insights
      expect(res.insights.any((i) => i.contains('Food') && i.contains('1,000') && i.contains('50.0%')), isTrue);
      expect(res.insights.any((i) => i.contains('Travel') && i.contains('200') && i.contains('20.0%')), isTrue);
    });

    test('32. Exact query: which category spending has been increased or decred from all last month,it should give amount and even percentage', () {
      final res = FinancialAiAssistant.processQuery(
        query: 'which category spending has been increased or decred from all last month,it should give amount and even percentage',
        transactions: transactions,
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      expect(res.heroValue, contains('1,000'));
      expect(res.heroValue, contains('50.0%'));
      expect(res.categoryBreakdown.isNotEmpty, isTrue);

      // Both amount and percentage are included
      expect(res.insights.any((i) => i.contains('Food') && i.contains('50.0%')), isTrue);
      expect(res.insights.any((i) => i.contains('Travel') && i.contains('20.0%')), isTrue);
    });

    test('33. Category spending decreased with reduced spending dataset', () {
      final modifiedTransactions = [
        ...transactions,
        // Add a big expense in Travel in August so Travel decreased in September
        TransactionModel(
          id: 't_extra_aug',
          amount: 5000.0,
          type: 'expense',
          categoryId: 'c2', // Travel was 6000 in Aug, now 1200 in Sep -> drop of 4800 (-80.0%)
          accountId: 'a1',
          note: 'Flight ticket August',
          date: DateTime(2026, 8, 15).millisecondsSinceEpoch,
        ),
      ];

      final res = FinancialAiAssistant.processQuery(
        query: 'Which category spending decreased from last month',
        transactions: modifiedTransactions,
        categories: categories,
        currency: currency,
        referenceDate: fixedNow,
      );

      expect(res.heroValue, contains('4,800'));
      expect(res.heroValue, contains('80.0%'));
      expect(res.heroSubtitle?.toLowerCase(), contains('travel'));
      expect(res.heroColor, const Color(0xFF00FE06));
      expect(res.insights.any((i) => i.contains('Travel') && i.contains('4,800') && i.contains('80.0%')), isTrue);
    });
  });
}
