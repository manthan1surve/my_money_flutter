import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import '../components/app_background.dart';
import '../components/glass_card.dart';
import '../components/blur_button.dart';
import '../components/validation_dialog.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _iconController = TextEditingController();
  String _type = 'expense';

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
      Provider.of<AppProvider>(context, listen: false).addCategory(name, icon, _type);
      _nameController.clear();
      _iconController.clear();
    } catch (e) {
      if (!mounted) return;
      showValidationDialog(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final filteredCategories = provider.categories.where((c) => c.type == _type).toList();

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
                child: Text("Categories", style: AppTypography.screenTitle),
              ),

              // Add Category Form Card
              GlassCard(
                margin: const EdgeInsets.only(bottom: 30),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Add New Category",
                      style: AppTypography.sectionTitle,
                    ),
                    const SizedBox(height: 15),

                    // Category Name Input
                    _buildInput("Category Name (e.g., Groceries)", _nameController),
                    const SizedBox(height: 12),

                    // Emoji Icon Input
                    _buildInput("Emoji Icon (e.g., ðŸ›’)", _iconController),
                    const SizedBox(height: 16),

                    // Animated Expense / Income Toggle
                    Center(
                      child: Container(
                        width: 220,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Stack(
                          children: [
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeOutQuart,
                              left: _type == 'expense' ? 3.0 : 110.0,
                              top: 3,
                              child: Container(
                                width: 107,
                                height: 44,
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
                                    onTap: () => setState(() => _type = 'expense'),
                                    child: Center(
                                      child: Text(
                                        'Expense',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: _type == 'expense' ? Colors.black : Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => setState(() => _type = 'income'),
                                    child: Center(
                                      child: Text(
                                        'Income',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: _type == 'income' ? Colors.black : Colors.white,
                                        ),
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

              // Section Title
              Text("Your Categories", style: AppTypography.sectionTitle),
              const SizedBox(height: 15),

              // Category List
              if (filteredCategories.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(
                      'No $_type categories yet.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
                    ),
                  ),
                )
              else
                ...filteredCategories.map((cat) => _buildCategoryItem(cat, provider)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String hint, TextEditingController controller) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: TextField(
        controller: controller,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildCategoryItem(CategoryModel cat, AppProvider provider) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Text(cat.icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cat.name,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cat.type.toUpperCase(),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 9, letterSpacing: 0.8),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(12, 0),
            child: Theme(
            data: Theme.of(context).copyWith(
              cardColor: const Color(0xFF2A2A2A),
            ),
            child: PopupMenuButton<String>(
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
                  _showEditCategoryDialog(cat, provider);
                } else if (value == 'delete') {
                  _showDeleteConfirmation(cat, provider);
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
    );
  }

  void _showEditCategoryDialog(CategoryModel cat, AppProvider provider) {
    final TextEditingController nameCtrl = TextEditingController(text: cat.name);
    final TextEditingController iconCtrl = TextEditingController(text: cat.icon);

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
          title: const Text('Edit Category', style: TextStyle(color: Colors.white)),
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
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () async {
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Category updated successfully!')),
                    );
                  }
                } catch (e) {
                  _showValidationDialog(e.toString());
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

  void _showDeleteConfirmation(CategoryModel cat, AppProvider provider) {
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
          title: const Text('Delete Category', style: TextStyle(color: Colors.white)),
          content: Text('Are you sure you want to delete ${cat.name}?', style: const TextStyle(color: Colors.white70)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () async {
                try {
                  provider.deleteCategory(cat.id);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Category deleted successfully!')),
                    );
                  }
                } catch (e) {
                  _showValidationDialog(e.toString());
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
