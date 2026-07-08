import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const CustomTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final barWidth = screenWidth * 0.92;
    const paddingHorizontal = 6.0;
    const borderWidth = 1.5;
    
    final innerWidth = barWidth - (borderWidth * 2) - (paddingHorizontal * 2);
    final tabWidth = innerWidth / 4; // 4 tabs

    final startOffset = paddingHorizontal + (tabWidth - tabWidth) / 2;
    final translateX = (currentIndex * tabWidth) + startOffset;

    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Positioned(
      bottom: bottomPadding > 0 ? bottomPadding + 10 : 48,
      left: (screenWidth - barWidth) / 2,
      child: SizedBox(
        width: barWidth,
        height: 72,
        child: Stack(
          children: [
            // Background Layer
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                color: Colors.white.withValues(alpha: 0.05),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    offset: const Offset(0, 8),
                    blurRadius: 24,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(36),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    color: Colors.transparent,
                  ),
                ),
              ),
            ),

            // Active Pill Layer
            AnimatedPositioned(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutQuart,
              left: translateX,
              top: 6,
              bottom: 6,
              width: tabWidth,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(29),
                  color: Colors.white,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3), 
                    width: 1.5,
                  ),
                ),
                child: Stack(
                  children: [
                    // Top light catch
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(29),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.6],
                          colors: [
                            Colors.white.withValues(alpha: 0.5),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    // Bottom subtle reflection
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(29),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.4, 1.0],
                          colors: [
                            Colors.transparent,
                            Colors.white.withValues(alpha: 0.2),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content Layer
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: paddingHorizontal),
              child: Row(
                children: [
                  _buildTabItem(0, 'Dashboard', 'assets/dasborad.png'),
                  _buildTabItem(1, 'Accounts', 'assets/accounts.png'),
                  _buildTabItem(2, 'Analytics', 'assets/analytics.png'),
                  _buildTabItem(3, 'Categories', 'assets/catgorgy.png'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, String label, String assetName) {
    final isFocused = currentIndex == index;
    final color = isFocused ? Colors.black : Colors.white.withValues(alpha: 0.6);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          onTap(index);
        },
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(begin: color, end: color),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutQuart,
          builder: (context, animColor, child) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  assetName,
                  width: 24,
                  height: 24,
                  color: animColor,
                ),
                const SizedBox(height: 2),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: animColor,
                      letterSpacing: 0.2,
                      fontWeight: isFocused ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
