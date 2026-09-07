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
  void _showModal() {
    HapticFeedback.lightImpact();
    showSmoothModalDialog(
      context: context,
      builder: (context) {
        return GlassModalDialog(
          title: widget.label ?? 'SELECT',
          content: _DropdownModalContent<T>(
            items: widget.items,
            selectedItem: widget.selectedItem,
            onSelect: widget.onSelect,
            getName: widget.getName,
            getId: widget.getId,
            getIcon: widget.getIcon,
          ),
        );
      },
    );
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
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),

              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (icon != null && icon.isNotEmpty) ...[
                        Text(
                          icon,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        selectedItem != null
                            ? widget.getName(selectedItem)
                            : widget.placeholder,
                        style: TextStyle(
                          color: selectedItem != null
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.3),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white.withValues(alpha: 0.4),
                    size: 16,
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
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    double initialOffset = 0.0;
    if (widget.selectedItem != null) {
      final selectedIndex = widget.items.indexWhere(
        (item) => widget.getId(item) == widget.getId(widget.selectedItem as T),
      );
      if (selectedIndex > 2) {
        // Approximate item height + margin is ~54px
        initialOffset = (selectedIndex - 1) * 54.0;
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
    final maxHeight = MediaQuery.sizeOf(context).height * 0.48;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: maxHeight,
      ),
      child: RawScrollbar(
        controller: _scrollController,
        thumbColor: Colors.white.withValues(alpha: 0.25),
        radius: const Radius.circular(8),
        thickness: 4,
        thumbVisibility: widget.items.length > 5,
        child: ListView.builder(
          controller: _scrollController,
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: widget.items.length,
          itemBuilder: (context, index) {
            final item = widget.items[index];
            final isSelected = widget.selectedItem != null &&
                widget.getId(item) == widget.getId(widget.selectedItem as T);
            final icon = widget.getIcon?.call(item);

            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                widget.onSelect(item);
                Navigator.pop(context);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
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
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Flexible(
                            child: Text(
                              widget.getName(item),
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.7),
                                fontSize: 16,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
                          size: 20,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
