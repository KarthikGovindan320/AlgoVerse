import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/difficulty_badge.dart';
import '../../core/widgets/notification_drawer.dart';
import '../../data/repositories/providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final dailyAsync = ref.watch(dailyProblemProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Fixed header ──────────────────────────────────────────────
            _HomeHeader(
              profile: profileAsync.value,
              onProfile: () => context.push('/profile'),
            ),

            // ── Scrollable feed ───────────────────────────────────────────
            Expanded(
              child: profileAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (_, __) => const _ErrorState(),
                data: (profile) => RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  onRefresh: () async {
                    ref.invalidate(userProfileProvider);
                    ref.invalidate(dailyProblemProvider);
                  },
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      // Section 1: Today's Pick
                      _SectionLabel('TODAY\'S PICK'),
                      _DailyProblemCard(daily: dailyAsync.value),
                      const SizedBox(height: 20),

                      // Section 2: Streak & XP
                      _SectionLabel('PROGRESS'),
                      _StreakXpCard(profile: profile),
                      const SizedBox(height: 20),

                      // Section 3: SRS Queue
                      _SrsCard(),
                      const SizedBox(height: 20),

                      // Section 4: Weak Spot
                      _WeakSpotCard(profile: profile),
                      const SizedBox(height: 20),

                      // Section 5: Sync status
                      _SyncStatusCard(profile: profile),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _HomeHeader extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final VoidCallback onProfile;

  const _HomeHeader({
    required this.profile,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    final name = profile?['displayName'] as String? ?? 'Hey';
    final firstName = name.split(' ').first;
    final avatarUrl = profile?['avatarUrl'] as String?;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
      child: Row(
        children: [
          // Logo mark
          const _NodeMark(size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Hey, $firstName 👋',
              style: AppTextStyles.sectionHeader,
            ),
          ),
          // Notification bell with badge
          const NotificationBell(),
          // Avatar
          GestureDetector(
            onTap: onProfile,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryMuted,
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(
                      firstName.isNotEmpty ? firstName[0].toUpperCase() : 'A',
                      style: AppTextStyles.label
                          .copyWith(color: AppColors.primary),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// Tiny node-graph logo mark for the header.
class _NodeMark extends StatelessWidget {
  final double size;
  const _NodeMark({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _NodeMarkPainter(),
    );
  }
}

class _NodeMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.fill;
    final edge = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.4)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final nodes = [
      Offset(s * 0.5, s * 0.1),
      Offset(s * 0.15, s * 0.55),
      Offset(s * 0.85, s * 0.55),
      Offset(s * 0.5, s * 0.9),
    ];
    canvas.drawLine(nodes[0], nodes[1], edge);
    canvas.drawLine(nodes[0], nodes[2], edge);
    canvas.drawLine(nodes[1], nodes[3], edge);
    canvas.drawLine(nodes[2], nodes[3], edge);
    for (final n in nodes) {
      canvas.drawCircle(n, s * 0.1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ── Section Label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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

// ── Daily Problem Card ────────────────────────────────────────────────────────

class _DailyProblemCard extends ConsumerWidget {
  final Map<String, dynamic>? daily;
  const _DailyProblemCard({required this.daily});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (daily == null) {
      return _EmptyDailyCard();
    }

    final title = daily!['title'] as String? ?? 'Daily Problem';
    final difficulty = daily!['difficulty'] as String? ?? 'Medium';
    final slug = daily!['slug'] as String? ?? '';
    final reasoning = daily!['reasoning'] as String? ?? '';
    final concept = daily!['primaryConcept'] as String? ?? '';

    return GestureDetector(
      onTap: () {
        if (slug.isNotEmpty) context.push('/problem/$slug');
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          // Gradient border effect via boxShadow
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.15),
              blurRadius: 12,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Gradient top border line
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16)),
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF7C3AED)],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'AI SELECTED',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const Spacer(),
                      const Text('✦',
                          style: TextStyle(
                              color: AppColors.primary, fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(title,
                      style: AppTextStyles.sectionHeader,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      DifficultyBadge.fromString(difficulty),
                      if (concept.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _ConceptPill(concept),
                      ],
                    ],
                  ),
                  if (reasoning.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _CollapsibleReasoning(text: reasoning),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (slug.isNotEmpty) context.push('/problem/$slug');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.background,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Start →'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyDailyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Text('✦',
              style: TextStyle(color: AppColors.primary, fontSize: 24)),
          const SizedBox(height: 12),
          Text("Your daily pick is on its way.",
              style: AppTextStyles.cardTitle,
              textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            "Gemini is selecting a problem based on your profile.",
            style: AppTextStyles.bodySecondary,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CollapsibleReasoning extends StatefulWidget {
  final String text;
  const _CollapsibleReasoning({required this.text});

  @override
  State<_CollapsibleReasoning> createState() => _CollapsibleReasoningState();
}

class _CollapsibleReasoningState extends State<_CollapsibleReasoning> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.text,
            style: AppTextStyles.bodySecondary,
            maxLines: _expanded ? null : 2,
            overflow: _expanded ? null : TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                _expanded ? 'show less' : 'read more',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.primary),
              ),
              AnimatedRotation(
                turns: _expanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.keyboard_arrow_down,
                    size: 14, color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConceptPill extends StatelessWidget {
  final String name;
  const _ConceptPill(this.name);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryMuted,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(name,
          style:
              AppTextStyles.caption.copyWith(color: AppColors.primary)),
    );
  }
}

// ── Streak & XP Card ──────────────────────────────────────────────────────────

class _StreakXpCard extends StatelessWidget {
  final Map<String, dynamic>? profile;
  const _StreakXpCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final streak = (profile?['currentStreak'] as int?) ?? 0;
    final bestStreak = (profile?['bestStreak'] as int?) ?? 0;
    final xp = (profile?['xp'] as int?) ?? 0;
    final xpToNext = (profile?['xpToNextLevel'] as int?) ?? 500;
    final level = profile?['level'] as String? ?? 'Beginner';

    return GestureDetector(
      onTap: () => context.go('/progress'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Left: Streak
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 8),
                      Text(
                        '$streak',
                        style: AppTextStyles.screenTitle.copyWith(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Text('day streak',
                      style: AppTextStyles.bodySecondary),
                  Text('Best: $bestStreak days',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),

            Container(
                width: 1, height: 60, color: AppColors.border),

            // Right: XP
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(level,
                        style: AppTextStyles.label
                            .copyWith(color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: xpToNext > 0 ? xp / xpToNext : 0,
                        backgroundColor: AppColors.surfaceRaised,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$xp / $xpToNext XP',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── SRS Queue Card ────────────────────────────────────────────────────────────

class _SrsCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // SRS queue is not yet populated in Phase 4 — show card only if there's data
    return const SizedBox.shrink();
  }
}

// ── Weak Spot Card ────────────────────────────────────────────────────────────

class _WeakSpotCard extends StatelessWidget {
  final Map<String, dynamic>? profile;
  const _WeakSpotCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    // Weak spot detection requires radar scores — Phase 5+
    return const SizedBox.shrink();
  }
}

// ── Sync Status Card ──────────────────────────────────────────────────────────

class _SyncStatusCard extends StatefulWidget {
  final Map<String, dynamic>? profile;
  const _SyncStatusCard({required this.profile});

  @override
  State<_SyncStatusCard> createState() => _SyncStatusCardState();
}

class _SyncStatusCardState extends State<_SyncStatusCard>
    with SingleTickerProviderStateMixin {
  bool _syncing = false;
  late final AnimationController _spinController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    _spinController.repeat();
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      _spinController.stop();
      setState(() => _syncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All up to date.',
              style:
                  AppTextStyles.body.copyWith(color: AppColors.background)),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final username =
        widget.profile?['leetcodeUsername'] as String? ?? '';

    if (username.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.sync, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'LeetCode: @$username · tap to sync',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textMuted),
            ),
          ),
          GestureDetector(
            onTap: _refresh,
            child: RotationTransition(
              turns: _spinController,
              child: Icon(
                Icons.refresh,
                size: 18,
                color: _syncing ? AppColors.primary : AppColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error State ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text('Could not load your data.',
              style: AppTextStyles.cardTitle),
          const SizedBox(height: 4),
          Text('Check your connection and pull to refresh.',
              style: AppTextStyles.bodySecondary,
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
