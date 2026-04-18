import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/repositories/providers.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Settings', style: AppTextStyles.screenTitle),
      ),
      body: profileAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => const Center(
            child: Text('Could not load settings.',
                style: AppTextStyles.bodySecondary)),
        data: (profile) => _SettingsBody(profile: profile),
      ),
    );
  }
}

// ── Settings Body ─────────────────────────────────────────────────────────────

class _SettingsBody extends ConsumerStatefulWidget {
  final Map<String, dynamic>? profile;
  const _SettingsBody({required this.profile});

  @override
  ConsumerState<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends ConsumerState<_SettingsBody> {
  // AI Tutor prefs (local + Firestore)
  bool _socraticMode = true;
  bool _hintLadder = true;

  // Notifications
  bool _dailyReminder = true;
  bool _streakWarning = true;
  bool _srsReviews = true;
  bool _leetcodeAlerts = true;
  bool _friendActivity = false;
  bool _levelUpCelebrations = true;

  // Appearance
  bool _hapticFeedback = true;
  bool _reduceMotion = false;
  double _codeFontSize = 14.0;

  // Privacy
  bool _useSocialData = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _socraticMode = prefs.getBool('socratic_mode') ?? true;
      _hintLadder = prefs.getBool('hint_ladder') ?? true;
      _dailyReminder = prefs.getBool('notif_daily') ?? true;
      _streakWarning = prefs.getBool('notif_streak') ?? true;
      _srsReviews = prefs.getBool('notif_srs') ?? true;
      _leetcodeAlerts = prefs.getBool('notif_leetcode') ?? true;
      _friendActivity = prefs.getBool('notif_friends') ?? false;
      _levelUpCelebrations = prefs.getBool('notif_levelup') ?? true;
      _hapticFeedback = prefs.getBool('haptic') ?? true;
      _reduceMotion = prefs.getBool('reduce_motion') ?? false;
      _codeFontSize = prefs.getDouble('code_font_size') ?? 14.0;
      _useSocialData = prefs.getBool('use_social_data') ?? true;
    });
  }

  Future<void> _savePref(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
    if (value is double) await prefs.setDouble(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final displayName =
        widget.profile?['displayName'] as String? ?? 'User';
    final email = widget.profile?['email'] as String? ?? '';
    final avatarUrl = widget.profile?['avatarUrl'] as String? ?? '';
    final leetcodeUsername =
        widget.profile?['leetcodeUsername'] as String?;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      children: [
        // ── Section 1: Account ───────────────────────────────────────────
        _SectionHeader('ACCOUNT'),
        _SettingsCard(children: [
          // Profile row
          ListTile(
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.surfaceRaised,
              backgroundImage: avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl.isEmpty
                  ? Text(
                      displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : '?',
                      style: AppTextStyles.label
                          .copyWith(color: AppColors.primary),
                    )
                  : null,
            ),
            title: Text(displayName,
                style: AppTextStyles.label
                    .copyWith(color: AppColors.textPrimary)),
            subtitle: Text(email, style: AppTextStyles.caption),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted),
            onTap: () => context.push('/profile'),
          ),
          _Divider(),

          // LeetCode username
          ListTile(
            leading: const Icon(Icons.code_rounded,
                color: AppColors.textSecondary, size: 20),
            title: Text(
              leetcodeUsername != null
                  ? '@$leetcodeUsername'
                  : 'Link LeetCode',
              style: AppTextStyles.bodySecondary.copyWith(
                  color: leetcodeUsername != null
                      ? AppColors.textPrimary
                      : AppColors.textMuted),
            ),
            subtitle: leetcodeUsername != null
                ? const Text('Tap to change username',
                    style: AppTextStyles.caption)
                : null,
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted),
            onTap: () {},
          ),
          _Divider(),

          // Sign out
          ListTile(
            leading: const Icon(Icons.logout_rounded,
                color: AppColors.textSecondary, size: 20),
            title: const Text('Sign Out',
                style: AppTextStyles.bodySecondary),
            onTap: () => _signOut(context),
          ),
          _Divider(),

          // Delete account
          ListTile(
            leading: const Icon(Icons.delete_forever_rounded,
                color: AppColors.error, size: 20),
            title: const Text('Delete Account',
                style: TextStyle(
                    color: AppColors.error,
                    fontSize: 14,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500)),
            onTap: () => _deleteAccount(context),
          ),
        ]),
        const SizedBox(height: 24),

        // ── Section 2: AI Tutor ──────────────────────────────────────────
        _SectionHeader('AI TUTOR'),
        _SettingsCard(children: [
          _SwitchRow(
            title: 'Socratic Mode',
            subtitle: 'AI guides without giving direct answers',
            value: _socraticMode,
            onChanged: (v) {
              setState(() => _socraticMode = v);
              _savePref('socratic_mode', v);
            },
          ),
          _Divider(),
          _SwitchRow(
            title: 'Hint Ladder',
            subtitle: 'Progressive hints button in AI Tutor',
            value: _hintLadder,
            onChanged: (v) {
              setState(() => _hintLadder = v);
              _savePref('hint_ladder', v);
            },
          ),
          _Divider(),
          ListTile(
            dense: true,
            leading: const Icon(Icons.key_outlined,
                color: AppColors.textSecondary, size: 20),
            title: const Text('Gemini API Key',
                style: AppTextStyles.bodySecondary),
            subtitle: const Text('Use your own key for AI features',
                style: AppTextStyles.caption),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted),
            onTap: () => _showApiKeyDialog(context),
          ),
        ]),
        const SizedBox(height: 24),

        // ── Section 3: Notifications ─────────────────────────────────────
        _SectionHeader('NOTIFICATIONS'),
        _SettingsCard(children: [
          _SwitchRow(
            title: 'Daily reminder',
            value: _dailyReminder,
            onChanged: (v) {
              setState(() => _dailyReminder = v);
              _savePref('notif_daily', v);
            },
          ),
          _Divider(),
          _SwitchRow(
            title: 'Streak warning',
            subtitle: 'Alert at 9pm if no activity',
            value: _streakWarning,
            onChanged: (v) {
              setState(() => _streakWarning = v);
              _savePref('notif_streak', v);
            },
          ),
          _Divider(),
          _SwitchRow(
            title: 'SRS reviews due',
            value: _srsReviews,
            onChanged: (v) {
              setState(() => _srsReviews = v);
              _savePref('notif_srs', v);
            },
          ),
          _Divider(),
          _SwitchRow(
            title: 'LeetCode sync alerts',
            value: _leetcodeAlerts,
            onChanged: (v) {
              setState(() => _leetcodeAlerts = v);
              _savePref('notif_leetcode', v);
            },
          ),
          _Divider(),
          _SwitchRow(
            title: 'Friend activity',
            value: _friendActivity,
            onChanged: (v) {
              setState(() => _friendActivity = v);
              _savePref('notif_friends', v);
            },
          ),
          _Divider(),
          _SwitchRow(
            title: 'Level up celebrations',
            value: _levelUpCelebrations,
            onChanged: (v) {
              setState(() => _levelUpCelebrations = v);
              _savePref('notif_levelup', v);
            },
          ),
        ]),
        const SizedBox(height: 24),

        // ── Section 4: Connected Accounts ────────────────────────────────
        _SectionHeader('CONNECTED ACCOUNTS'),
        _SettingsCard(children: [
          _ConnectedAccountRow(
            icon: Icons.terminal_rounded,
            name: 'GitHub',
            status: 'Not connected',
            onTap: () {},
          ),
          _Divider(),
          _ConnectedAccountRow(
            icon: Icons.work_outline_rounded,
            name: 'LinkedIn',
            status: 'Not connected',
            onTap: () {},
          ),
          _Divider(),
          _ConnectedAccountRow(
            icon: Icons.bar_chart_rounded,
            name: 'Codeforces',
            status: 'Not connected',
            onTap: () {},
          ),
        ]),
        const SizedBox(height: 24),

        // ── Section 5: Privacy & Data ────────────────────────────────────
        _SectionHeader('PRIVACY & DATA'),
        _SettingsCard(children: [
          _SwitchRow(
            title: 'Use social data for recommendations',
            value: _useSocialData,
            onChanged: (v) {
              setState(() => _useSocialData = v);
              _savePref('use_social_data', v);
            },
          ),
          _Divider(),
          ListTile(
            dense: true,
            leading: const Icon(Icons.privacy_tip_outlined,
                color: AppColors.textSecondary, size: 20),
            title: const Text('What the app knows about me',
                style: AppTextStyles.bodySecondary),
            trailing: const Icon(Icons.chevron_right_rounded,
                color: AppColors.textMuted),
            onTap: () {},
          ),
          _Divider(),
          ListTile(
            dense: true,
            leading: const Icon(Icons.download_outlined,
                color: AppColors.textSecondary, size: 20),
            title: const Text('Export my data',
                style: AppTextStyles.bodySecondary),
            subtitle: const Text('Delivered to your email',
                style: AppTextStyles.caption),
            onTap: () {},
          ),
        ]),
        const SizedBox(height: 24),

        // ── Section 6: Appearance ────────────────────────────────────────
        _SectionHeader('APPEARANCE'),
        _SettingsCard(children: [
          _SwitchRow(
            title: 'Haptic feedback',
            value: _hapticFeedback,
            onChanged: (v) {
              setState(() => _hapticFeedback = v);
              _savePref('haptic', v);
            },
          ),
          _Divider(),
          _SwitchRow(
            title: 'Reduce motion',
            subtitle: 'Disables physics and page animations',
            value: _reduceMotion,
            onChanged: (v) {
              setState(() => _reduceMotion = v);
              _savePref('reduce_motion', v);
            },
          ),
          _Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Code font size',
                        style: AppTextStyles.bodySecondary),
                    Text('${_codeFontSize.round()}px',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textMuted)),
                  ],
                ),
                Slider(
                  value: _codeFontSize,
                  min: 12,
                  max: 20,
                  divisions: 8,
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.surfaceRaised,
                  onChanged: (v) {
                    setState(() => _codeFontSize = v);
                    _savePref('code_font_size', v);
                  },
                ),
              ],
            ),
          ),
        ]),
        const SizedBox(height: 24),

        // ── Section 7: About ─────────────────────────────────────────────
        _SectionHeader('ABOUT'),
        _SettingsCard(children: [
          ListTile(
            dense: true,
            title: const Text('App version',
                style: AppTextStyles.bodySecondary),
            trailing: Text('v1.0.0',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textMuted)),
          ),
          _Divider(),
          ListTile(
            dense: true,
            leading: const Icon(Icons.star_outline_rounded,
                color: AppColors.textSecondary, size: 20),
            title: const Text('Rate the app',
                style: AppTextStyles.bodySecondary),
            onTap: () {},
          ),
          _Divider(),
          ListTile(
            dense: true,
            leading: const Icon(Icons.share_outlined,
                color: AppColors.textSecondary, size: 20),
            title: const Text('Share the app',
                style: AppTextStyles.bodySecondary),
            onTap: () {},
          ),
          _Divider(),
          ListTile(
            dense: true,
            leading: const Icon(Icons.description_outlined,
                color: AppColors.textSecondary, size: 20),
            title: const Text('Privacy Policy',
                style: AppTextStyles.bodySecondary),
            onTap: () {},
          ),
          _Divider(),
          ListTile(
            dense: true,
            leading: const Icon(Icons.gavel_outlined,
                color: AppColors.textSecondary, size: 20),
            title: const Text('Terms of Service',
                style: AppTextStyles.bodySecondary),
            onTap: () {},
          ),
        ]),
      ],
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Sign out?',
            style: AppTextStyles.sectionHeader
                .copyWith(color: AppColors.textPrimary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppTextStyles.label
                    .copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(authServiceProvider).signOut();
      if (context.mounted) context.go('/onboarding/login');
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Delete account?',
              style: AppTextStyles.sectionHeader
                  .copyWith(color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This permanently deletes your profile, chat history, and progress. This cannot be undone.',
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Type DELETE to confirm',
                  hintStyle: AppTextStyles.caption,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.border),
                  ),
                ),
                onChanged: (_) => setLocal(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel',
                  style: AppTextStyles.label
                      .copyWith(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: controller.text == 'DELETE'
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.error)),
            ),
          ],
        ),
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(authServiceProvider).deleteAccount();
      if (context.mounted) context.go('/onboarding/login');
    }
  }

  Future<void> _showApiKeyDialog(BuildContext context) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Gemini API Key',
            style: AppTextStyles.sectionHeader
                .copyWith(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your own Gemini API key. Stored locally only.',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              obscureText: true,
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'AIza...',
                hintStyle: AppTextStyles.caption,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: AppTextStyles.label
                    .copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('gemini_api_key', controller.text);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save',
                style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

// ── Reusable components ───────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(
        text,
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textMuted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      dense: true,
      title: Text(title, style: AppTextStyles.bodySecondary),
      subtitle: subtitle != null
          ? Text(subtitle!, style: AppTextStyles.caption)
          : null,
      value: value,
      onChanged: onChanged,
      activeColor: AppColors.primary,
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(
        height: 1, color: AppColors.border, indent: 16, endIndent: 16);
  }
}

class _ConnectedAccountRow extends StatelessWidget {
  final IconData icon;
  final String name;
  final String status;
  final VoidCallback onTap;

  const _ConnectedAccountRow({
    required this.icon,
    required this.name,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: AppColors.textSecondary, size: 20),
      title:
          Text(name, style: AppTextStyles.bodySecondary),
      subtitle: Text(status, style: AppTextStyles.caption),
      trailing: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text('Connect'),
      ),
    );
  }
}
