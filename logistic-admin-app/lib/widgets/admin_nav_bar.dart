import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NavItem {
  final IconData activeIcon;
  final IconData icon;
  final String label;
  const NavItem(this.activeIcon, this.icon, this.label);
}

class AdminNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AdminNavBar({super.key, required this.currentIndex, required this.onTap});

  // ── Palette (matches DriverDashboardScreen) ───────────────────────────────
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _accent  = Color(0xFF0066FF);
  static const Color _border  = Color(0xFFE8ECF0);
  static const Color _textSec = Color(0xFF8A94A6);

  static const _items = [
    NavItem(Icons.dashboard_rounded,      Icons.dashboard_outlined,         'Home'),
    NavItem(Icons.drive_eta_rounded,      Icons.drive_eta_outlined,         'Drivers'),
    NavItem(Icons.people_rounded,         Icons.people_outline_rounded,     'Users'),
    NavItem(Icons.local_shipping_rounded, Icons.local_shipping_outlined,    'Orders'),
    NavItem(Icons.bar_chart_rounded,      Icons.bar_chart_outlined,         'Analytics'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 16,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(_items.length, (i) {
              final item     = _items[i];
              final selected = i == currentIndex;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    if (i != currentIndex) HapticFeedback.selectionClick();
                    onTap(i);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ── Active indicator bar ──────────────────────────
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: selected ? 20 : 0,
                        height: 2.5,
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(
                          color: _accent,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),

                      // ── Icon ─────────────────────────────────────────
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, anim) => ScaleTransition(
                          scale: Tween<double>(begin: 0.75, end: 1.0).animate(anim),
                          child: FadeTransition(opacity: anim, child: child),
                        ),
                        child: Icon(
                          selected ? item.activeIcon : item.icon,
                          key: ValueKey('${i}_$selected'),
                          color: selected ? _accent : _textSec,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 3),

                      // ── Label ─────────────────────────────────────────
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        style: TextStyle(
                          color: selected ? _accent : _textSec,
                          fontSize: 10,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                          letterSpacing: -0.1,
                        ),
                        child: Text(item.label),
                      ),
                    ],
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