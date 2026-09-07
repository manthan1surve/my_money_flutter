import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../core/currency_format.dart';
import '../base/base_dialog.dart';
import 'floating_action_button.dart';
import 'validation_dialog.dart';

/// TransactionDetailsDialog refactored to inherit from OO BaseModalDialog.
class TransactionDetailsDialog extends BaseModalDialog {
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
  }) : super(title: 'Record Details', borderRadius: 24.0, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16));

  void _showEditForm(BuildContext context) {
    Navigator.pop(context);
    FloatingActionButtonMorph.editNotifier.value = transaction;
  }

  void _confirmDelete(BuildContext context) {
    final provider = Provider.of<AppProvider>(parentContext, listen: false);
    Navigator.pop(context);

    showSmoothModalDialog(
      context: parentContext,
      builder: (BuildContext dialogContext) {
        return _DeleteConfirmationModal(
          onConfirm: () {
            provider.deleteTransaction(transaction);
            Navigator.pop(dialogContext);
            if (parentContext.mounted) {
              showSuccessNotification(
                parentContext,
                'Record Deleted',
              );
            }
          },
        );
      },
    );
  }

  @override
  Widget buildDialogHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        Text(
          transaction.type.toUpperCase(),
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.white),
              onPressed: () => _confirmDelete(context),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
              onPressed: () => _showEditForm(context),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget buildDialogContent(BuildContext context) {
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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

class _DeleteConfirmationModal extends BaseModalDialog {
  final VoidCallback onConfirm;

  const _DeleteConfirmationModal({
    required this.onConfirm,
  }) : super(title: 'Delete record?');

  @override
  Widget buildDialogContent(BuildContext context) {
    return const Text(
      "Are you sure you want to delete this record?",
      textAlign: TextAlign.center,
      style: TextStyle(color: Colors.white70, fontSize: 16),
    );
  }

  @override
  List<Widget>? buildDialogActions(BuildContext context) {
    return [
      OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        ),
        onPressed: () => Navigator.pop(context),
        child: const Text("NO", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ),
      const SizedBox(width: 16),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        ),
        onPressed: onConfirm,
        child: const Text("YES", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      ),
    ];
  }
}
