import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import 'dropdown_selector.dart';
import 'validation_dialog.dart';

class AddTransactionForm extends StatefulWidget {
  final VoidCallback? onComplete;
  final TransactionModel? existingTransaction;

  const AddTransactionForm({super.key, this.onComplete, this.existingTransaction});

  @override
  State<AddTransactionForm> createState() => _AddTransactionFormState();
}

class _AddTransactionFormState extends State<AddTransactionForm> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String _type = 'expense';
  Account? _selectedAccount;
  Account? _selectedToAccount;
  CategoryModel? _selectedCategory;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.existingTransaction != null) {
      final tx = widget.existingTransaction!;
      String cleanText = tx.amount.toString().replaceAll(RegExp(r'\.0$'), '');
      List<String> parts = cleanText.split('.');
      String intPart = parts[0];
      String decPart = parts.length > 1 ? '.${parts[1]}' : '';
      final number = int.tryParse(intPart);
      if (number != null) {
        intPart = NumberFormat.decimalPattern('en_IN').format(number);
      }
      _amountController.text = intPart + decPart;
      
      _noteController.text = tx.note;
      _type = tx.type;
      _selectedDate = DateTime.fromMillisecondsSinceEpoch(tx.date);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<AppProvider>(context, listen: false);
      if (widget.existingTransaction != null) {
        final tx = widget.existingTransaction!;
        setState(() {
          try {
            _selectedAccount = provider.accounts.firstWhere((a) => a.id == tx.accountId);
          } catch (_) {}
          try {
            _selectedCategory = provider.categories.firstWhere((c) => c.id == tx.categoryId);
          } catch (_) {}
        });
      } else if (provider.accounts.isNotEmpty) {
        setState(() {
          _selectedAccount = provider.accounts.first;
          if (provider.accounts.length > 1) {
            _selectedToAccount = provider.accounts[1];
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    HapticFeedback.lightImpact();
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Theme(
            data: ThemeData.dark().copyWith(
              colorScheme: const ColorScheme.dark(
                primary: Colors.white,
                onPrimary: Colors.black,
                surface: Color(0x661A1A1A), // Translucent black for glass
                onSurface: Colors.white,
              ),
              dialogTheme: const DialogThemeData(backgroundColor: Color(0x661A1A1A)),
              textTheme: GoogleFonts.castoroTextTheme(ThemeData.dark().textTheme),
            ),
            child: child!,
          ),
        );
      },
    );
    if (date != null) {
      if (!mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
        builder: (context, child) {
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Theme(
              data: ThemeData.dark().copyWith(
                colorScheme: const ColorScheme.dark(
                  primary: Colors.white,
                  onPrimary: Colors.black,
                  surface: Color(0x661A1A1A),
                  onSurface: Colors.white,
                ),
                dialogTheme: const DialogThemeData(backgroundColor: Color(0x661A1A1A)),
                textTheme: GoogleFonts.castoroTextTheme(ThemeData.dark().textTheme),
              ),
              child: child!,
            ),
          );
        },
      );
      if (time != null) {
        setState(() {
          _selectedDate = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  void _setType(String type) {
    if (_type == type) return;
    HapticFeedback.lightImpact();
    setState(() {
      _type = type;
      _selectedCategory = null;
    });
  }

  Future<void> _handleSave() async {
    HapticFeedback.mediumImpact();
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      showValidationDialog(context, 'Please enter an amount.');
      return;
    }

    if (_selectedAccount == null) {
      showValidationDialog(context, 'Please select ${_type == 'transfer' ? 'a source' : 'an'} account.');
      return;
    }

    if (_type == 'transfer') {
      if (_selectedToAccount == null) {
        showValidationDialog(context, 'Please select a destination account.');
        return;
      }
      if (_selectedAccount!.id == _selectedToAccount!.id) {
        showValidationDialog(context, 'Source and destination accounts must be different.');
        return;
      }
    } else {
      if (_selectedCategory == null) {
        showValidationDialog(context, 'Please select a category.');
        return;
      }
    }

    final value = double.tryParse(amountText.replaceAll(',', ''));
    if (value == null) {
      showValidationDialog(context, 'Invalid amount entered.');
      return;
    }

    final provider = Provider.of<AppProvider>(context, listen: false);
    
    try {
      final transaction = TransactionModel(
        id: widget.existingTransaction?.id ?? '',
        amount: value,
        type: _type,
        categoryId: _type == 'transfer' ? '' : (_selectedCategory?.id ?? ''),
        accountId: _selectedAccount!.id,
        toAccountId: _type == 'transfer' ? _selectedToAccount!.id : '',
        note: _noteController.text.trim().isEmpty && _type == 'transfer' 
            ? 'Transfer to ${_selectedToAccount!.name}' 
            : _noteController.text.trim(),
        date: _selectedDate.millisecondsSinceEpoch,
      );

      widget.onComplete?.call();

      if (widget.existingTransaction != null) {
        provider.updateTransaction(widget.existingTransaction!, transaction);
      } else {
        provider.addTransaction(transaction);
      }
      
      if (mounted) {
        _amountController.clear();
        _noteController.clear();
        setState(() {
          _selectedCategory = null;
          _selectedToAccount = null;
        });
      }
    } catch (error) {
      if (!mounted) return;
      showValidationDialog(context, error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final filteredCategories = provider.categories.where((c) => c.type == _type).toList();
    final hasAmount = _amountController.text.isNotEmpty;

    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(left: 24, right: 24, bottom: 10),
      child: Column(
        children: [
          // Hero Amount
          Container(
            alignment: Alignment.center,
            margin: const EdgeInsets.only(bottom: 10),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      provider.currency.symbol,
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w300,
                        color: hasAmount ? Colors.white : Colors.white.withValues(alpha: 0.3),
                        // fontFamily: 'Castoro',
                      ),
                    ),
                    IntrinsicWidth(
                      child: TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [IndianCurrencyFormatter()],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w300,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText: _amountController.text.isEmpty ? '0.00' : '',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (val) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.1),
                  width: double.infinity,
                ),
              ],
            ),
          ),

          // Type Toggle
          Container(
            width: double.infinity,
            height: 50,
            margin: const EdgeInsets.only(bottom: 15),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double toggleWidth = constraints.maxWidth;
                final double pillWidth = (toggleWidth - 6) / 3;
                
                double leftPos = 3.0;
                if (_type == 'income') {
                  leftPos = 3.0 + pillWidth;
                } else if (_type == 'transfer') {
                  leftPos = 3.0 + pillWidth * 2;
                }

                return Stack(
                  children: [
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutQuart,
                      left: leftPos,
                      top: 3,
                      child: Container(
                        width: pillWidth,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                    Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _setType('expense'),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutQuart,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _type == 'expense' ? Colors.black : Colors.white,
                            ),
                            child: const Text('Expense'),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _setType('income'),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutQuart,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _type == 'income' ? Colors.black : Colors.white,
                            ),
                            child: const Text('Income'),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _setType('transfer'),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutQuart,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _type == 'transfer' ? Colors.black : Colors.white,
                            ),
                            child: const Text('Transfer'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),

          // Note
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: Column(
              children: [
                TextField(
                  controller: _noteController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    // fontFamily: 'Castoro',
                  ),
                  decoration: InputDecoration(
                    hintText: 'Add a note...',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.1),
                  width: double.infinity,
                ),
              ],
            ),
          ),

          // Dropdowns
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            child: Column(
              children: [
                DropdownSelector<Account>(
                  label: _type == 'transfer' ? 'FROM' : 'ACCOUNT',
                  items: provider.accounts,
                  selectedItem: _selectedAccount,
                  onSelect: (acc) => setState(() => _selectedAccount = acc),
                  placeholder: 'Select account',
                  getName: (acc) => acc.name,
                  getId: (acc) => acc.id,
                ),
                if (_type == 'transfer')
                  DropdownSelector<Account>(
                    label: 'TO',
                    items: provider.accounts,
                    selectedItem: _selectedToAccount,
                    onSelect: (acc) => setState(() => _selectedToAccount = acc),
                    placeholder: 'Select destination account',
                    getName: (acc) => acc.name,
                    getId: (acc) => acc.id,
                  )
                else
                  DropdownSelector<CategoryModel>(
                    label: 'CATEGORY',
                    items: filteredCategories,
                    selectedItem: _selectedCategory,
                    onSelect: (cat) => setState(() => _selectedCategory = cat),
                    placeholder: 'Select category',
                    getName: (cat) => cat.name,
                    getIcon: (cat) => cat.icon,
                    getId: (cat) => cat.id,
                  ),
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6, left: 4),
                        child: Text(
                          'DATE & TIME',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _pickDateTime,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Colors.white70, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                DateFormat('MMM dd, yyyy - hh:mm a').format(_selectedDate),
                                style: const TextStyle(color: Colors.white, fontSize: 15),
                              ),
                              const Spacer(),
                              Icon(Icons.keyboard_arrow_down, color: Colors.white.withValues(alpha: 0.4), size: 16),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Save Button
          GestureDetector(
            onTap: _handleSave,
            child: Container(
              width: 220,
              height: 50,
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(35),
              ),
              alignment: Alignment.center,
              child: Text(
                _type == 'transfer' ? 'Transfer' : 'Save',
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  // fontFamily: 'Castoro',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class IndianCurrencyFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) {
      return newValue;
    }
    
    String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9.]'), '');
    
    if (cleanText.contains('.')) {
      List<String> parts = cleanText.split('.');
      cleanText = '${parts[0]}.${parts.sublist(1).join()}';
    }
    
    List<String> parts = cleanText.split('.');
    String intPart = parts[0];
    String decPart = parts.length > 1 ? '.${parts[1]}' : '';
    
    if (intPart.isNotEmpty) {
      final number = int.tryParse(intPart);
      if (number != null) {
        intPart = NumberFormat.decimalPattern('en_IN').format(number);
      }
    }
    
    if (newValue.text.endsWith('.') && decPart.isEmpty) {
      decPart = '.';
    }
    
    String formatted = intPart + decPart;
    
    int cursorOffset = newValue.selection.end;
    if (formatted == newValue.text) {
      return newValue;
    }
    
    cursorOffset = formatted.length;
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursorOffset),
    );
  }
}

