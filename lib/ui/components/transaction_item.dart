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

  const TransactionItem({
    super.key,
    required this.transaction,
    this.category,
  });

  void _showDetails(BuildContext context) {
    HapticFeedback.lightImpact();
    final provider = Provider.of<AppProvider>(context, listen: false);
    Account? account;
    try {
      account = provider.accounts.firstWhere((a) => a.id == transaction.accountId);
    } catch (_) {}

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
          account: account,
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
    final provider = Provider.of<AppProvider>(context, listen: false);
    final isTransfer = transaction.type == 'transfer';
    Account? account;
    Account? toAccount;
    try {
      account = provider.accounts.firstWhere((a) => a.id == transaction.accountId);
      if (isTransfer && transaction.toAccountId.isNotEmpty) {
        toAccount = provider.accounts.firstWhere((a) => a.id == transaction.toAccountId);
      }
    } catch (_) {}

    return Text(
      isTransfer
          ? '${account?.name ?? 'Unknown'} → ${toAccount?.name ?? 'Unknown'}'
          : (account?.name ?? 'Unknown Account'),
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.5),
        fontSize: 12,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget? buildTrailing(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final currency = provider.currency;
    final isIncome = transaction.type == 'income';
    final isTransfer = transaction.type == 'transfer';

    return Text(
      isTransfer
          ? "${currency.symbol}${transaction.amount.formatIndianCurrency()}"
          : "${isIncome ? '+' : '-'}${currency.symbol}${transaction.amount.formatIndianCurrency()}",
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
            style: GoogleFonts.fraunces(),
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
