import 'package:flutter/material.dart';
import '../base/base_dialog.dart';

/// Modal dialog for validation alerts extending OO BaseModalDialog.
class ValidationModalDialog extends BaseModalDialog {
  final String message;

  const ValidationModalDialog({
    super.key,
    required this.message,
    super.borderRadius = 24.0,
    super.padding = const EdgeInsets.fromLTRB(24, 28, 24, 24),
  }) : super(title: 'Notice');

  @override
  Widget? buildTitleIcon(BuildContext context) {
    return const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB74D), size: 24);
  }

  @override
  Widget buildDialogContent(BuildContext context) {
    return Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5),
    );
  }

  @override
  List<Widget>? buildDialogActions(BuildContext context) {
    return [
      ElevatedButton(
        onPressed: () => Navigator.of(context).pop(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
          minimumSize: const Size(70, 36),
        ),
        child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    ];
  }
}

/// Modal dialog for success notifications extending OO BaseModalDialog.
class SuccessNotificationModalDialog extends BaseModalDialog {
  final String? message;

  const SuccessNotificationModalDialog({
    super.key,
    required super.title,
    this.message,
    super.borderRadius = 24.0,
    super.padding = const EdgeInsets.fromLTRB(24, 40, 24, 24),
  });

  @override
  Widget? buildTitleIcon(BuildContext context) {
    return const Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 22);
  }

  @override
  Widget buildDialogContent(BuildContext context) {
    if (message == null || message!.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Text(
      message!,
      textAlign: TextAlign.center,
      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14, height: 1.4),
    );
  }

  @override
  List<Widget>? buildDialogActions(BuildContext context) {
    return [
      ElevatedButton(
        onPressed: () => Navigator.of(context).pop(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 10),
          minimumSize: const Size(70, 36),
        ),
        child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    ];
  }
}

void showValidationDialog(BuildContext context, String message) {
  showSmoothModalDialog(
    context: context,
    builder: (context) => ValidationModalDialog(message: message),
  );
}

void showSuccessNotification(BuildContext context, String title, [String? message]) {
  showSmoothModalDialog(
    context: context,
    builder: (context) => SuccessNotificationModalDialog(title: title, message: message),
  );
}
