import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../base/base_dialog.dart';
import 'loading_spinner.dart';
import 'validation_dialog.dart';

class ExportReportDialog extends StatefulWidget {
  const ExportReportDialog({super.key});

  @override
  State<ExportReportDialog> createState() => _ExportReportDialogState();
}

class _ExportReportDialogState extends State<ExportReportDialog> {
  late DateTime _startDate;
  late DateTime _endDate;
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = now;
  }

  ThemeData get _pickerTheme => ThemeData.dark().copyWith(
    colorScheme: const ColorScheme.dark(
      primary: Colors.white,
      onPrimary: Colors.black,
      surface: Color(0x661A1A1A),
      onSurface: Colors.white,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Color(0x661A1A1A)),
    textTheme: GoogleFonts.castoroTextTheme(ThemeData.dark().textTheme),
  );

  Future<void> _pickStartDate() async {
    HapticFeedback.lightImpact();
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: _endDate,
      builder: (context, child) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Theme(data: _pickerTheme, child: child!),
      ),
    );
    if (date != null && mounted) {
      setState(() {
        _startDate = date;
      });
    }
  }

  Future<void> _pickEndDate() async {
    HapticFeedback.lightImpact();
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
      builder: (context, child) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Theme(data: _pickerTheme, child: child!),
      ),
    );
    if (date != null && mounted) {
      setState(() {
        _endDate = date;
      });
    }
  }

  Widget _buildCategoryIcons(List<TransactionModel> transactions, List<CategoryModel> allCategories, Color tintColor) {
    final uniqueCatIds = transactions.map((t) => t.categoryId).toSet().toList();
    final iconsToShow = uniqueCatIds.take(3).toList();
    final remainingCount = uniqueCatIds.length - 3;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ...iconsToShow.map((id) {
          final cat = allCategories.firstWhere((c) => c.id == id, orElse: () => CategoryModel(id: '', name: '', icon: '📁', type: ''));
          return Container(
            margin: const EdgeInsets.only(right: 8),
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tintColor.withValues(alpha: 0.2),
              border: Border.all(color: tintColor.withValues(alpha: 0.5)),
            ),
            child: Text(
              cat.icon,
              style: const TextStyle(fontSize: 16),
            ),
          );
        }),
        if (remainingCount > 0)
          Text("+$remainingCount more", style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final endOfDay = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59, 999);
    final filteredTx = provider.transactions.where((tx) {
      final date = DateTime.fromMillisecondsSinceEpoch(tx.date);
      return !date.isBefore(_startDate) && !date.isAfter(endOfDay);
    }).toList();

    final expenses = filteredTx.where((t) => t.type == 'expense').toList();
    final incomes = filteredTx.where((t) => t.type == 'income').toList();
    final expenseCategories = expenses.map((e) => e.categoryId).toSet().length;
    final incomeCategories = incomes.map((e) => e.categoryId).toSet().length;

    return _ExportReportModal(
      startDate: _startDate,
      endDate: _endDate,
      dateFormat: _dateFormat,
      filteredTxCount: filteredTx.length,
      expenses: expenses,
      incomes: incomes,
      expenseCategories: expenseCategories,
      incomeCategories: incomeCategories,
      categories: provider.categories,
      onPickStartDate: _pickStartDate,
      onPickEndDate: _pickEndDate,
      onCategoryIconsBuilder: _buildCategoryIcons,
      onExport: filteredTx.isEmpty
          ? null
          : () async {
              try {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) => const GlassModalDialog(
                    title: 'Exporting...',
                    content: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(width: 24, height: 24, child: LoadingSpinner()),
                        SizedBox(width: 20),
                        Text("Exporting CSV...", style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                );
                await provider.exportTransactionsCSV(startDate: _startDate, endDate: _endDate);
                if (context.mounted) {
                  Navigator.of(context).pop(); // dismiss loading
                  Navigator.of(context).pop(); // dismiss dialog
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.of(context).pop(); // dismiss loading
                  showValidationDialog(context, 'Something went wrong: $e');
                }
              }
            },
    );
  }
}

/// Inner class extending OO BaseModalDialog for Export Modal UI.
class _ExportReportModal extends BaseModalDialog {
  final DateTime startDate;
  final DateTime endDate;
  final DateFormat dateFormat;
  final int filteredTxCount;
  final List<TransactionModel> expenses;
  final List<TransactionModel> incomes;
  final int expenseCategories;
  final int incomeCategories;
  final List<CategoryModel> categories;
  final VoidCallback onPickStartDate;
  final VoidCallback onPickEndDate;
  final Widget Function(List<TransactionModel>, List<CategoryModel>, Color) onCategoryIconsBuilder;
  final VoidCallback? onExport;

  const _ExportReportModal({
    required this.startDate,
    required this.endDate,
    required this.dateFormat,
    required this.filteredTxCount,
    required this.expenses,
    required this.incomes,
    required this.expenseCategories,
    required this.incomeCategories,
    required this.categories,
    required this.onPickStartDate,
    required this.onPickEndDate,
    required this.onCategoryIconsBuilder,
    required this.onExport,
  }) : super(title: 'Export Records');

  @override
  Widget buildDialogContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text("Select the date range you want to export:", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onPickStartDate,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        const Text("From:", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(dateFormat.format(startDate).toUpperCase(), style: const TextStyle(color: Color(0xFFFFB74D), fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
              Container(width: 1, height: 50, color: Colors.white.withValues(alpha: 0.1)),
              Expanded(
                child: GestureDetector(
                  onTap: onPickEndDate,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: [
                        const Text("To:", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(dateFormat.format(endDate).toUpperCase(), style: const TextStyle(color: Color(0xFFFFB74D), fontSize: 15, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text("Export Summary:", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Found a total of $filteredTxCount records within the selected date range.",
                style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
              ),
              if (filteredTxCount > 0) ...[
                const SizedBox(height: 16),
                Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
                const SizedBox(height: 16),
                if (expenses.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.circle, color: Colors.white54, size: 6),
                      const SizedBox(width: 8),
                      Expanded(child: Text("${expenses.length} expense records in $expenseCategories categories.", style: const TextStyle(color: Colors.white, fontSize: 14))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  onCategoryIconsBuilder(expenses, categories, const Color(0xFFFE0000)),
                  const SizedBox(height: 16),
                ],
                if (incomes.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.circle, color: Colors.white54, size: 6),
                      const SizedBox(width: 8),
                      Expanded(child: Text("${incomes.length} income records in $incomeCategories categories.", style: const TextStyle(color: Colors.white, fontSize: 14))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  onCategoryIconsBuilder(incomes, categories, const Color(0xFF00FE06)),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  List<Widget>? buildDialogActions(BuildContext context) {
    return [
      Expanded(
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: onExport,
          child: const Text("EXPORT CSV", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        ),
      ),
    ];
  }
}
