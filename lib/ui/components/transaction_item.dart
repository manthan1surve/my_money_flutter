import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../core/currency_format.dart';
import 'transaction_details_dialog.dart';

/// Interactive TransactionItem component that triggers the Transaction Details Dialog
/// on a short long-press (~280ms) with tactile scale and haptic feedback.
class TransactionItem extends StatefulWidget {
  final TransactionModel transaction;
  final CategoryModel? category;
  final Account? account;
  final Account? toAccount;
  final String? currencySymbol;

  const TransactionItem({
    super.key,
    required this.transaction,
    this.category,
    this.account,
    this.toAccount,
    this.currencySymbol,
  });

  @override
  State<TransactionItem> createState() => _TransactionItemState();
}

class _TransactionItemState extends State<TransactionItem> {
  static final TextStyle _frauncesStyle = GoogleFonts.fraunces();
  static const TextStyle _titleStyle = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
  static final TextStyle _subtitleStyle = TextStyle(
    color: Colors.white.withValues(alpha: 0.5),
    fontSize: 12,
  );
  static final TextStyle _amountTransferStyle = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
  static final TextStyle _amountIncomeStyle = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: const Color(0xFF00FE06),
  );
  static final TextStyle _amountExpenseStyle = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: const Color(0xFFFE0000),
  );

  Timer? _pressDownTimer;
  Timer? _longPressTimer;
  bool _isPressed = false;

  @override
  void dispose() {
    _pressDownTimer?.cancel();
    _longPressTimer?.cancel();
    super.dispose();
  }

  void _startShortLongPress(BuildContext context) {
    _pressDownTimer?.cancel();
    _longPressTimer?.cancel();

    // 75ms grace window: if the user drags/swipes to scroll, onTapCancel fires
    // before _pressDownTimer triggers. This completely eliminates false press
    // scale animations and setState churn during scroll flings.
    _pressDownTimer = Timer(const Duration(milliseconds: 75), () {
      if (!mounted) return;
      setState(() => _isPressed = true);
    });

    // Short long-press threshold: 280ms triggers details dialog with haptics
    _longPressTimer = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) return;
      _pressDownTimer?.cancel();
      setState(() => _isPressed = false);
      _showDetails(context);
    });
  }

  void _cancelShortLongPress() {
    _pressDownTimer?.cancel();
    _longPressTimer?.cancel();
    if (_isPressed && mounted) {
      setState(() => _isPressed = false);
    }
  }

  void _showDetails(BuildContext context) {
    HapticFeedback.mediumImpact();
    Account? resolvedAccount = widget.account;
    if (resolvedAccount == null) {
      final provider = Provider.of<AppProvider>(context, listen: false);
      for (final a in provider.accounts) {
        if (a.id == widget.transaction.accountId) {
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
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) => TransactionDetailsDialog(
          transaction: widget.transaction,
          parentContext: outerContext,
          category: widget.category,
          account: resolvedAccount,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curve,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.93, end: 1.0).animate(curve),
              child: child,
            ),
          );
        },
      ),
    );
  }

  BoxDecoration _buildDecoration() {
    return BoxDecoration(
      color: const Color(0xFF0C1214).withValues(alpha: 0.60),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: _isPressed
            ? Colors.white.withValues(alpha: 0.30)
            : Colors.white.withValues(alpha: 0.11),
        width: _isPressed ? 1.2 : 1.0,
      ),
    );
  }

  Widget _buildLeading() {
    final isTransfer = widget.transaction.type == 'transfer';
    return Text(
      isTransfer ? '🔄' : (widget.category?.icon ?? '📦'),
      style: const TextStyle(fontSize: 24),
    );
  }

  Widget _buildTitle() {
    final isTransfer = widget.transaction.type == 'transfer';
    return Text(
      isTransfer ? 'Transfer' : (widget.category?.name ?? 'Transaction'),
      style: _titleStyle,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildSubtitle() {
    final isTransfer = widget.transaction.type == 'transfer';
    Account? srcAccount = widget.account;
    Account? dstAccount = widget.toAccount;

    if (srcAccount == null || (isTransfer && dstAccount == null && widget.transaction.toAccountId.isNotEmpty)) {
      final provider = Provider.of<AppProvider>(context, listen: false);
      for (final a in provider.accounts) {
        if (srcAccount == null && a.id == widget.transaction.accountId) {
          srcAccount = a;
        }
        if (isTransfer && dstAccount == null && a.id == widget.transaction.toAccountId) {
          dstAccount = a;
        }
      }
    }

    return Text(
      isTransfer
          ? '${srcAccount?.name ?? 'Unknown'} → ${dstAccount?.name ?? 'Unknown'}'
          : (srcAccount?.name ?? 'Unknown Account'),
      style: _subtitleStyle,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildTrailing() {
    final isIncome = widget.transaction.type == 'income';
    final isTransfer = widget.transaction.type == 'transfer';
    final symbol = widget.currencySymbol ?? Provider.of<AppProvider>(context, listen: false).currency.symbol;

    final style = isTransfer
        ? _amountTransferStyle
        : (isIncome ? _amountIncomeStyle : _amountExpenseStyle);

    return Text(
      isTransfer
          ? "$symbol${widget.transaction.amount.formatIndianCurrency()}"
          : "${isIncome ? '+' : '-'}$symbol${widget.transaction.amount.formatIndianCurrency()}",
      style: style,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTapDown: (_) => _startShortLongPress(context),
        onTapUp: (_) => _cancelShortLongPress(),
        onTapCancel: _cancelShortLongPress,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _isPressed ? 0.975 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(vertical: 5),
            decoration: _buildDecoration(),
            padding: const EdgeInsets.all(15),
            child: DefaultTextStyle.merge(
              style: _frauncesStyle,
              child: Row(
                children: [
                  _buildLeading(),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildTitle(),
                        const SizedBox(height: 2),
                        _buildSubtitle(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _buildTrailing(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
