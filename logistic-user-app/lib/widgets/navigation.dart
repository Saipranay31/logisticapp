import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────
//  AppBottomNavBar — Reusable bottom navigation
//  with smooth animated tab switching
// ─────────────────────────────────────────────

class AppBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  // ── Same color system as all other screens ─────────────────
  static const Color _black = Color(0xFF0A0A0A);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _surface = Color(0xFFF7F7F7);
  static const Color _hint = Color(0xFF9E9E9E);
  static const Color _divider = Color(0xFFEEEEEE);

  static const _items = [
    _NavItem(icon: Icons.home_rounded,        activeIcon: Icons.home_rounded,         label: 'Home'),
    _NavItem(icon: Icons.add_circle_outline_rounded, activeIcon: Icons.add_circle_rounded, label: 'Book'),
    _NavItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded, label: 'History'),
    _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded,      label: 'Account'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _white,
        border: Border(top: BorderSide(color: _divider, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: List.generate(_items.length, (i) {
              return Expanded(
                child: _NavBarItem(
                  item: _items[i],
                  isActive: currentIndex == i,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onTap(i);
                  },
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── Single nav item data ───────────────────────────────────────
class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}

// ── Animated individual nav item ──────────────────────────────
class _NavBarItem extends StatefulWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  State<_NavBarItem> createState() => _NavBarItemState();
}

class _NavBarItemState extends State<_NavBarItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  static const Color _black = Color(0xFF0A0A0A);
  static const Color _hint = Color(0xFF9E9E9E);
  static const Color _surface = Color(0xFFF7F7F7);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    if (widget.isActive) _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(_NavBarItem old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _ctrl.forward(from: 0.0);
    } else if (!widget.isActive && old.isActive) {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Icon container ────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                height: 36,
                width: widget.isActive ? 56 : 40,
                decoration: BoxDecoration(
                  color: widget.isActive ? _black : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: ScaleTransition(
                    scale: widget.isActive ? _scaleAnim : const AlwaysStoppedAnimation(1.0),
                    child: Icon(
                      widget.isActive ? widget.item.activeIcon : widget.item.icon,
                      color: widget.isActive ? Colors.white : _hint,
                      size: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // ── Label ─────────────────────────────────────
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: widget.isActive ? _black : _hint,
                  fontSize: 10,
                  fontWeight: widget.isActive ? FontWeight.w700 : FontWeight.w400,
                  letterSpacing: widget.isActive ? 0.1 : 0,
                ),
                child: Text(widget.item.label),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
//  AnimatedTabSwitcher
//  Wraps IndexedStack with a smooth fade+slide
//  animation between tabs.
// ─────────────────────────────────────────────

class AnimatedTabSwitcher extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const AnimatedTabSwitcher({
    super.key,
    required this.index,
    required this.children,
  });

  @override
  State<AnimatedTabSwitcher> createState() => _AnimatedTabSwitcherState();
}

class _AnimatedTabSwitcherState extends State<AnimatedTabSwitcher>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.025),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(AnimatedTabSwitcher old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _ctrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: List.generate(widget.children.length, (i) {
        final isActive = i == widget.index;
        if (!isActive) {
          return Offstage(offstage: true, child: widget.children[i]);
        }
        return FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: widget.children[i],
          ),
        );
      }),
    );
  }
}