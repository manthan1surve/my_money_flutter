import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../base/base_dialog.dart';

class DropdownSelector<T> extends StatefulWidget {
  final String? label;
  final List<T> items;
  final T? selectedItem;
  final ValueChanged<T> onSelect;
  final String placeholder;
  final String Function(T) getName;
  final String? Function(T)? getIcon;
  final String Function(T) getId;

  const DropdownSelector({
    super.key,
    this.label,
    required this.items,
    required this.selectedItem,
    required this.onSelect,
    this.placeholder = 'Select...',
    required this.getName,
    required this.getId,
    this.getIcon,
  });

  @override
  State<DropdownSelector<T>> createState() => _DropdownSelectorState<T>();
}

class _DropdownSelectorState<T> extends State<DropdownSelector<T>> {
  bool _isOpen = false;

  Future<void> _showModal() async {
    HapticFeedback.lightImpact();
    setState(() => _isOpen = true);

    final selected = await showSmoothModalDialog<T>(
      context: context,
      duration: const Duration(milliseconds: 240),
      builder: (dialogCtx) {
        return GlassModalDialog(
          title: widget.label ?? 'SELECT',
          scrollableContent: false,
          blurSigma: 12.0,
          content: _DropdownModalContent<T>(
            items: widget.items,
            selectedItem: widget.selectedItem,
            onSelect: (item) {
              Navigator.of(dialogCtx).pop(item);
            },
            getName: widget.getName,
            getId: widget.getId,
            getIcon: widget.getIcon,
          ),
        );
      },
    );

    if (mounted) {
      setState(() => _isOpen = false);
      if (selected != null) {
        widget.onSelect(selected);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedItem = widget.selectedItem;
    final icon = selectedItem != null ? widget.getIcon?.call(selectedItem) : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.label != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6, left: 4),
              child: Text(
                widget.label!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          GestureDetector(
            onTap: _showModal,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _isOpen
                      ? Colors.white.withValues(alpha: 0.28)
                      : Colors.white.withValues(alpha: 0.08),
                  width: _isOpen ? 1.2 : 1.0,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        if (icon != null && icon.isNotEmpty) ...[
                          Text(
                            icon,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            selectedItem != null
                                ? widget.getName(selectedItem)
                                : widget.placeholder,
                            style: TextStyle(
                              color: selectedItem != null
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.3),
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isOpen ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: _isOpen
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DropdownModalContent<T> extends StatefulWidget {
  final List<T> items;
  final T? selectedItem;
  final ValueChanged<T> onSelect;
  final String Function(T) getName;
  final String? Function(T)? getIcon;
  final String Function(T) getId;

  const _DropdownModalContent({
    required this.items,
    required this.selectedItem,
    required this.onSelect,
    required this.getName,
    required this.getId,
    this.getIcon,
  });

  @override
  State<_DropdownModalContent<T>> createState() => _DropdownModalContentState<T>();
}

class _DropdownModalContentState<T> extends State<_DropdownModalContent<T>> {
  static const double _itemHeight = 52.0;
  late final ScrollController _scrollController;
  String? _tempSelectedId;

  // Cached decorations to avoid memory allocations and GC pressure during 60/120fps scrolling
  static final BoxDecoration _selectedDecoration = BoxDecoration(
    color: Colors.white.withValues(alpha: 0.08),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: Colors.white.withValues(alpha: 0.16),
      width: 1,
    ),
  );

  static final BoxDecoration _unselectedDecoration = BoxDecoration(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: Colors.transparent,
      width: 1,
    ),
  );

  @override
  void initState() {
    super.initState();
    if (widget.selectedItem != null) {
      _tempSelectedId = widget.getId(widget.selectedItem as T);
    }

    double initialOffset = 0.0;
    if (widget.selectedItem != null) {
      final selectedIndex = widget.items.indexWhere(
        (item) => widget.getId(item) == widget.getId(widget.selectedItem as T),
      );
      if (selectedIndex > 1) {
        initialOffset = (selectedIndex - 1) * _itemHeight;
      }
    }
    _scrollController = ScrollController(initialScrollOffset: initialOffset);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final maxHeight = screenHeight * 0.48;
    final totalHeight = widget.items.length * _itemHeight;
    final contentHeight = totalHeight.clamp(_itemHeight, maxHeight);
    final isScrollable = totalHeight > maxHeight;

    // RepaintBoundary isolates the scrolling list onto its own GPU layer,
    // preventing the parent GlassModalDialog's 12px BackdropFilter from
    // re-filtering the background on every single scroll frame.
    return RepaintBoundary(
      child: SizedBox(
        height: contentHeight,
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
            scrollbars: false,
          ),
          child: RawScrollbar(
            controller: _scrollController,
            thumbColor: Colors.white.withValues(alpha: 0.28),
            radius: const Radius.circular(8),
            thickness: 4,
            interactive: true,
            thumbVisibility: isScrollable,
            child: ListView.builder(
              controller: _scrollController,
              itemExtent: _itemHeight,
              itemCount: widget.items.length,
              shrinkWrap: false,
              // ClampingScrollPhysics provides instantaneous 1:1 tracking without sticky rubber-band resistance
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.zero,
              findChildIndexCallback: (Key key) {
                if (key is ValueKey<String>) {
                  final index = widget.items.indexWhere(
                    (item) => widget.getId(item) == key.value,
                  );
                  return index >= 0 ? index : null;
                }
                return null;
              },
              itemBuilder: (context, index) {
                final item = widget.items[index];
                final itemId = widget.getId(item);
                final isSelected = _tempSelectedId != null
                    ? _tempSelectedId == itemId
                    : (widget.selectedItem != null &&
                        widget.getId(widget.selectedItem as T) == itemId);
                final icon = widget.getIcon?.call(item);

                return Padding(
                  key: ValueKey<String>(itemId),
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _tempSelectedId = itemId);
                        widget.onSelect(item);
                      },
                      borderRadius: BorderRadius.circular(12),
                      splashColor: Colors.white.withValues(alpha: 0.12),
                      highlightColor: Colors.white.withValues(alpha: 0.06),
                      child: Ink(
                        decoration: isSelected
                            ? _selectedDecoration
                            : _unselectedDecoration,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  if (icon != null && icon.isNotEmpty) ...[
                                    Text(
                                      icon,
                                      style: const TextStyle(fontSize: 18),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Expanded(
                                    child: Text(
                                      widget.getName(item),
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.white
                                            : Colors.white.withValues(alpha: 0.72),
                                        fontSize: 15,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 19,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
