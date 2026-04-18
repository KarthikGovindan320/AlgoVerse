import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/radar_chart.dart';
import '../../core/widgets/activity_heatmap.dart';
import '../../data/repositories/providers.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final radarAsync = ref.watch(radarScoresProvider);
    final solvedAsync = ref.watch(solvedProblemsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Progress', style: AppTextStyles.screenTitle),
        elevation: 0,
      ),
      body: profileAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.primary)),
        error: (_, __) => const Center(
            child: Text('Could not load progress.',
                style: AppTextStyles.bodySecondary)),
        data: (profile) {
          final radarScores = radarAsync.value;
          final solvedIds = solvedAsync.value ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Heatmap ──────────────────────────────────────────────
                _SectionHeader('ACTIVITY'),
                const SizedBox(height: 12),
                ActivityHeatmap(activity: const {}),
                const SizedBox(height: 12),
                _HeatmapStats(profile: profile, solved: solvedIds.length),
                const SizedBox(height: 24),

                // ── XP & Level ───────────────────────────────────────────
                _SectionHeader('XP & LEVEL'),
                const SizedBox(height: 12),
                _XpLevelCard(profile: profile),
                const SizedBox(height: 24),

                // ── Radar Chart ──────────────────────────────────────────
                _SectionHeader('SKILL RADAR'),
                const SizedBox(height: 12),
                _RadarSection(radarScores: radarScores),
                const SizedBox(height: 24),

                // ── Stats Summary ─────────────────────────────────────────
                _SectionHeader('STATS'),
                const SizedBox(height: 12),
                _StatsGrid(profile: profile, solvedCount: solvedIds.length),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

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

// ── Heatmap Stats ─────────────────────────────────────────────────────────────

class _HeatmapStats extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final int solved;

  const _HeatmapStats({required this.profile, required this.solved});

  @override
  Widget build(BuildContext context) {
    final streak = profile?['currentStreak'] as int? ?? 0;
    final bestStreak = profile?['bestStreak'] as int? ?? 0;

    return Row(
      children: [
        _StatPill('🔥 $streak day streak'),
        const SizedBox(width: 8),
        _StatPill('Best: $bestStreak days'),
        const SizedBox(width: 8),
        _StatPill('$solved solved'),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final String text;
  const _StatPill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(text,
          style: AppTextStyles.caption
              .copyWith(color: AppColors.textSecondary)),
    );
  }
}

// ── XP & Level Card ───────────────────────────────────────────────────────────

class _XpLevelCard extends StatelessWidget {
  final Map<String, dynamic>? profile;
  const _XpLevelCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    final xp = profile?['xp'] as int? ?? 0;
    final xpToNext = profile?['xpToNextLevel'] as int? ?? 500;
    final level = profile?['level'] as String? ?? 'Beginner';
    final levelNum = profile?['levelNumber'] as int? ?? 1;
    final progress = xpToNext > 0 ? (xp / xpToNext).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Arc progress gauge
          _XpArc(progress: progress, xp: xp),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(level,
                    style: AppTextStyles.sectionHeader
                        .copyWith(color: AppColors.primary)),
                Text('Level $levelNum',
                    style: AppTextStyles.bodySecondary),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.surfaceRaised,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.primary),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${xpToNext - xp} XP to next level',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _XpArc extends StatelessWidget {
  final double progress;
  final int xp;
  const _XpArc({required this.progress, required this.xp});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 80,
      child: CustomPaint(
        painter: _ArcPainter(progress: progress),
        child: Center(
          child: Text(
            '$xp\nXP',
            textAlign: TextAlign.center,
            style: AppTextStyles.label
                .copyWith(color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  _ArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const startAngle = pi * 0.75;
    const sweepMax = pi * 1.5;

    final bgPaint = Paint()
      ..color = AppColors.surfaceRaised
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fgPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
        startAngle, sweepMax, false, bgPaint);
    if (progress > 0) {
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius),
          startAngle, sweepMax * progress, false, fgPaint);
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}

// ── Radar Section ─────────────────────────────────────────────────────────────

class _RadarSection extends StatelessWidget {
  final Map<String, dynamic>? radarScores;
  const _RadarSection({required this.radarScores});

  List<double> _buildScores() {
    if (radarScores == null) return List.filled(6, 0.0);
    final axes = kRadarAxes;
    return axes.map((axis) {
      final raw = radarScores![axis];
      if (raw is num) return (raw.toDouble() / 100).clamp(0.0, 1.0);
      return 0.0;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scores = _buildScores();
    final hasData = scores.any((s) => s > 0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          if (!hasData)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  const Icon(Icons.radar_outlined,
                      size: 40, color: AppColors.textMuted),
                  const SizedBox(height: 8),
                  Text(
                    'Solve problems to build your radar.',
                    style: AppTextStyles.bodySecondary,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            RadarChart(scores: scores, size: 260),

          const SizedBox(height: 16),

          // Axis legend
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: List.generate(kRadarAxes.length, (i) {
              final score = scores[i];
              return _AxisLegendItem(
                name: kRadarAxes[i],
                score: (score * 100).round(),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _AxisLegendItem extends StatelessWidget {
  final String name;
  final int score;
  const _AxisLegendItem({required this.name, required this.score});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.7),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text('${name.split(' ').first}: $score',
            style:
                AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}

// ── Stats Grid ────────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final Map<String, dynamic>? profile;
  final int solvedCount;

  const _StatsGrid({required this.profile, required this.solvedCount});

  @override
  Widget build(BuildContext context) {
    final easy = profile?['easyCount'] as int? ?? 0;
    final medium = profile?['mediumCount'] as int? ?? 0;
    final hard = profile?['hardCount'] as int? ?? 0;
    final streak = profile?['currentStreak'] as int? ?? 0;

    final stats = [
      ('Total Solved', '$solvedCount'),
      ('Easy', '$easy'),
      ('Medium', '$medium'),
      ('Hard', '$hard'),
      ('Current Streak', '🔥 $streak days'),
      ('Best Streak', '${profile?['bestStreak'] ?? 0} days'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: GridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.6,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: stats
            .map((s) => _StatCell(label: s.$1, value: s.$2))
            .toList(),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  const _StatCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(value,
            style: AppTextStyles.cardTitle
                .copyWith(color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label,
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textMuted)),
      ],
    );
  }
}
