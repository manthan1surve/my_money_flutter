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

class CategoriesScreen extends BaseScreen {
  const CategoriesScreen({super.key});

  @override
  BaseScreenState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends BaseScreenState<CategoriesScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _iconController = TextEditingController();
  String _type = 'expense';

  @override
  bool get hasOwnBackground => false;

  @override
  String? get screenTitle => "Categories";

  @override
  void dispose() {
    _nameController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  void _showValidationDialog(String message) {
    showValidationDialog(context, message);
  }

  Future<void> _handleAddCategory() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final name = _nameController.text.trim();
    final icon = _iconController.text.trim();

    if (name.isEmpty && icon.isEmpty) {
      _showValidationDialog('Category name and emoji icon are required.');
      return;
    }
    if (name.isEmpty) {
      _showValidationDialog('Category name is required.');
      return;
    }
    if (icon.isEmpty) {
      _showValidationDialog('Emoji icon is required.');
      return;
    }

    final emojiRegex = RegExp(r'^[^\x00-\x7F\p{L}\p{N}\p{P}\p{Z}]+$', unicode: true);

    if (!emojiRegex.hasMatch(icon)) {
      _showValidationDialog('Please enter exactly one valid emoji for the icon.');
      return;
    }

    try {
      context.read<AppProvider>().addCategory(name, icon, _type);
      _nameController.clear();
      _iconController.clear();
      if (mounted) {
        showSuccessNotification(
          context,
          'Category "$icon $name" Created',
        );
      }
    } catch (e) {
      if (!mounted) return;
      showValidationDialog(context, e.toString());
    }
  }

