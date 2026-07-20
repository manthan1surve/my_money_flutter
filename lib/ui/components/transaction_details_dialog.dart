import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../core/currency_format.dart';
import 'floating_action_button.dart';

class TransactionDetailsDialog extends StatelessWidget {
  final TransactionModel transaction;
  final CategoryModel? category;
  final Account? account;
  final BuildContext parentContext;

  const TransactionDetailsDialog({
    super.key,
    required this.transaction,
    required this.parentContext,
    this.category,
    this.account,
  });

  void _showEditForm(BuildContext context) {
    Navigator.pop(context); // Close the dialog
    // Signal the morphing FAB to expand in edit mode
    FloatingActionButtonMorph.editNotifier.value = transaction;
  }

  void _deleteTransaction(BuildContext context) {
    // Close the transaction details dialog first
    Navigator.pop(context);

    // Show the confirmation dialog over the main screen using parentContext
    showDialog(
      context: parentContext,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(35),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(35),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Delete this record?",
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Are you sure?",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 90,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () => Navigator.pop(dialogContext),
                            child: const Text("NO", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 90,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: () {
                              final provider = Provider.of<AppProvider>(parentContext, listen: false);
                              provider.deleteTransaction(transaction);
                              Navigator.pop(dialogContext);
                            },
                            child: const Text("YES", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final currency = provider.currency;
    final isExpense = transaction.type == 'expense';
    final isTransfer = transaction.type == 'transfer';
    
    Account? toAccount;
    if (isTransfer && transaction.toAccountId.isNotEmpty) {
      try {
        toAccount = provider.accounts.firstWhere((a) => a.id == transaction.toAccountId);
      } catch (_) {}
    }
    
    final amountColor = isTransfer ? Colors.white : (isExpense ? const Color(0xFFFF8A65) : const Color(0xFF81C784));
    final dateStr = DateFormat('MMM dd, yyyy h:mm a').format(DateTime.fromMillisecondsSinceEpoch(transaction.date));
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Material(
        type: MaterialType.transparency,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(35),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(35),
                ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Transform.translate(
                      offset: const Offset(-8, -8),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Transform.translate(
                      offset: const Offset(8, -8),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.white),
                            onPressed: () => _deleteTransaction(context),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: Colors.white),
                            onPressed: () => _showEditForm(context),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  transaction.type.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isTransfer 
                      ? "${currency.symbol}${transaction.amount.formatIndianCurrency()}"
                      : "${isExpense ? '-' : '+'}${currency.symbol}${transaction.amount.formatIndianCurrency()}",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: amountColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  dateStr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                if (isTransfer) ...[
                  _buildDetailRow("From", account?.name ?? 'Unknown', '👛'),
                  const SizedBox(height: 12),
                  _buildDetailRow("To", toAccount?.name ?? 'Unknown', '👛'),
                ] else ...[
                  _buildDetailRow("Account", account?.name ?? 'Unknown', '👛'),
                  const SizedBox(height: 12),
                  _buildDetailRow("Category", category?.name ?? 'Uncategorized', category?.icon ?? '📦'),
                ],
                const SizedBox(height: 16),
                Text(
                  transaction.note.isEmpty ? "No notes" : transaction.note,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, String icon) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
