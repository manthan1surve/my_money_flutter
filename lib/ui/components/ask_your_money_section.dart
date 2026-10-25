import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import '../../models/models.dart';
import '../../core/currency_format.dart';
import '../../core/theme.dart';
import '../../services/financial_ai_assistant.dart';
import 'loading_spinner.dart';
import 'transaction_details_dialog.dart';

class _AiQueryComputeInput {
  final String query;
  final List<TransactionModel> transactions;
  final List<CategoryModel> categories;
  final CurrencyModel currency;

  const _AiQueryComputeInput({
    required this.query,
    required this.transactions,
    required this.categories,
    required this.currency,
  });
}

AiQueryResult _processAiQueryInBackground(_AiQueryComputeInput input) {
  return FinancialAiAssistant.processQuery(
    query: input.query,
    transactions: input.transactions,
    categories: input.categories,
    currency: input.currency,
  );
}

/// "Ask Your Money" AI-powered financial assistant component embedded in the Analytics page.
class AskYourMoneySection extends StatefulWidget {
  final List<TransactionModel> transactions;
  final List<CategoryModel> categories;
  final List<Account> accounts;
  final CurrencyModel currency;

  const AskYourMoneySection({
    super.key,
    required this.transactions,
    required this.categories,
    required this.accounts,
    required this.currency,
  });

  @override
  State<AskYourMoneySection> createState() => _AskYourMoneySectionState();
}

class _AskYourMoneySectionState extends State<AskYourMoneySection> {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  AiQueryResult? _currentResult;
  String? _activeChip;
  int _activeQuerySeq = 0;

