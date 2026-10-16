import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../core/currency_format.dart';
import '../base/base_tile.dart';
import 'transaction_details_dialog.dart';

/// TransactionItem component refactored to extend the OO base BaseListItemWidget.
class TransactionItem extends BaseListItemWidget {
  final TransactionModel transaction;
  final CategoryModel? category;
  final Account? account;
  final Account? toAccount;
  final String? currencySymbol;

  static final TextStyle _frauncesStyle = GoogleFonts.fraunces();

  const TransactionItem({
    super.key,
    required this.transaction,
    this.category,
    this.account,
    this.toAccount,
    this.currencySymbol,
  });

  void _showDetails(BuildContext context) {
    HapticFeedback.lightImpact();
    Account? resolvedAccount = account;
    if (resolvedAccount == null) {
      final provider = Provider.of<AppProvider>(context, listen: false);
      for (final a in provider.accounts) {
        if (a.id == transaction.accountId) {
          resolvedAccount = a;
          break;
        }
      }
    }

    final outerContext = context;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) => TransactionDetailsDialog(
          transaction: transaction,
          parentContext: outerContext,
          category: category,
          account: resolvedAccount,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  BoxDecoration buildDecoration(BuildContext context) {
    return BoxDecoration(
      color: const Color(0xFF121212).withValues(alpha: 0.85),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    );
  }

  @override
  Widget buildLeading(BuildContext context) {
    final isTransfer = transaction.type == 'transfer';
    return Text(
      isTransfer ? '🔄' : (category?.icon ?? '📦'),
      style: const TextStyle(fontSize: 24),
    );
  }

  @override
  Widget buildTitle(BuildContext context) {
    final isTransfer = transaction.type == 'transfer';
    return Text(
      isTransfer ? 'Transfer' : (category?.name ?? 'Transaction'),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget? buildSubtitle(BuildContext context) {
    final isTransfer = transaction.type == 'transfer';
    Account? srcAccount = account;
    Account? dstAccount = toAccount;

    // Fallback if not passed directly from parent list
    if (srcAccount == null || (isTransfer && dstAccount == null && transaction.toAccountId.isNotEmpty)) {
      final provider = Provider.of<AppProvider>(context, listen: false);
      for (final a in provider.accounts) {
        if (srcAccount == null && a.id == transaction.accountId) {
          srcAccount = a;
        }
        if (isTransfer && dstAccount == null && a.id == transaction.toAccountId) {
          dstAccount = a;
        }
      }
    }

    return Text(
      isTransfer
          ? '${srcAccount?.name ?? 'Unknown'} → ${dstAccount?.name ?? 'Unknown'}'
          : (srcAccount?.name ?? 'Unknown Account'),
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.5),
        fontSize: 12,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget? buildTrailing(BuildContext context) {
    final isIncome = transaction.type == 'income';
    final isTransfer = transaction.type == 'transfer';
    final symbol = currencySymbol ?? Provider.of<AppProvider>(context, listen: false).currency.symbol;

    return Text(
      isTransfer
          ? "$symbol${transaction.amount.formatIndianCurrency()}"
          : "${isIncome ? '+' : '-'}$symbol${transaction.amount.formatIndianCurrency()}",
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: isTransfer ? Colors.white : (isIncome ? const Color(0xFF00FE06) : const Color(0xFFFE0000)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = buildSubtitle(context);
    final trailing = buildTrailing(context);

    return GestureDetector(
      onTap: () => _showDetails(context),
      behavior: HitTestBehavior.opaque,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 5),
          decoration: buildDecoration(context),
          padding: const EdgeInsets.all(15),
          child: DefaultTextStyle.merge(
            style: _frauncesStyle,
            child: Row(
              children: [
                buildLeading(context),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      buildTitle(context),
                      const SizedBox(height: 2),
                      ?subtitle,
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 10),
                  trailing,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
