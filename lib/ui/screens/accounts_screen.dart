import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../base/base_screen.dart';
import '../base/base_card.dart';
import '../base/ui_factory.dart';
import '../base/base_dialog.dart';
import '../components/blur_button.dart';
import '../components/validation_dialog.dart';
import '../../core/currency_format.dart';

class AccountsScreen extends BaseScreen {
  const AccountsScreen({super.key});

  @override
  BaseScreenState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends BaseScreenState<AccountsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _balanceController = TextEditingController();

  @override
  bool get hasOwnBackground => false;

  @override
  String? get screenTitle => "Accounts";

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _addAccount(AppProvider provider) async {
    FocusManager.instance.primaryFocus?.unfocus();
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
        showSuccessNotification(
          context,
          'Account "$name" Created',
        );
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
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
  Widget buildBody(BuildContext context) {
    final accounts = context.select((AppProvider p) => p.accounts);
    final currency = context.select((AppProvider p) => p.currency);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SolidCardWidget(
            margin: const EdgeInsets.only(bottom: 30),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Add New Account",
                  style: GoogleFonts.fraunces(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 15),
                _buildTextField("Account Name", _nameController, false),
                const SizedBox(height: 15),
                _buildTextField("Initial Balance", _balanceController, true),
                const SizedBox(height: 20),
                Center(
                  child: BlurButton(
                    text: "Add Account",
                    onPressed: () => _addAccount(context.read<AppProvider>()),
                  ),
                ),
              ],
            ),
          ),

          UIComponentFactory.buildSectionHeader(title: "Your Accounts"),
          const SizedBox(height: 15),

          if (accounts.isEmpty)
            UIComponentFactory.buildEmptyState(
              message: "No accounts found.",
              icon: Icons.account_balance_wallet_outlined,
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: accounts.length,
              proxyDecorator: _proxyDecorator,
              onReorderItem: (oldIndex, newIndex) {
                final provider = context.read<AppProvider>();
                final items = List<Account>.from(accounts);
                final item = items.removeAt(oldIndex);
                items.insert(newIndex, item);
                provider.updateAccountsOrder(items);
              },
              itemBuilder: (context, index) {
                final account = accounts[index];
                final isNegative = account.balance < 0;
                final formattedBalance = '${isNegative ? '-' : ''}${currency.symbol}${account.balance.abs().formatIndianCurrency()}';
                return _AccountItemWidget(
                  key: ValueKey(account.id),
                  account: account,
                  balance: formattedBalance,
                  isNegative: isNegative,
                  index: index,
                  onEdit: () => _showEditAccountDialog(account, context.read<AppProvider>()),
                  onDelete: () {
                    try {
                      context.read<AppProvider>().deleteAccount(account.id);
                      showSuccessNotification(
                        context,
                        'Account "${account.name}" Deleted',
                      );
                    } catch (e) {
                      _showError(e.toString());
                    }
                  },
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTextField(String hint, TextEditingController controller, bool isNumber) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        textAlign: TextAlign.center,
        style: GoogleFonts.fraunces(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.fraunces(color: Colors.white.withValues(alpha: 0.3)),
          contentPadding: const EdgeInsets.all(15),
          border: InputBorder.none,
        ),
      ),
    );
  }

  void _showEditAccountDialog(Account account, AppProvider provider) {
    final TextEditingController nameCtrl = TextEditingController(text: account.name);
    final TextEditingController balanceCtrl = TextEditingController(text: account.balance.toString());

    showSmoothModalDialog(
      context: context,
      builder: (context) {
        return GlassModalDialog(
          title: 'Edit Account',
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
              child: Text('Cancel', style: GoogleFonts.fraunces(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () async {
                FocusManager.instance.primaryFocus?.unfocus();
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
                    showSuccessNotification(
                      context,
                      'Account "$name" Updated',
                    );
                  }
                } catch (e) {
                  _showError(e.toString());
                }
              },
              child: Text('Save', style: GoogleFonts.fraunces(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

}

/// Account list item widget extending OO BaseListItemWidget.
class _AccountItemWidget extends StatefulWidget {
  final Account account;
  final String balance;
  final bool isNegative;
  final int index;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AccountItemWidget({
    super.key,
    required this.account,
    required this.balance,
    required this.isNegative,
    required this.index,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_AccountItemWidget> createState() => _AccountItemWidgetState();
}

class _AccountItemWidgetState extends State<_AccountItemWidget> {
  bool _isDeleteRevealed = false;
  bool _isDismissing = false;

  void _handleRemove() async {
    if (!_isDeleteRevealed || _isDismissing) return;
    setState(() {
      _isDismissing = true;
    });
    await Future.delayed(const Duration(milliseconds: 320));
    if (mounted) {
      widget.onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _isDismissing ? const Offset(-1.3, 0) : Offset.zero,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOutCubic,
      child: AnimatedOpacity(
        opacity: _isDismissing ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeIn,
        child: Stack(
          alignment: Alignment.centerRight,
          children: [
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: AnimatedOpacity(
                opacity: _isDeleteRevealed ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                child: GestureDetector(
                  onTap: _handleRemove,
                  child: Container(
                    width: 125,
                    padding: const EdgeInsets.only(left: 28, right: 18),
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFE0000),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.centerRight,
                    child: Text('Remove', style: GoogleFonts.fraunces(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ),
            AnimatedSlide(
              offset: _isDeleteRevealed ? const Offset(-0.22, 0) : Offset.zero,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFF121212).withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      boxShadow: _isDeleteRevealed
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.45),
                                blurRadius: 12,
                                offset: const Offset(4, 0),
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      children: [
                        ReorderableDragStartListener(
                          index: widget.index,
                          child: Icon(
                            Icons.drag_handle,
                            color: Colors.white.withValues(alpha: 0.3),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            widget.account.name,
                            style: GoogleFonts.fraunces(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.35),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
                                decoration: BoxDecoration(
                                  color: widget.isNegative
                                      ? const Color(0xFFFE0000).withValues(alpha: 0.1)
                                      : Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: widget.isNegative
                                        ? const Color(0xFFFE0000).withValues(alpha: 0.2)
                                        : Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                child: Text(
                                  widget.balance,
                                  style: GoogleFonts.fraunces(
                                    color: widget.isNegative ? const Color(0xFFFE0000) : Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Material(
                              color: Colors.white.withValues(alpha: 0.05),
                              shape: const CircleBorder(),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: widget.onEdit,
                                child: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(Icons.edit_outlined, color: Colors.white70, size: 20),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Material(
                              color: Colors.white.withValues(alpha: 0.05),
                              shape: const CircleBorder(),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _isDeleteRevealed = !_isDeleteRevealed;
                                  });
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Icon(Icons.close, color: Colors.white70, size: 20),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
