import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../components/app_background.dart';
import '../components/blur_button.dart';
import '../components/validation_dialog.dart';
import '../../core/currency_format.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _balanceController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _addAccount(AppProvider provider) async {
    final name = _nameController.text.trim();
    final balanceText = _balanceController.text.trim();

    if (name.isEmpty && balanceText.isEmpty) {
      _showError('Account name and initial balance are required.');
      return;
    }
    if (name.isEmpty) {
      _showError('Account name is required.');
      return;
    }
    if (balanceText.isEmpty) {
      _showError('Initial balance is required.');
      return;
    }

    final balance = double.tryParse(balanceText);
    if (balance == null) {
      _showError('Initial balance must be a valid number.');
      return;
    }

    try {
      provider.addAccount(name, balance);
      _nameController.clear();
      _balanceController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account added successfully!')),
        );
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    showValidationDialog(context, message);
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double animValue = Curves.easeOutQuart.transform(animation.value);
        final double scale = 1.0 + (animValue * 0.04);
        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4 * animValue),
                  blurRadius: 15 * animValue,
                  spreadRadius: 2 * animValue,
                  offset: Offset(0, 8 * animValue),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);

    return AppBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.only(bottom: 20, top: 10),
                child: Text("Accounts", style: AppTypography.screenTitle),
              ),
              
              // Add Account Card
              Container(
                margin: const EdgeInsets.only(bottom: 30),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Column(
                  children: [
                    _buildTextField("Account Name", _nameController, false),
                    const SizedBox(height: 15),
                    _buildTextField("Initial Balance", _balanceController, true),
                    const SizedBox(height: 20),
                    BlurButton(
                      text: "Add Account", 
                      onPressed: () => _addAccount(provider),
                    ),
                  ],
                ),
              ),
              
              Text("Your Accounts", style: AppTypography.sectionTitle),
              const SizedBox(height: 15),
              
              if (provider.accounts.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 20),
                    child: Text("No accounts found.", style: TextStyle(color: Colors.white54)),
                  ),
                )
              else
                ReorderableListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: provider.accounts.length,
                  proxyDecorator: _proxyDecorator,
                  onReorderItem: (oldIndex, newIndex) {
                    final items = List<Account>.from(provider.accounts);
                    final item = items.removeAt(oldIndex);
                    items.insert(newIndex, item);
                    provider.updateAccountsOrder(items);
                  },
                  itemBuilder: (context, index) {
                    final account = provider.accounts[index];
                    final isNegative = account.balance < 0;
                    final formattedBalance = '${isNegative ? '-' : ''}${provider.currency.symbol}${account.balance.abs().formatIndianCurrency()}';
                    return _buildAccountItem(account, formattedBalance, isNegative, provider, index);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller, bool isNumber) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
          contentPadding: const EdgeInsets.all(15),
          border: InputBorder.none,
        ),
      ),
    );
  }
  
  Widget _buildAccountItem(Account account, String balance, bool isNegative, AppProvider provider, int index) {
    return Container(
      key: ValueKey(account.id),
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Icon(
              Icons.drag_handle,
              color: Colors.white.withValues(alpha: 0.3),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              account.name, 
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 95,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isNegative
                          ? const Color(0xFFFE0000).withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isNegative
                            ? const Color(0xFFFE0000).withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Text(
                      balance,
                      style: TextStyle(
                        color: isNegative ? const Color(0xFFFE0000) : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Transform.translate(
                offset: const Offset(5, 0),
                child: Theme(
                data: Theme.of(context).copyWith(
                  cardColor: const Color(0xFF2A2A2A),
                ),
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_vert, color: Colors.white70, size: 20),
                  color: const Color(0xFF2A2A2A),
                  elevation: 8,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  popUpAnimationStyle: AnimationStyle(
                    curve: Curves.easeOut,
                    duration: const Duration(milliseconds: 300),
                  ),
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditAccountDialog(account, provider);
                    } else if (value == 'delete') {
                      _showDeleteConfirmation(account, provider);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Center(child: Text('Edit', style: TextStyle(color: Colors.white))),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Center(child: Text('Delete', style: TextStyle(color: Color(0xFFFE0000)))),
                    ),
                  ],
                ),
              ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditAccountDialog(Account account, AppProvider provider) {
    final TextEditingController nameCtrl = TextEditingController(text: account.name);
    final TextEditingController balanceCtrl = TextEditingController(text: account.balance.toString());

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
          title: const Text('Edit Account', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField("Account Name", nameCtrl, false),
              const SizedBox(height: 15),
              _buildTextField("Balance", balanceCtrl, true),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final balanceText = balanceCtrl.text.trim();
                if (name.isEmpty || balanceText.isEmpty) {
                  _showError('Name and balance cannot be empty.');
                  return;
                }
                final balance = double.tryParse(balanceText);
                if (balance == null) {
                  _showError('Invalid balance amount.');
                  return;
                }
                
                try {
                  provider.updateAccount(account.id, name, balance);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Account updated successfully!')),
                    );
                  }
                } catch (e) {
                  _showError(e.toString());
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(Account account, AppProvider provider) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
          title: const Text('Delete Account', style: TextStyle(color: Colors.white)),
          content: Text('Are you sure you want to delete ${account.name}?', style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () async {
                try {
                  provider.deleteAccount(account.id);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Account deleted successfully!')),
                    );
                  }
                } catch (e) {
                  _showError(e.toString());
                }
              },
              child: const Text('Delete', style: TextStyle(color: Color(0xFFFE0000))),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }
}
