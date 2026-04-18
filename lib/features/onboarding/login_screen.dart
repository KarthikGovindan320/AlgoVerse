import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/haptics.dart';
import '../../data/repositories/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = false;
  String? _error;

  // Button press animation
  late final AnimationController _pressController;
  late final Animation<double> _pressScale;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _pressScale = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  Future<void> _onGoogleSignIn() async {
    if (_loading) return;

    // Press animation + haptic
    await _pressController.forward();
    await AppHaptics.light();
    await _pressController.reverse();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      final cred = await authService.signInWithGoogle();

      if (!mounted) return;

      if (cred == null) {
        // User cancelled the sign-in sheet
        setState(() => _loading = false);
        return;
      }

      // Success → navigate to LeetCode step
      context.go('/onboarding/leetcode');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Sign in failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(flex: 3),

                // App title placeholder
                Text(
                  'AlgoVerse',
                  style: AppTextStyles.screenTitle.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 20,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),

                // Tagline
                Text(
                  'Learn smarter.\nOne concept at a time.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),

                const Spacer(flex: 4),

                // Google sign-in button
                AnimatedBuilder(
                  animation: _pressScale,
                  builder: (context, child) => Transform.scale(
                    scale: _pressScale.value,
                    child: child,
                  ),
                  child: _GoogleSignInButton(
                    loading: _loading,
                    onTap: _onGoogleSignIn,
                  ),
                ),

                // Error toast area
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _error != null
                      ? Padding(
                          key: const ValueKey('error'),
                          padding: const EdgeInsets.only(top: 16),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodySecondary
                                .copyWith(color: AppColors.error),
                          ),
                        )
                      : const SizedBox(key: ValueKey('no-error'), height: 0),
                ),

                const Spacer(flex: 2),

                // Legal note
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'By continuing, you agree to our Terms & Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textMuted),
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

class _GoogleSignInButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const _GoogleSignInButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: loading
              ? const Center(
                  key: ValueKey('loading'),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(AppColors.background),
                    ),
                  ),
                )
              : Row(
                  key: const ValueKey('label'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _GoogleLogo(size: 20),
                    const SizedBox(width: 12),
                    Text(
                      'Continue with Google',
                      style: AppTextStyles.body.copyWith(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Hand-drawn Google 'G' logo using CustomPaint.
class _GoogleLogo extends StatelessWidget {
  final double size;
  const _GoogleLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final center = Offset(s / 2, s / 2);
    final r = s / 2;

    // Clip to circle
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(
        Rect.fromCircle(center: center, radius: r),
        Radius.circular(r)));

    // White background
    canvas.drawCircle(center, r, Paint()..color = Colors.white);

    final strokeW = s * 0.095;

    void drawArc(Color color, double startAngle, double sweepAngle) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.butt;
      final rect =
          Rect.fromCircle(center: center, radius: r - strokeW / 2 - 1);
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
    }

    // Google colors: blue, red, yellow, green (approx arcs)
    const pi = 3.14159265358979;
    drawArc(const Color(0xFF4285F4), -pi / 2, pi * 0.5);  // top: blue
    drawArc(const Color(0xFFEA4335), 0, pi * 0.5);        // right: red
    drawArc(const Color(0xFFFBBC05), pi / 2, pi * 0.5);   // bottom: yellow
    drawArc(const Color(0xFF34A853), pi, pi * 0.5);       // left: green

    // White horizontal bar for the 'G' cutout
    canvas.drawRect(
      Rect.fromLTWH(center.dx - 1, center.dy - strokeW / 2, r + 1, strokeW),
      Paint()..color = Colors.white,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
