import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';

/// Full-screen splash shown once on app launch.
/// Pulses the node-graph icon, then navigates to the login screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    // Pulse: 1.0 → 1.08 → 1.0 over 800ms
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _opacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.85, 1.0, curve: Curves.easeOut),
      ),
    );

    // Start pulse at t=0, navigate at t=1800ms
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) context.go('/onboarding/login');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacity.value,
              child: Transform.scale(
                scale: _scale.value,
                child: child,
              ),
            );
          },
          child: const _NodeGraphIcon(size: 96),
        ),
      ),
    );
  }
}

/// Custom-painted node-graph icon representing a concept dependency graph.
class _NodeGraphIcon extends StatelessWidget {
  final double size;
  const _NodeGraphIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _NodeGraphPainter(),
    );
  }
}

class _NodeGraphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final primary = AppColors.primary;
    final muted = AppColors.textMuted;

    final edgePaint = Paint()
      ..color = muted.withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final nodePaint = Paint()
      ..color = primary
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = primary.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;

    // Node positions (proportional to size)
    final s = size.width;
    final nodes = [
      Offset(s * 0.5, s * 0.12),   // top center (root)
      Offset(s * 0.22, s * 0.42),  // left mid
      Offset(s * 0.78, s * 0.42),  // right mid
      Offset(s * 0.5, s * 0.65),   // center mid
      Offset(s * 0.18, s * 0.82),  // bottom left
      Offset(s * 0.5, s * 0.92),   // bottom center
      Offset(s * 0.82, s * 0.82),  // bottom right
    ];

    // Edges
    final edges = [
      [0, 1], [0, 2],
      [1, 3], [2, 3],
      [1, 4], [3, 5],
      [2, 6], [3, 6],
    ];

    for (final edge in edges) {
      canvas.drawLine(nodes[edge[0]], nodes[edge[1]], edgePaint);
    }

    // Nodes: glow ring + filled dot
    final radii = [9.0, 6.5, 6.5, 7.5, 5.5, 5.5, 5.5];
    for (int i = 0; i < nodes.length; i++) {
      canvas.drawCircle(nodes[i], radii[i] + 4, glowPaint);
      canvas.drawCircle(nodes[i], radii[i], nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
