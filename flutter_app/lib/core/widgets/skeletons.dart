import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// A single shimmering placeholder block.
///
/// The sweep is driven by a repeating [AnimationController] whose direction
/// alternates, giving the "loading" pulse without any third-party dependency.
/// When the platform asks for reduced motion the block renders as a static tint
/// so there is no infinite animation.
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.height = 16,
    this.width,
    this.radius = 10,
  });

  final double height;
  final double? width;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!reduceMotion && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (reduceMotion && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      return Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      );
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_c.value);
        final base = AppColors.surfaceAlt;
        final highlight = Color.lerp(base, Colors.white, 0.7)!;
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [base, highlight, base],
              stops: [0.0, t, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// A card-shaped skeleton matching the height of a submission row, used while
/// history/feed data loads.
class SubmissionSkeleton extends StatelessWidget {
  const SubmissionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.raised(blur: 18, y: 8),
      ),
      child: Row(
        children: [
          const SkeletonBox(height: 44, width: 44, radius: 12),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(height: 16, width: 160),
                SizedBox(height: 10),
                SkeletonBox(height: 19, width: 220),
                SizedBox(height: 10),
                SkeletonBox(height: 18, width: 110),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A block of [SubmissionSkeleton]s, optionally capped by [count].
class SubmissionSkeletonList extends StatelessWidget {
  const SubmissionSkeletonList({super.key, this.count = 4});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [for (var i = 0; i < count; i++) const SubmissionSkeleton()],
    );
  }
}
