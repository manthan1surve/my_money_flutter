import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/models.dart';
import 'add_transaction_form.dart';

class FloatingActionButtonMorph extends StatefulWidget {
  const FloatingActionButtonMorph({super.key});

  /// Set a non-null value to open the FAB in edit mode for that transaction.
  /// The FAB listens to this and morphs open automatically.
  static final editNotifier = ValueNotifier<TransactionModel?>(null);

  /// Controls whether the FAB should be visible on screen
  static final showNotifier = ValueNotifier<bool>(true);

  @override
  State<FloatingActionButtonMorph> createState() => _FloatingActionButtonMorphState();
}

class _FloatingActionButtonMorphState extends State<FloatingActionButtonMorph>
    with TickerProviderStateMixin {
  bool _isExpanded = false;
  TransactionModel? _existingTransaction;

  late AnimationController _progressController;
  late Animation<double> _progressAnim;
  late AnimationController _iconController;
  late AnimationController _fadeController;

  Timer? _fadeTimer;

  static const double btnSize = 60.0;
  static const double btnBottom = 170.0;
  static const double btnRight = 20.0;
  static const double expandedHeightFraction = 0.70;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _progressAnim = CurvedAnimation(
        parent: _progressController,
        curve: Curves.easeOutQuint,
        reverseCurve: Curves.easeInCubic);

    _iconController = AnimationController(vsync: this);
    _fadeController = AnimationController(vsync: this);

    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        setState(() {
          _isExpanded = false;
          _existingTransaction = null;
        });
      }
    });

    FloatingActionButtonMorph.editNotifier.addListener(_onEditRequest);
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    _progressController.dispose();
    _iconController.dispose();
    _fadeController.dispose();
    FloatingActionButtonMorph.editNotifier.removeListener(_onEditRequest);
    super.dispose();
  }

  void _onEditRequest() {
    final tx = FloatingActionButtonMorph.editNotifier.value;
    if (tx != null) {
      setState(() => _existingTransaction = tx);
      _expand();
    }
  }

  void _expand() {
    HapticFeedback.mediumImpact();
    setState(() => _isExpanded = true);

    _progressController.forward();
    _iconController.animateTo(1.0,
        duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);

    _fadeTimer?.cancel();
    _fadeTimer = Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        _fadeController.animateTo(1.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic);
      }
    });
  }

  void _collapse() {
    HapticFeedback.lightImpact();
    FocusScope.of(context).unfocus();
    FloatingActionButtonMorph.editNotifier.value = null;

    _fadeTimer?.cancel();
    _fadeController.animateTo(0.0,
        duration: const Duration(milliseconds: 200), curve: Curves.easeInCubic);
    _iconController.animateTo(0.0,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInCubic);

    _progressController.reverse();
  }

  void _toggle() {
    HapticFeedback.lightImpact();
    if (_progressController.value > 0.5 || _isExpanded) {
      _collapse();
    } else {
      setState(() => _existingTransaction = null);
      _expand();
    }
  }

  void _handleComplete() {
    _collapse();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;

    final expandedWidth = screenWidth - 40;
    final expandedHeight = screenHeight * expandedHeightFraction;
    const expandedX = 20.0;
    const expandedYBottom = 170.0;

    return ValueListenableBuilder<bool>(
      valueListenable: FloatingActionButtonMorph.showNotifier,
      builder: (context, showFab, _) {
        return AnimatedBuilder(
          animation:
              Listenable.merge([_progressController, _iconController, _fadeController]),
          // Rebuild form when transaction changes so it pre-fills correctly
          child: RepaintBoundary(
            key: ValueKey(_existingTransaction?.id),
            child: AddTransactionForm(
              existingTransaction: _existingTransaction,
              onComplete: _handleComplete,
            ),
          ),
          builder: (context, child) {
            final progress = _progressAnim.value;
            final iconProgress = _iconController.value;
            final fadeProgress = _fadeController.value;

            final currentWidth = lerpDouble(btnSize, expandedWidth, progress)!;
            final currentHeight = lerpDouble(btnSize, expandedHeight, progress)!;
            final currentRadius = lerpDouble(btnSize / 2, 24, progress)!;
            final currentRight = lerpDouble(btnRight, expandedX, progress)!;
            final currentBottom = lerpDouble(btnBottom, expandedYBottom, progress)!;

            final isVisible = showFab || progress > 0.05;
            final finalBottom = isVisible ? currentBottom : -100.0;

            return AnimatedPositioned(
              duration: const Duration(milliseconds: 750),
              curve: Curves.easeInOutCubic,
              right: currentRight,
              bottom: finalBottom,
              child: GestureDetector(
                onTap: !_isExpanded ? _toggle : null,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: currentWidth,
                  height: currentHeight,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(currentRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withValues(alpha: lerpDouble(0.35, 0.45, progress)!),
                        blurRadius: 24,
                        offset: Offset(0, lerpDouble(8, 16, progress)!),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(currentRadius),
                    child: Stack(
                      children: [
                        BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(currentRadius),
                            ),
                          ),
                        ),

                        // Form content
                        OverflowBox(
                          minWidth: expandedWidth,
                          maxWidth: expandedWidth,
                          minHeight: expandedHeight - 20,
                          maxHeight: expandedHeight - 20,
                          child: Opacity(
                            opacity: fadeProgress,
                            child: Container(
                              padding: const EdgeInsets.only(top: 20),
                              width: expandedWidth,
                              height: expandedHeight - 20,
                              child: IgnorePointer(
                                ignoring: !_isExpanded || fadeProgress < 0.5,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Expanded(child: child!),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Close / Add icon — centered when collapsed, top-right when expanded
                        Positioned.fill(
                          child: Align(
                            alignment: Alignment.lerp(
                              Alignment.center,
                              Alignment.topRight,
                              progress,
                            )!,
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: lerpDouble(0, 16, progress)!,
                                right: lerpDouble(0, 16, progress)!,
                              ),
                              child: GestureDetector(
                                onTap: _toggle,
                                behavior: HitTestBehavior.opaque,
                                child: SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: Transform.rotate(
                                    angle:
                                        lerpDouble(0, 135 * 3.14159 / 180, iconProgress)!,
                                    child: const Icon(
                                      Icons.add,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
