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
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  TransactionModel? _existingTransaction;
  int _sessionKey = 0;

  late final AnimationController _morphController;
  late final Animation<double> _shapeAnim;
  late final Animation<double> _iconAnim;
  late final Animation<double> _formFadeAnim;

  static const double btnSize = 60.0;
  static const double btnBottom = 170.0;
  static const double btnRight = 20.0;
  static const double expandedHeightFraction = 0.70;

  @override
  void initState() {
    super.initState();
    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      reverseDuration: const Duration(milliseconds: 320),
    );

    // Natural fluid easing curves for organic deceleration and responsive retreat
    _shapeAnim = CurvedAnimation(
      parent: _morphController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );

    _iconAnim = CurvedAnimation(
      parent: _morphController,
      curve: const Interval(0.0, 0.80, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0.15, 1.0, curve: Curves.easeInOutCubic),
    );

    // Form content smoothly fades in without mid-flight mount spikes and cleanly dissolves on retreat
    _formFadeAnim = CurvedAnimation(
      parent: _morphController,
      curve: const Interval(0.25, 1.0, curve: Curves.easeOutCubic),
      reverseCurve: const Interval(0.60, 1.0, curve: Curves.easeIn),
    );

    _morphController.addStatusListener((status) {
      if (status == AnimationStatus.dismissed) {
        if (mounted) {
          setState(() {
            _isExpanded = false;
            _existingTransaction = null;
          });
        }
      }
    });

    FloatingActionButtonMorph.editNotifier.addListener(_onEditRequest);
  }

  @override
  void dispose() {
    _morphController.dispose();
    FloatingActionButtonMorph.editNotifier.removeListener(_onEditRequest);
    super.dispose();
  }

  void _onEditRequest() {
    final tx = FloatingActionButtonMorph.editNotifier.value;
    if (tx != null) {
      setState(() {
        _existingTransaction = tx;
        _sessionKey = DateTime.now().millisecondsSinceEpoch;
      });
      _expand();
    }
  }

  void _expand() {
    HapticFeedback.mediumImpact();
    setState(() => _isExpanded = true);
    _morphController.forward();
  }

  void _collapse() {
    HapticFeedback.lightImpact();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    FocusManager.instance.primaryFocus?.unfocus();
    FloatingActionButtonMorph.editNotifier.value = null;
    _morphController.reverse();
  }

  void _toggle() {
    HapticFeedback.lightImpact();
    if (_morphController.value > 0.5 || _isExpanded) {
      _collapse();
    } else {
      setState(() {
        _existingTransaction = null;
        _sessionKey = DateTime.now().millisecondsSinceEpoch;
      });
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

    return ValueListenableBuilder<bool>(
      valueListenable: FloatingActionButtonMorph.showNotifier,
      builder: (context, showFab, _) {
        return Positioned(
          right: btnRight,
          bottom: btnBottom,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            offset: (showFab || _isExpanded) ? Offset.zero : const Offset(0, 2.5),
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _morphController,
                // Pre-built form widget cached in AnimatedBuilder child to avoid rebuilds
                child: RepaintBoundary(
                  key: ValueKey('${_existingTransaction?.id ?? 'new'}_$_sessionKey'),
                  child: AddTransactionForm(
                    existingTransaction: _existingTransaction,
                    onComplete: _handleComplete,
                  ),
                ),
                builder: (context, child) {
                  final shapeProgress = _shapeAnim.value;
                  final iconProgress = _iconAnim.value;
                  final fadeProgress = _formFadeAnim.value;

                  final currentWidth = lerpDouble(btnSize, expandedWidth, shapeProgress)!;
                  final currentHeight = lerpDouble(btnSize, expandedHeight, shapeProgress)!;
                  final currentRadius = lerpDouble(btnSize / 2, 24, shapeProgress)!;

                  return GestureDetector(
                    onTap: !_isExpanded ? _toggle : null,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: currentWidth,
                      height: currentHeight,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(currentRadius),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                                alpha: lerpDouble(0.35, 0.45, shapeProgress)!),
                            blurRadius: 24,
                            offset: Offset(0, lerpDouble(8, 16, shapeProgress)!),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(currentRadius),
                        child: Stack(
                          children: [
                            // Exact original visual glass layer
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

                            // Form content: persistent across expanded session, zero mid-animation mount spikes
                            if (_isExpanded)
                              OverflowBox(
                                minWidth: expandedWidth,
                                maxWidth: expandedWidth,
                                minHeight: expandedHeight - 20,
                                maxHeight: expandedHeight - 20,
                                child: FadeTransition(
                                  opacity: _formFadeAnim,
                                  child: Container(
                                    padding: const EdgeInsets.only(top: 20),
                                    width: expandedWidth,
                                    height: expandedHeight - 20,
                                    child: IgnorePointer(
                                      ignoring: !_isExpanded || fadeProgress < 0.5,
                                      child: child!,
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
                                  shapeProgress,
                                )!,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    top: lerpDouble(0, 16, shapeProgress)!,
                                    right: lerpDouble(0, 16, shapeProgress)!,
                                  ),
                                  child: GestureDetector(
                                    onTap: _toggle,
                                    behavior: HitTestBehavior.opaque,
                                    child: SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: Transform.rotate(
                                        angle: lerpDouble(
                                            0, 135 * 3.14159 / 180, iconProgress)!,
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
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
