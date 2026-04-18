import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/repositories/providers.dart';

class ProfileScreen extends ConsumerWidget {
  final String? username;
  const ProfileScreen({super.key, this.username});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final solvedAsync = ref.watch(solvedProblemsProvider);
    final learntAsync = ref.watch(learntConceptsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          username != null ? '@$username' : 'My Profile',
          style: AppTextStyles.screenTitle,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined,
                color: AppColors.textSecondary),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => const Center(
            child: Text('Could not load profile.',
                style: AppTextStyles.bodySecondary)),
        data: (profile) {
          final solved = solvedAsync.value?.length ?? 0;
          final learnt = learntAsync.value?.length ?? 0;
          return _ProfileBody(
            profile: profile,
            solvedCount: solved,
            learntCount: learnt,
          );
        },
      ),
    );
  }
}

// ── Profile Body ──────────────────────────────────────────────────────────────

class _ProfileBody extends ConsumerWidget {
  final Map<String, dynamic>? profile;
  final int solvedCount;
  final int learntCount;

  const _ProfileBody({
    required this.profile,
    required this.solvedCount,
    required this.learntCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = profile?['displayName'] as String? ?? 'Learner';
    final handle = profile?['handle'] as String? ?? '';
    final avatarUrl = profile?['avatarUrl'] as String? ?? '';
    final level = profile?['level'] as String? ?? 'Beginner';
    final xp = profile?['xp'] as int? ?? 0;
    final streak = profile?['currentStreak'] as int? ?? 0;
    final openToWork = profile?['openToWork'] as bool? ?? false;
    final aboutMe = profile?['aboutMe'] as String? ?? '';
    final leetcodeUsername = profile?['leetcodeUsername'] as String?;
    final easy = profile?['easyCount'] as int? ?? 0;
    final medium = profile?['mediumCount'] as int? ?? 0;
    final hard = profile?['hardCount'] as int? ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar + Name ────────────────────────────────────────────────
          _ProfileHeader(
            displayName: displayName,
            handle: handle,
            avatarUrl: avatarUrl,
            level: level,
            openToWork: openToWork,
          ),
          const SizedBox(height: 20),

          // ── Quick Stats ──────────────────────────────────────────────────
          _QuickStatsRow(
            solved: solvedCount,
            learnt: learntCount,
            xp: xp,
            streak: streak,
          ),
          const SizedBox(height: 24),

          // ── Difficulty Breakdown ─────────────────────────────────────────
          _SectionLabel('SOLVED BY DIFFICULTY'),
          const SizedBox(height: 12),
          _DifficultyBreakdown(
            total: solvedCount,
            easy: easy,
            medium: medium,
            hard: hard,
          ),
          const SizedBox(height: 24),

          // ── About Me ─────────────────────────────────────────────────────
          if (aboutMe.isNotEmpty) ...[
            _SectionLabel('ABOUT'),
            const SizedBox(height: 8),
            _AboutCard(text: aboutMe),
            const SizedBox(height: 24),
          ],

          // ── Linked Accounts ──────────────────────────────────────────────
          _SectionLabel('LINKED ACCOUNTS'),
          const SizedBox(height: 12),
          _LinkedAccounts(
            profile: profile,
            leetcodeUsername: leetcodeUsername,
          ),
          const SizedBox(height: 24),

          // ── Danger Zone ──────────────────────────────────────────────────
          _SectionLabel('ACCOUNT'),
          const SizedBox(height: 12),
          _AccountActions(ref: ref),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Section Label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.caption.copyWith(
        color: AppColors.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ── Profile Header ────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final String displayName;
  final String handle;
  final String avatarUrl;
  final String level;
  final bool openToWork;

  const _ProfileHeader({
    required this.displayName,
    required this.handle,
    required this.avatarUrl,
    required this.level,
    required this.openToWork,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Avatar
        Stack(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.surfaceRaised,
              backgroundImage:
                  avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl.isEmpty
                  ? Text(
                      displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : '?',
                      style: AppTextStyles.sectionHeader
                          .copyWith(color: AppColors.primary, fontSize: 28),
                    )
                  : null,
            ),
            if (openToWork)
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.background, width: 2),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(displayName,
                  style: AppTextStyles.sectionHeader
                      .copyWith(color: AppColors.textPrimary)),
              if (handle.isNotEmpty)
                Text('@$handle',
                    style: AppTextStyles.bodySecondary
                        .copyWith(color: AppColors.textMuted)),
              const SizedBox(height: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4)),
                ),
                child: Text(
                  level,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.primary),
                ),
              ),
              if (openToWork) ...[
                const SizedBox(height: 4),
                Text('Open to work',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.primary)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ── Quick Stats ───────────────────────────────────────────────────────────────

class _QuickStatsRow extends StatelessWidget {
  final int solved;
  final int learnt;
  final int xp;
  final int streak;

  const _QuickStatsRow({
    required this.solved,
    required this.learnt,
    required this.xp,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _StatItem(value: '$solved', label: 'Solved'),
          _Divider(),
          _StatItem(value: '$learnt', label: 'Concepts'),
          _Divider(),
          _StatItem(value: '$xp', label: 'XP'),
          _Divider(),
          _StatItem(value: '🔥 $streak', label: 'Streak'),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: AppTextStyles.cardTitle
                  .copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 28, color: AppColors.border);
  }
}

// ── Difficulty Breakdown ──────────────────────────────────────────────────────

class _DifficultyBreakdown extends StatelessWidget {
  final int total;
  final int easy;
  final int medium;
  final int hard;

  const _DifficultyBreakdown({
    required this.total,
    required this.easy,
    required this.medium,
    required this.hard,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _DifficultyRow(
            label: 'Easy',
            count: easy,
            total: total,
            color: const Color(0xFF00B8A3),
          ),
          const SizedBox(height: 10),
          _DifficultyRow(
            label: 'Medium',
            count: medium,
            total: total,
            color: const Color(0xFFFFA116),
          ),
          const SizedBox(height: 10),
          _DifficultyRow(
            label: 'Hard',
            count: hard,
            total: total,
            color: const Color(0xFFFF375F),
          ),
        ],
      ),
    );
  }
}