  @override
  void dispose() {
    _queryController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _runQuery(String queryText) async {
    final text = queryText.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    _focusNode.unfocus();

    setState(() {
      _isLoading = true;
      _activeChip = text;
      _queryController.text = text;
    });

    _activeQuerySeq++;
    final currentSeq = _activeQuerySeq;

    try {
      final input = _AiQueryComputeInput(
        query: text,
        transactions: widget.transactions,
        categories: widget.categories,
        currency: widget.currency,
      );

      final result = await compute(_processAiQueryInBackground, input);

      if (mounted && _activeQuerySeq == currentSeq) {
        setState(() {
          _currentResult = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && _activeQuerySeq == currentSeq) {
        setState(() {
          _currentResult = AiQueryResult.error(query: text, message: e.toString());
          _isLoading = false;
        });
      }
    }
  }

  void _clearQuery() {
    HapticFeedback.lightImpact();
    setState(() {
      _queryController.clear();
      _currentResult = null;
      _activeChip = null;
      _isLoading = false;
    });
  }

  void _showTransactionsModal(AiQueryResult result) {
    HapticFeedback.lightImpact();
    final accountMap = {for (var a in widget.accounts) a.id: a};
    final targetTrans = List<TransactionModel>.from(result.matchedTransactions);
    targetTrans.sort((a, b) => b.date.compareTo(a.date));

    final Map<String, List<TransactionModel>> grouped = {};
    for (var t in targetTrans) {
      final dateObj = DateTime.fromMillisecondsSinceEpoch(t.date);
      final dateString = DateFormat('MMM dd, EEEE').format(dateObj);
      grouped.putIfAbsent(dateString, () => []).add(t);
    }

    showDialog(
      context: context,
      builder: (context) {
        bool isNewToOld = true;
        return StatefulBuilder(
          builder: (context, setModalState) {
            for (var key in grouped.keys) {
              grouped[key]!.sort((a, b) => isNewToOld ? b.date.compareTo(a.date) : a.date.compareTo(b.date));
            }
            final sortedKeys = grouped.keys.toList()
              ..sort((a, b) {
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
                                  "${result.title} (${targetTrans.length} records)",
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setModalState(() => isNewToOld = !isNewToOld);
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Row(
                                  children: [
                                    Icon(isNewToOld ? Icons.arrow_downward : Icons.arrow_upward, color: Colors.white, size: 16),
                                    const SizedBox(width: 4),
                                    Text(
                                      isNewToOld ? "NEW TO OLD" : "OLD TO NEW",
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
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
                                  "No matching records found.",
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
                                        final sign = t.type == 'expense' ? '-' : (t.type == 'income' ? '+' : '');
                                        final amountColor = t.type == 'expense'
                                            ? const Color(0xFFFE0000)
                                            : (t.type == 'income' ? const Color(0xFF00FE06) : Colors.white);

                                        return GestureDetector(
                                          onTap: () {
                                            CategoryModel? cat;
                                            try {
                                              cat = widget.categories.firstWhere((c) => c.id == t.categoryId);
                                            } catch (_) {}
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => TransactionDetailsDialog(
                                                transaction: t,
                                                parentContext: context,
                                                category: cat,
                                                account: acc,
                                              ),
                                            );
                                          },
                                          behavior: HitTestBehavior.opaque,
                                          child: Padding(
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
                                                            style: GoogleFonts.fraunces(
                                                              color: Colors.white.withValues(alpha: 0.4),
                                                              fontSize: 16,
                                                              fontStyle: FontStyle.italic,
                                                            ),
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
                                                  "$sign${widget.currency.symbol}${t.amount.formatIndianCurrency()}",
                                                  style: GoogleFonts.inter(color: amountColor, fontSize: 16, fontWeight: FontWeight.w600),
                                                ),
                                              ],
                                            ),
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
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0C1214).withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: [
              Text(
                "Ask Your Money",
                style: GoogleFonts.fraunces(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6366F1).withValues(alpha: 0.25),
                      const Color(0xFF00BCD4).withValues(alpha: 0.25),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF00BCD4).withValues(alpha: 0.4),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFF00BCD4),
                      size: 11,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "AI Assistant",
                      style: GoogleFonts.fraunces(
                        color: const Color(0xFF00BCD4),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_currentResult != null || _queryController.text.isNotEmpty)
                GestureDetector(
                  onTap: _clearQuery,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white70, size: 16),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Search Input Bar
          Container(
            height: 52,
            padding: const EdgeInsets.only(left: 14, right: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: _focusNode.hasFocus
                    ? const Color(0xFF00BCD4).withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.1),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.white54, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _runQuery,
                    style: GoogleFonts.fraunces(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: "Ask anything about your money...",
                      hintStyle: GoogleFonts.fraunces(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_queryController.text.isNotEmpty && !_isLoading)
                  GestureDetector(
                    onTap: () {
                      _queryController.clear();
                      setState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.cancel, color: Colors.white.withValues(alpha: 0.4), size: 18),
                    ),
                  ),
                GestureDetector(
                  onTap: () => _runQuery(_queryController.text),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: LoadingSpinner(size: 18, strokeWidth: 2.2),
                          )
                        : const Icon(Icons.arrow_upward, color: Colors.black, size: 20),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Horizontally Scrollable Suggested Question Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: FinancialAiAssistant.suggestedQuestions.map((q) {
                final isSelected = _activeChip == q;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _runQuery(q),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.1),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getIconForChip(q),
                            size: 13,
                            color: isSelected ? Colors.black : Colors.white70,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            q,
                            style: GoogleFonts.fraunces(
                              color: isSelected ? Colors.black : Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Answer Presentation Card
          AnimatedSize(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            child: _buildAnswerArea(),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerArea() {
    if (_isLoading) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const LoadingSpinner(size: 22, strokeWidth: 2.5),
            const SizedBox(width: 12),
            Text(
              "Analyzing financial records...",
              style: GoogleFonts.fraunces(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final result = _currentResult;
    if (result == null) {
      return const SizedBox.shrink();
    }

    if (result.hasError) {
      return Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: Color(0xFFFF9800), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                result.errorMessage ?? "No matching records found.",
                style: GoogleFonts.fraunces(color: Colors.white70, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Result Header & Dismiss
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: GoogleFonts.fraunces(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.periodLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (result.comparisonBadge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (result.comparisonIsPositiveForUser ?? true)
                        ? const Color(0xFF00FE06).withValues(alpha: 0.15)
                        : const Color(0xFFFE0000).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (result.comparisonIsPositiveForUser ?? true)
                          ? const Color(0xFF00FE06).withValues(alpha: 0.3)
                          : const Color(0xFFFE0000).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    result.comparisonBadge!,
                    style: TextStyle(
                      color: (result.comparisonIsPositiveForUser ?? true)
                          ? const Color(0xFF00FE06)
                          : const Color(0xFFFE0000),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Primary Hero Metric
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                result.heroValue,
                style: GoogleFonts.inter(
                  color: result.heroColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              if (result.isPrediction)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BCD4).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF00BCD4).withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    "ESTIMATE",
                    style: TextStyle(
                      color: Color(0xFF00BCD4),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              if (result.isMonthlyHistorical)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                  ),
                  child: const Text(
                    "HISTORICAL",
                    style: TextStyle(
                      color: Color(0xFF6366F1),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
            ],
          ),

          if (result.heroSubtitle != null) ...[
            const SizedBox(height: 6),
            Text(
              result.heroSubtitle!,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 12,
              ),
            ),
          ],

          // Category Breakdown List
          if (result.categoryBreakdown.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
            const SizedBox(height: 16),
            ...result.categoryBreakdown.take(4).map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(item.icon, style: const TextStyle(fontSize: 15)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          "${widget.currency.symbol}${item.amount.formatIndianCurrency()}",
                          style: GoogleFonts.inter(color: item.color, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            "|",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.2),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          "${item.percentage.toStringAsFixed(1)}%",
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.55),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        height: 6,
                        width: double.infinity,
                        color: Colors.white.withValues(alpha: 0.08),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: (item.percentage / 100).clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: item.color.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          // Monthly Historical Series Bars (same pattern as categoryBreakdown)
          if (result.monthlySeries.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
            const SizedBox(height: 16),
            ...result.monthlySeries.map((item) {
              final barColor = result.isSavingsResult
                  ? (item.amount >= 0 ? const Color(0xFF00FE06) : const Color(0xFFFE0000))
                  : result.heroColor;
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 0),
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                item.monthLabel,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (item.isCurrentMonth) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF9800).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                        color: const Color(0xFFFF9800).withValues(alpha: 0.4)),
                                  ),
                                  child: const Text(
                                    'IN PROGRESS',
                                    style: TextStyle(
                                      color: Color(0xFFFF9800),
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          '${item.amount < 0 ? '-' : ''}${widget.currency.symbol}${item.amount.abs().formatIndianCurrency()}',
                          style: GoogleFonts.inter(
                              color: barColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            "|",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.2),
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          '${item.percentage.toStringAsFixed(0)}%',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        height: 6,
                        width: double.infinity,
                        color: Colors.white.withValues(alpha: 0.08),
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: (item.percentage / 100).clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: barColor.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (result.insights.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.06)),
            const SizedBox(height: 14),
            Text(
              "KEY INSIGHTS",
              style: AppTypography.label,
            ),
            const SizedBox(height: 10),
            ...result.insights.map((note) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(top: 7, right: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.55),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          note,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.56),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],

          // Prediction Disclaimer
          if (result.predictionNote != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF00BCD4).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF00BCD4).withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline, color: Color(0xFF00BCD4), size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.predictionNote!,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // "View Transactions" Action Button
          if (result.matchedTransactions.isNotEmpty) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => _showTransactionsModal(result),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "View ${result.matchedTransactions.length} transaction${result.matchedTransactions.length == 1 ? '' : 's'}",
                      style: GoogleFonts.fraunces(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.arrow_forward, color: Colors.white, size: 14),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  IconData _getIconForChip(String chip) {
    final lower = chip.toLowerCase();
    if (lower.contains('category')) return Icons.pie_chart_outline;
    if (lower.contains('predict')) return Icons.auto_awesome;
    if (lower.contains('expense')) return Icons.account_balance_wallet_outlined;
    if (lower.contains('today')) return Icons.today_outlined;
    if (lower.contains('food')) return Icons.restaurant_outlined;
    if (lower.contains('income')) return Icons.trending_up;
    if (lower.contains('compare')) return Icons.compare_arrows;
    return Icons.search;
  }
}
