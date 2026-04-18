import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/repositories/providers.dart';
import '../../services/leetcode_service.dart';

class LeetCodeScreen extends ConsumerStatefulWidget {
  const LeetCodeScreen({super.key});

  @override
  ConsumerState<LeetCodeScreen> createState() => _LeetCodeScreenState();
}

class _LeetCodeScreenState extends ConsumerState<LeetCodeScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  bool _loading = false;
  bool _verified = false;
  int? _solvedCount;
  String? _errorText;

  // Spring animation for success card bounce
  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnim;

  final _leetcodeService = LeetCodeService();

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _bounceAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.04), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.04, end: 0.97), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.97, end: 1.01), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.01, end: 1.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _bounceController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  Future<void> _onConnect() async {
    final username = _controller.text.trim();
    if (username.isEmpty || _loading) return;

    _focusNode.unfocus();
    setState(() {
      _loading = true;
      _verified = false;
      _errorText = null;
      _solvedCount = null;
    });

    final result = await _leetcodeService.verifyUsername(username);

    if (!mounted) return;

    if (result.valid) {
      setState(() {
        _loading = false;
        _verified = true;
        _solvedCount = result.solvedCount;
      });
      _bounceController.forward(from: 0);
      // Persist to Firestore
      _saveLeetCode(username, result.solvedCount ?? 0);
    } else if (result.error == 'network') {
      setState(() {
        _loading = false;
        _errorText = "Couldn't reach LeetCode. Check your connection.";
      });
    } else {
      setState(() {
        _loading = false;
        _errorText = 'Username not found. Double-check your spelling.';
      });
    }
  }

  Future<void> _onContinue() async {
    context.go('/onboarding/concepts');
  }

  Future<void> _onSkip() async {
    // Proceed without setting a username
    context.go('/onboarding/concepts');
  }

  Future<void> _saveLeetCode(String username, int solvedCount) async {
    try {
      final authAsync = ref.read(authStateProvider);
      final user = authAsync.value;
      if (user == null) return;
      final fs = ref.read(firestoreServiceProvider);
      await fs.updateProfile(user.uid, {
        'leetcodeUsername': username,
        'leetcodeSolvedCount': solvedCount,
        'onboardingStep': 2,
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 64),

                // Header
                Text('Link your LeetCode account',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.screenTitle),
                const SizedBox(height: 12),
                Text(
                  "We'll sync your solved problems and track your\nprogress automatically.",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySecondary,
                ),
                const SizedBox(height: 48),

                // Card
                AnimatedBuilder(
                  animation: _bounceController,
                  builder: (context, child) =>
                      Transform.scale(scale: _bounceAnim.value, child: child),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Username input
                        _UsernameField(
                          controller: _controller,
                          focusNode: _focusNode,
                          enabled: !_loading && !_verified,
                          hasError: _errorText != null,
                          verified: _verified,
                          onChanged: (_) => setState(() => _errorText = null),
                        ),
                        const SizedBox(height: 8),

                        // Status text below input
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _errorText != null
                              ? _StatusText(
                                  key: const ValueKey('err'),
                                  text: _errorText!,
                                  color: AppColors.error,
                                )
                              : _verified && _solvedCount != null
                                  ? _StatusText(
                                      key: const ValueKey('ok'),
                                      text:
                                          'Found! $_solvedCount problems solved.',
                                      color: AppColors.primary,
                                      icon: Icons.check_circle_outline,
                                    )
                                  : const SizedBox(
                                      key: ValueKey('none'), height: 0),
                        ),

                        const SizedBox(height: 20),

                        // Connect / Continue button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: _verified
                              ? ElevatedButton(
                                  onPressed: _onContinue,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: AppColors.background,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('Continue →'),
                                )
                              : ElevatedButton(
                                  onPressed: _controller.text.trim().isEmpty ||
                                          _loading
                                      ? null
                                      : _onConnect,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.surfaceRaised,
                                    foregroundColor: AppColors.textPrimary,
                                    disabledBackgroundColor:
                                        AppColors.surfaceRaised,
                                    disabledForegroundColor: AppColors.textMuted,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    AppColors.textSecondary),
                                          ),
                                        )
                                      : const Text('Connect'),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Skip link
                TextButton(
                  onPressed: _loading ? null : _onSkip,
                  child: Text(
                    "Don't have one? Skip for now",
                    style: AppTextStyles.bodySecondary
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

class _UsernameField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final bool hasError;
  final bool verified;
  final ValueChanged<String> onChanged;

  const _UsernameField({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.hasError,
    required this.verified,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      onChanged: onChanged,
      autocorrect: false,
      style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'your-leetcode-username',
        hintStyle:
            AppTextStyles.body.copyWith(color: AppColors.textMuted),
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Text(
            'LC',
            style: AppTextStyles.label.copyWith(
              color: AppColors.amber,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        prefixIconConstraints:
            const BoxConstraints(minWidth: 48, minHeight: 48),
        suffixIcon: verified
            ? const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
            : null,
        filled: true,
        fillColor: AppColors.background,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: hasError ? AppColors.error : AppColors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: hasError ? AppColors.error : AppColors.primary,
            width: 1.5,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;

  const _StatusText({
    super.key,
    required this.text,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.caption.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