class _DifficultyRow extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _DifficultyRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? (count / total).clamp(0.0, 1.0) : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(label,
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.textMuted)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: AppColors.surfaceRaised,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 28,
          child: Text(
            '$count',
            textAlign: TextAlign.right,
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

// ── About Card ────────────────────────────────────────────────────────────────

class _AboutCard extends StatelessWidget {
  final String text;
  const _AboutCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(text, style: AppTextStyles.bodySecondary),
    );
  }
}

// ── Linked Accounts ───────────────────────────────────────────────────────────

class _LinkedAccounts extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final String? leetcodeUsername;

  const _LinkedAccounts({required this.profile, required this.leetcodeUsername});

  @override
  Widget build(BuildContext context) {
    final linked =
        (profile?['linkedAccounts'] as Map<String, dynamic>?) ?? {};

    final platforms = [
      _PlatformInfo(
          key: '__leetcode',
          label: 'LeetCode',
          icon: Icons.code_rounded,
          connected: leetcodeUsername != null,
          subtitle: leetcodeUsername),
      _PlatformInfo(
          key: 'github',
          label: 'GitHub',
          icon: Icons.terminal_rounded,
          connected:
              (linked['github'] as Map<String, dynamic>?)?['connected'] ==
                  true),
      _PlatformInfo(
          key: 'linkedin',
          label: 'LinkedIn',
          icon: Icons.work_outline_rounded,
          connected:
              (linked['linkedin'] as Map<String, dynamic>?)?['connected'] ==
                  true),
      _PlatformInfo(
          key: 'codeforces',
          label: 'Codeforces',
          icon: Icons.bar_chart_rounded,
          connected:
              (linked['codeforces'] as Map<String, dynamic>?)?['connected'] ==
                  true),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: List.generate(platforms.length, (i) {
          final p = platforms[i];
          return Column(
            children: [
              _LinkedAccountRow(info: p),
              if (i < platforms.length - 1)
                Divider(
                    height: 1,
                    color: AppColors.border,
                    indent: 16,
                    endIndent: 16),
            ],
          );
        }),
      ),
    );
  }
}

class _PlatformInfo {
  final String key;
  final String label;
  final IconData icon;
  final bool connected;
  final String? subtitle;

  const _PlatformInfo({
    required this.key,
    required this.label,
    required this.icon,
    required this.connected,
    this.subtitle,
  });
}

class _LinkedAccountRow extends StatelessWidget {
  final _PlatformInfo info;
  const _LinkedAccountRow({required this.info});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(
        info.icon,
        color: info.connected ? AppColors.primary : AppColors.textMuted,
        size: 20,
      ),
      title: Text(info.label,
          style: AppTextStyles.bodySecondary
              .copyWith(color: AppColors.textPrimary)),
      subtitle: info.subtitle != null
          ? Text(info.subtitle!,
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.textMuted))
          : null,
      trailing: info.connected
          ? Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('Connected',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.primary)),
            )
          : Text('Connect',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textMuted)),
    );
  }
}

// ── Account Actions ───────────────────────────────────────────────────────────

class _AccountActions extends StatelessWidget {
  final WidgetRef ref;
  const _AccountActions({required this.ref});

  Future<void> _signOut(BuildContext context) async {
    final auth = ref.read(authServiceProvider);
    await auth.signOut();
    if (context.mounted) context.go('/onboarding/login');
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Delete account?',
            style: AppTextStyles.sectionHeader
                .copyWith(color: AppColors.textPrimary)),
        content: Text(
          'This permanently deletes your AlgoVerse data. This cannot be undone.',
          style: AppTextStyles.bodySecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: AppTextStyles.label
                    .copyWith(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Color(0xFFFF375F))),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final auth = ref.read(authServiceProvider);
      await auth.deleteAccount();
      if (context.mounted) context.go('/onboarding/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.logout_rounded,
                color: AppColors.textSecondary, size: 20),
            title: Text('Sign out',
                style: AppTextStyles.bodySecondary
                    .copyWith(color: AppColors.textPrimary)),
            onTap: () => _signOut(context),
          ),
          Divider(height: 1, color: AppColors.border, indent: 16, endIndent: 16),
          ListTile(
            dense: true,
            leading: const Icon(Icons.delete_outline_rounded,
                color: Color(0xFFFF375F), size: 20),
            title: const Text('Delete account',
                style: TextStyle(
                    color: Color(0xFFFF375F),
                    fontSize: 14,
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500)),
            onTap: () => _confirmDeleteAccount(context),
          ),
        ],
      ),
    );
  }
}