  @override
  Widget buildBody(BuildContext context) {
    final categories = context.select((AppProvider p) => p.categories);
    final expenseCategories = categories.where((c) => c.type == 'expense').toList();
    final incomeCategories = categories.where((c) => c.type == 'income').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add Category Form Card using SolidCardWidget
          SolidCardWidget(
            margin: const EdgeInsets.only(bottom: 30),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Add New Category",
                  style: AppTypography.sectionTitle,
                ),
                const SizedBox(height: 15),
                _buildInput("Category Name (e.g., Groceries)", _nameController),
                const SizedBox(height: 12),
                _buildInput("Emoji Icon (e.g., 🛒)", _iconController),
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 220,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF161616).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          left: _type == 'expense' ? 3.0 : 110.0,
                          top: 3,
                          child: Container(
                            width: 107,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  if (_type != 'expense') {
                                    setState(() => _type = 'expense');
                                  }
                                },
                                child: Center(
                                  child: AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic,
                                    style: GoogleFonts.fraunces(
                                      fontSize: 14,
                                      fontWeight: _type == 'expense' ? FontWeight.w700 : FontWeight.w600,
                                      color: _type == 'expense' ? const Color(0xFFFE0000) : Colors.white.withValues(alpha: 0.65),
                                    ),
                                    child: const Text('Expense'),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  if (_type != 'income') {
                                    setState(() => _type = 'income');
                                  }
                                },
                                child: Center(
                                  child: AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOutCubic,
                                    style: GoogleFonts.fraunces(
                                      fontSize: 14,
                                      fontWeight: _type == 'income' ? FontWeight.w700 : FontWeight.w600,
                                      color: _type == 'income' ? const Color(0xFF00A82D) : Colors.white.withValues(alpha: 0.65),
                                    ),
                                    child: const Text('Income'),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(child: BlurButton(text: "Add Category", onPressed: _handleAddCategory)),
              ],
            ),
          ),

          UIComponentFactory.buildSectionHeader(title: "Your Categories"),
          const SizedBox(height: 15),

          _SlidingCategoryList(
            type: _type,
            expenseCategories: expenseCategories,
            incomeCategories: incomeCategories,
            onEdit: _showEditCategoryDialog,
            onDelete: (cat) {
              try {
                context.read<AppProvider>().deleteCategory(cat.id);
                showSuccessNotification(context, 'Category "${cat.name}" Deleted');
              } catch (e) {
                _showValidationDialog(e.toString());
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInput(String hint, TextEditingController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        style: GoogleFonts.fraunces(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.fraunces(color: Colors.white.withValues(alpha: 0.5), fontSize: 14),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          border: InputBorder.none,
        ),
      ),
    );
  }

  void _showEditCategoryDialog(CategoryModel cat, AppProvider provider) {
    final TextEditingController nameCtrl = TextEditingController(text: cat.name);
    final TextEditingController iconCtrl = TextEditingController(text: cat.icon);

    showSmoothModalDialog(
      context: context,
      builder: (context) {
        return GlassModalDialog(
          title: 'Edit Category',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInput("Category Name", nameCtrl),
              const SizedBox(height: 15),
              _buildInput("Emoji Icon", iconCtrl),
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
                final icon = iconCtrl.text.trim();
                if (name.isEmpty || icon.isEmpty) {
                  _showValidationDialog('Name and icon cannot be empty.');
                  return;
                }
                final emojiRegex = RegExp(r'^[^\x00-\x7F\p{L}\p{N}\p{P}\p{Z}]+$', unicode: true);
                if (!emojiRegex.hasMatch(icon)) {
                  _showValidationDialog('Please enter exactly one valid emoji for the icon.');
                  return;
                }
                
                try {
                  provider.updateCategory(cat.id, name, icon, cat.type);
                  if (context.mounted) {
                    Navigator.pop(context);
                    showSuccessNotification(
                      context,
                      'Category "$icon $name" Updated',
                    );
                  }
                } catch (e) {
                  _showValidationDialog(e.toString());
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

// ─── Sliding Category List ──────────────────────────────────────────────────

class _SlidingCategoryList extends StatelessWidget {
  final String type;
  final List<CategoryModel> expenseCategories;
  final List<CategoryModel> incomeCategories;
  final void Function(CategoryModel, AppProvider) onEdit;
  final void Function(CategoryModel) onDelete;

  const _SlidingCategoryList({
    required this.type,
    required this.expenseCategories,
    required this.incomeCategories,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final activeCategories = type == 'income' ? incomeCategories : expenseCategories;
    final isIncome = type == 'income';

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          children: [
            ...previousChildren,
            ?currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        final offsetTween = isIncome
            ? Tween<Offset>(begin: const Offset(0.06, 0.0), end: Offset.zero)
            : Tween<Offset>(begin: const Offset(-0.06, 0.0), end: Offset.zero);

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: offsetTween.animate(animation),
            child: child,
          ),
        );
      },
      child: activeCategories.isEmpty
          ? SizedBox(
              key: ValueKey('empty_$type'),
              width: double.infinity,
              child: UIComponentFactory.buildEmptyState(
                message: 'No $type categories yet.',
                icon: Icons.category_outlined,
              ),
            )
          : Column(
              key: ValueKey('list_$type'),
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: activeCategories.map((cat) {
                return _CategoryItemWidget(
                  key: ValueKey(cat.id),
                  category: cat,
                  onEdit: () => onEdit(cat, context.read<AppProvider>()),
                  onDelete: () => onDelete(cat),
                );
              }).toList(),
            ),
    );
  }
}

// ─── Category Item Widget ────────────────────────────────────────────────────

class _CategoryItemWidget extends StatefulWidget {
  final CategoryModel category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryItemWidget({
    super.key,
    required this.category,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_CategoryItemWidget> createState() => _CategoryItemWidgetState();
}

class _CategoryItemWidgetState extends State<_CategoryItemWidget> {
  bool _isDeleteRevealed = false;
  bool _isDismissing = false;

  void _handleRemove() async {
    if (!_isDeleteRevealed || _isDismissing) return;
    setState(() => _isDismissing = true);
    await Future.delayed(const Duration(milliseconds: 250));
    if (mounted) widget.onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: _isDismissing ? const Offset(-1.2, 0) : Offset.zero,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      child: AnimatedOpacity(
        opacity: _isDismissing ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeIn,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Stack(
            alignment: Alignment.centerRight,
            children: [
              // Red "Remove" action button revealed behind
              if (_isDeleteRevealed)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: _handleRemove,
                    child: Container(
                      width: 110,
                      margin: const EdgeInsets.symmetric(vertical: 2.0),
                      padding: const EdgeInsets.only(left: 20, right: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFE0000),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Remove',
                        style: GoogleFonts.fraunces(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),

              // Foreground category card
              AnimatedSlide(
                offset: _isDeleteRevealed ? const Offset(-0.24, 0) : Offset.zero,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161616).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Text(
                        widget.category.icon,
                        style: const TextStyle(fontSize: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          widget.category.name,
                          style: GoogleFonts.fraunces(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Edit Button
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onEdit,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.edit_outlined,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Toggle Delete Button
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => setState(() => _isDeleteRevealed = !_isDeleteRevealed),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _isDeleteRevealed
                                ? const Color(0xFFFE0000).withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            _isDeleteRevealed ? Icons.arrow_forward_ios : Icons.close,
                            color: _isDeleteRevealed ? const Color(0xFFFE0000) : Colors.white70,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

