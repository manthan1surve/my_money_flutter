import 'package:flutter/material.dart';
import '../components/app_background.dart';
import '../../core/theme.dart';

/// Abstract base widget for all screens in the application.
abstract class BaseScreen extends StatefulWidget {
  const BaseScreen({super.key});
}

/// Abstract base state for screens implementing the Template Method Pattern.
abstract class BaseScreenState<T extends BaseScreen> extends State<T> {
  /// Screen title to display in the standard header, if specified.
  String? get screenTitle => null;

  /// Whether to automatically wrap body in a SafeArea. Defaults to true.
  bool get useSafeArea => true;

  /// Whether to show a back button in the header. Defaults to false.
  bool get showBackButton => false;

  /// Optional trailing header widget (e.g. actions, icons).
  Widget? buildHeaderActions(BuildContext context) => null;

  /// Back tap callback handler.
  void onBackTapped() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  /// Whether this screen manages its own background.
  /// Defaults to true; set to false when hosted in a shell that renders a shared background.
  bool get hasOwnBackground => true;

  /// Template Method: Builds the background widget.
  Widget buildBackground(BuildContext context, Widget child) {
    if (!hasOwnBackground) return child;
    return AppBackground(child: child);
  }

  /// Template Method: Builds standard header row if title, back button, or actions are provided.
  Widget? buildHeader(BuildContext context) {
    final title = screenTitle;
    final hasActions = buildHeaderActions(context) != null;

    if (title == null && !showBackButton && !hasActions) return null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          if (showBackButton) ...[
            GestureDetector(
              onTap: onBackTapped,
              child: const Icon(Icons.chevron_left, color: Colors.white, size: 30),
            ),
            const SizedBox(width: 10),
          ],
          if (title != null)
            Text(title, style: AppTypography.screenTitle),
          const Spacer(),
          if (hasActions) buildHeaderActions(context)!,
        ],
      ),
    );
  }

  /// Abstract Method: Must be implemented by subclasses to provide screen body content.
  Widget buildBody(BuildContext context);

  /// Template Method: Optional floating action button.
  Widget? buildFloatingActionButton(BuildContext context) => null;

  /// Template Method: Optional bottom navigation bar.
  Widget? buildBottomNavigationBar(BuildContext context) => null;

  /// Template Method: Main layout builder combining background, safe area, header and body.
  Widget buildScreenContent(BuildContext context) {
    final header = buildHeader(context);
    final body = buildBody(context);

    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ?header,
        Expanded(child: body),
      ],
    );

    if (useSafeArea) {
      content = SafeArea(child: content);
    }

    return content;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: buildBackground(
        context,
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: buildScreenContent(context),
        ),
      ),
      floatingActionButton: buildFloatingActionButton(context),
      bottomNavigationBar: buildBottomNavigationBar(context),
    );
  }
}
