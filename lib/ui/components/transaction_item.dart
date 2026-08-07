import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../core/currency_format.dart';
import 'transaction_details_dialog.dart';

class TransactionItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final currency = provider.currency;
    final isIncome = transaction.type == 'income';
    final isTransfer = transaction.type == 'transfer';
    
    Account? account;
    Account? toAccount;
    try {
      account = provider.accounts.firstWhere((a) => a.id == transaction.accountId);
      if (isTransfer && transaction.toAccountId.isNotEmpty) {
        toAccount = provider.accounts.firstWhere((a) => a.id == transaction.toAccountId);
      }
    } catch (_) {}

    return GestureDetector(
      onTap: () => _showDetails(context),
      behavior: HitTestBehavior.opaque,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
            margin: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E), // Greyish black
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      isTransfer ? '🔄' : (category?.icon ?? '📦'),
                      style: const TextStyle(fontSize: 24),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isTransfer ? 'Transfer' : (category?.name ?? 'Transaction'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isTransfer 
                                ? '${account?.name ?? 'Unknown'} → ${toAccount?.name ?? 'Unknown'}'
                                : (account?.name ?? 'Unknown Account'),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                isTransfer 
                    ? "${currency.symbol}${transaction.amount.formatIndianCurrency()}"
                    : "${isIncome ? '+' : '-'}${currency.symbol}${transaction.amount.formatIndianCurrency()}",
                style: TextStyle(
                  fontFamily: 'sans-serif', // Ensures Rupee symbol renders correctly
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isTransfer ? Colors.white : (isIncome ? const Color(0xFF00FE06) : const Color(0xFFFE0000)),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
