import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_money_flutter/ui/components/custom_tab_bar.dart';
import 'package:my_money_flutter/ui/components/floating_action_button.dart';

void main() {
  testWidgets('Stack with CustomTabBar and FloatingActionButtonMorph builds without ParentData errors', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              CustomTabBar(
                currentIndex: 0,
                onTap: (_) {},
              ),
              const FloatingActionButtonMorph(),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(CustomTabBar), findsOneWidget);
    expect(find.byType(FloatingActionButtonMorph), findsOneWidget);
  });
}
