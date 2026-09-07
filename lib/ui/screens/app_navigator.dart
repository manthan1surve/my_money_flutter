import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_provider.dart';
import 'onboarding_screen.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'analytics_screen.dart';
import 'accounts_screen.dart';
import 'categories_screen.dart';
import '../components/custom_tab_bar.dart';
import '../components/floating_action_button.dart';
import '../components/loading_spinner.dart';
import '../components/app_background.dart';

class AppNavigator extends StatelessWidget {
  const AppNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    final loading = context.select((AppProvider p) => p.loading);
    final hasSeenOnboarding = context.select((AppProvider p) => p.hasSeenOnboarding);
    final hasUser = context.select((AppProvider p) => p.user != null);

    Widget content;
    if (loading) {
      content = const Scaffold(
        key: ValueKey('loading'),
        body: AppBackground(
          child: LoadingSpinner(),
        ),
      );
    } else if (!hasSeenOnboarding) {
      content = const OnboardingScreen(key: ValueKey('onboarding'));
    } else if (!hasUser) {
      content = const LoginScreen(key: ValueKey('login'));
    } else {
      content = const MainScreen(key: ValueKey('main'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: content,
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: AppBackground(
        child: Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                // Only toggle FAB visibility for vertical scrolls (ignore tab view swipes or horizontal months list)
                if (notification.metrics.axis == Axis.vertical) {
                  if (notification.metrics.pixels <= 10.0) {
                    // Always show FAB when at the top of the screen
                    FloatingActionButtonMorph.showNotifier.value = true;
                  } else if (notification is ScrollUpdateNotification) {
                    final delta = notification.scrollDelta ?? 0.0;
                    if (delta > 0.5) {
                      // Scrolling down -> hide FAB
                      FloatingActionButtonMorph.showNotifier.value = false;
                    } else if (delta < -0.5) {
                      // Scrolling up -> show FAB (only if we are not near/at the end of the screen)
                      if (notification.metrics.pixels < notification.metrics.maxScrollExtent - 40.0) {
                        FloatingActionButtonMorph.showNotifier.value = true;
                      }
                    }
                  }
                }
                return false; // let the notification bubble up further
              },
              child: IndexedStack(
                index: _currentIndex,
                children: [
                  TickerMode(
                    enabled: _currentIndex == 0,
                    child: const DashboardScreen(),
                  ),
                  TickerMode(
                    enabled: _currentIndex == 1,
                    child: const AccountsScreen(),
                  ),
                  TickerMode(
                    enabled: _currentIndex == 2,
                    child: AnalyticsScreen(isActive: _currentIndex == 2),
                  ),
                  TickerMode(
                    enabled: _currentIndex == 3,
                    child: const CategoriesScreen(),
                  ),
                ],
              ),
            ),
          CustomTabBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
              // Always reset FAB to visible when switching tabs
              FloatingActionButtonMorph.showNotifier.value = true;
            },
          ),
          const FloatingActionButtonMorph(),
        ],
      ),
    ),
  );
}
}
