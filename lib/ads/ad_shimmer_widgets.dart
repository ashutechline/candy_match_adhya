import 'package:flutter/material.dart';
import '../game_app/theme/candy_theme.dart';

class ShimmerContainer extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadius? borderRadius;
  const ShimmerContainer({
    super.key,
    required this.height,
    this.width,
    this.borderRadius,
  });
  @override
  State<ShimmerContainer> createState() => _ShimmerContainerState();
}

class _ShimmerContainerState extends State<ShimmerContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2C1E5C) : Colors.grey.shade200;
    final highlightColor = isDark ? const Color(0xFF5A499E) : Colors.white;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double t = Curves.easeInOutSine.transform(_controller.value);
        final double beginX = -1.6 + t * 2.6;
        final double endX = -1.0 + t * 2.6;
        return Container(
          width: widget.width ?? double.infinity,
          height: widget.height,
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
          ),
          child: ShaderMask(
            shaderCallback: (rect) {
              return LinearGradient(
                colors: [baseColor, highlightColor, baseColor],
                stops: const [0.3, 0.5, 0.7],
                begin: Alignment(beginX, -0.3),
                end: Alignment(endX, 0.3),
              ).createShader(rect);
            },
            blendMode: BlendMode.srcATop,
            child: Container(
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: widget.borderRadius ?? BorderRadius.circular(12),
              ),
            ),
          ),
        );
      },
    );
  }
}

class SmallAdCardShell extends StatelessWidget {
  final Widget child;
  const SmallAdCardShell({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4B3A8F), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class SmallNativeAdShimmer extends StatelessWidget {
  const SmallNativeAdShimmer({super.key});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ShimmerContainer(height: 20, width: 40, borderRadius: BorderRadius.circular(4)),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ShimmerContainer(height: 20),
                  const SizedBox(height: 12),
                  const ShimmerContainer(height: 16),
                  const SizedBox(height: 8),
                  const ShimmerContainer(height: 16, width: 140),
                ],
              ),
            ),
            const SizedBox(width: 16),
            const ShimmerContainer(height: 100, width: 100, borderRadius: BorderRadius.all(Radius.circular(12))),
          ],
        ),
        const SizedBox(height: 12),
        const ShimmerContainer(height: 48, borderRadius: BorderRadius.all(Radius.circular(12))),
      ],
    );
  }
}

class LargeNativeAdShimmer extends StatelessWidget {
  const LargeNativeAdShimmer({super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4B3A8F), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            ShimmerContainer(
              height: 160,
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            SizedBox(height: 16),
            ShimmerContainer(height: 20),
            SizedBox(height: 10),
            ShimmerContainer(height: 16),
            SizedBox(height: 10),
            ShimmerContainer(height: 16, width: 220),
            SizedBox(height: 16),
            ShimmerContainer(
              height: 50,
              borderRadius: BorderRadius.all(Radius.circular(10)),
            ),
          ],
        ),
      ),
    );
  }
}

class BannerAdShimmer extends StatelessWidget {
  const BannerAdShimmer({super.key});
  @override
  Widget build(BuildContext context) {
    return const ShimmerContainer(
      height: 50,
      width: 320,
      borderRadius: BorderRadius.all(Radius.circular(8)),
    );
  }
}
