import 'package:flutter/material.dart';

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _accent      = Color(0xFFFF6B35);
  static const _primary     = Color(0xFF1A1A2E);
  static const _white       = Color(0xFFFFFFFF);
  static const _textHint    = Color(0xFFBBBBBB);
  static const _divider     = Color(0xFFEEEEEE);

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_rounded,                   Icons.home_outlined,              'Home'),
      (Icons.account_balance_wallet_rounded, Icons.account_balance_wallet_outlined, 'Earnings'),
      (Icons.receipt_long_rounded,           Icons.receipt_long_outlined,      'Trips'),
      (Icons.person_rounded,                 Icons.person_outline_rounded,     'Profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: _white,
        border: const Border(top: BorderSide(color: _divider, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(items.length, (i) {
              final (activeIcon, inactiveIcon, label) = items[i];
              final isSelected = currentIndex == i;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon with active indicator dot
                        Stack(
                          alignment: Alignment.topRight,
                          clipBehavior: Clip.none,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                isSelected ? activeIcon : inactiveIcon,
                                key: ValueKey(isSelected),
                                color: isSelected ? _accent : _textHint,
                                size: 24,
                              ),
                            ),
                            if (isSelected)
                              Positioned(
                                top: -2,
                                right: -2,
                                child: Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: _accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Label
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            color: isSelected ? _accent : _textHint,
                            fontSize: isSelected ? 10.5 : 10,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            letterSpacing: isSelected ? 0.2 : 0,
                          ),
                          child: Text(label),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}