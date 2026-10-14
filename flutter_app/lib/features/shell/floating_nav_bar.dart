import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

/// One destination in the [FloatingNavBar].
class FloatingNavItem {
  const FloatingNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// Curved, floating emerald navigation bar with a central notch for the
/// "Collect census" FAB.
///
/// Uses [AutomaticNotchedShape] to paint the notch around the docked FAB.
/// Scaffold geometry is read only by the painter: BottomAppBar's clipper can
/// also read it during hit testing when a covered route becomes visible again,
/// violating Scaffold's paint-only geometry contract and freezing mouse input.
///
/// It expects exactly two [items]; the middle gap is where the FAB docks.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<FloatingNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    assert(items.length == 2, 'FloatingNavBar expects exactly two items');
    final theme = Theme.of(context).bottomAppBarTheme;
    return CustomPaint(
      painter: _NavBarPainter(
        geometry: Scaffold.geometryOf(context),
        color: theme.color ?? AppColors.primaryDark,
        shadowColor: theme.shadowColor ?? Colors.black,
        elevation: theme.elevation ?? 16,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: SizedBox(
            height: theme.height ?? 74,
            child: Row(
              children: [
                Expanded(
                  child: _BarItem(
                    item: items[0],
                    selected: selectedIndex == 0,
                    onTap: () => onSelect(0),
                  ),
                ),
                const SizedBox(width: 72),
                Expanded(
                  child: _BarItem(
                    item: items[1],
                    selected: selectedIndex == 1,
                    onTap: () => onSelect(1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarPainter extends CustomPainter {
  _NavBarPainter({
    required this.geometry,
    required this.color,
    required this.shadowColor,
    required this.elevation,
  }) : super(repaint: geometry);

  final ValueListenable<ScaffoldGeometry> geometry;
  final Color color;
  final Color shadowColor;
  final double elevation;

  static const _shape = AutomaticNotchedShape(
    RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    CircleBorder(),
  );

  @override
  void paint(Canvas canvas, Size size) {
    final value = geometry.value;
    final top = value.bottomNavigationBarTop;
    final button = top == null
        ? null
        : value.floatingActionButtonArea?.translate(0, -top);
    final path = _shape.getOuterPath(Offset.zero & size, button?.inflate(8));
    canvas.drawShadow(path, shadowColor, elevation, color.a < 1);
    canvas.drawPath(path, Paint()..color = color);
  }

  // The painted background has no input behavior. Only the navigation items
  // participate in hit testing, without querying the scaffold's geometry.
  @override
  bool hitTest(Offset position) => false;

  @override
  bool shouldRepaint(_NavBarPainter oldDelegate) =>
      geometry != oldDelegate.geometry ||
      color != oldDelegate.color ||
      shadowColor != oldDelegate.shadowColor ||
      elevation != oldDelegate.elevation;
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final FloatingNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Colors.white
        : Colors.white.withValues(alpha: 0.68);
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          // Keep the full icon + label stack comfortably inside the themed
          // BottomAppBar height, including devices with a larger text scale.
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  selected ? item.selectedIcon : item.icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 2),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
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

/// The circular "Collect census" action docked into the [FloatingNavBar].
class CollectFab extends StatelessWidget {
  const CollectFab({super.key, required this.onPressed, this.tooltip});

  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: onPressed,
      tooltip: tooltip,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 6,
      highlightElevation: 2,
      shape: const CircleBorder(),
      child: const Icon(Icons.add_rounded, size: 30),
    );
  }
}
