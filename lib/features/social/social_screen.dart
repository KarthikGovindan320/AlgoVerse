import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/repositories/providers.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class SocialScreen extends ConsumerStatefulWidget {
  final String? duelId;
  const SocialScreen({super.key, this.duelId});

  @override
  ConsumerState<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends ConsumerState<SocialScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    // If opened from a duel deep link, jump to Duels tab
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.duelId != null ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('Social', style: AppTextStyles.screenTitle),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: AppTextStyles.label,
          tabs: const [
            Tab(text: 'Leaderboard'),
            Tab(text: 'Duels'),
            Tab(text: 'Cards'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _LeaderboardTab(ref: ref),
          _DuelsTab(ref: ref, initialDuelId: widget.duelId),
          const _LearningCardsTab(),
        ],
      ),
    );
  }
}

// ── TAB 1 — Leaderboard ───────────────────────────────────────────────────────

enum _LeaderboardScope { friends, global, concepts }

class _LeaderboardTab extends StatefulWidget {
  final WidgetRef ref;
  const _LeaderboardTab({required this.ref});

  @override
  State<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<_LeaderboardTab> {
  _LeaderboardScope _scope = _LeaderboardScope.friends;

  @override
  Widget build(BuildContext context) {
    final profileAsync = widget.ref.watch(userProfileProvider);
    final uid = widget.ref.watch(authStateProvider).value?.uid;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('This Week',
                        style: AppTextStyles.sectionHeader
                            .copyWith(color: AppColors.textPrimary)),
                    const Text('Resets Monday · Updated live',
                        style: AppTextStyles.caption),
                  ],
                ),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.person_add_outlined, size: 16),
                label: const Text('Invite'),
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Scope switcher
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: _LeaderboardScope.values.map((s) {
              final isActive = _scope == s;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _scope = s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                          color: isActive
                              ? AppColors.primary
                              : AppColors.border),
                    ),
                    child: Text(
                      s.name[0].toUpperCase() + s.name.substring(1),
                      style: AppTextStyles.caption.copyWith(
                          color: isActive
                              ? AppColors.primary
                              : AppColors.textSecondary),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),

        // Leaderboard list
        Expanded(
          child: uid == null
              ? const Center(
                  child: Text('Sign in to see leaderboard.',
                      style: AppTextStyles.bodySecondary))
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('leaderboard')
                      .doc('weekly')
                      .collection(_scope == _LeaderboardScope.global
                          ? 'global'
                          : 'users')
                      .orderBy('weeklyXp', descending: true)
                      .limit(50)
                      .snapshots(),
                  builder: (context, snap) {
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return _buildEmptyLeaderboard();
                    }

                    final myHandle =
                        profileAsync.value?['handle'] as String? ?? '';

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: docs.length,
                      itemBuilder: (ctx, i) {
                        final d = docs[i].data() as Map<String, dynamic>;
                        final handle =
                            d['handle'] as String? ?? 'user';
                        final isMe = handle == myHandle;
                        return _LeaderboardRow(
                          rank: i + 1,
                          displayName: d['displayName'] as String? ??
                              handle,
                          handle: handle,
                          level: d['level'] as String? ?? 'Beginner',
                          weeklyXp: d['weeklyXp'] as int? ?? 0,
                          streak: d['currentStreak'] as int? ?? 0,
                          avatarUrl: d['avatarUrl'] as String? ?? '',
                          isMe: isMe,
                          onTap: () =>
                              context.push('/profile/$handle'),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyLeaderboard() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.leaderboard_outlined,
              size: 48, color: AppColors.textMuted),
          const SizedBox(height: 16),
          const Text('No leaderboard data yet.',
              style: AppTextStyles.bodySecondary),
          const SizedBox(height: 8),
          const Text('Earn XP by solving problems to appear here.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.go('/discover'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.background,
            ),
            child: const Text('Find problems →'),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  final int rank;
  final String displayName;
  final String handle;
  final String level;
  final int weeklyXp;
  final int streak;
  final String avatarUrl;
  final bool isMe;
  final VoidCallback onTap;

  const _LeaderboardRow({
    required this.rank,
    required this.displayName,
    required this.handle,
    required this.level,
    required this.weeklyXp,
    required this.streak,
    required this.avatarUrl,
    required this.isMe,
    required this.onTap,
  });

  Color get _rankColor {
    if (rank == 1) return const Color(0xFFFFD700);
    if (rank == 2) return const Color(0xFFC0C0C0);
    if (rank == 3) return const Color(0xFFCD7F32);
    return AppColors.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMe ? AppColors.primary : AppColors.border,
            width: isMe ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '#$rank',
                style: AppTextStyles.label.copyWith(color: _rankColor),
              ),
            ),
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.surfaceRaised,
              backgroundImage: avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl.isEmpty
                  ? Text(
                      displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : '?',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.primary),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isMe ? '@$handle (You)' : displayName,
                    style: AppTextStyles.label.copyWith(
                      color: isMe
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(level,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textMuted)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$weeklyXp XP',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.primary)),
                Text('🔥 $streak',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.amber)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── TAB 2 — Duels ─────────────────────────────────────────────────────────────

class _DuelsTab extends StatelessWidget {
  final WidgetRef ref;
  final String? initialDuelId;

  const _DuelsTab({required this.ref, this.initialDuelId});

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).value?.uid;

    return uid == null
        ? const Center(
            child: Text('Sign in to view duels.',
                style: AppTextStyles.bodySecondary))
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Active Duels',
                          style: AppTextStyles.sectionHeader
                              .copyWith(color: AppColors.textPrimary)),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Challenge'),
                      onPressed: () => _showNewDuelSheet(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.background,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('duels')
                      .where('participants', arrayContains: uid)
                      .orderBy('createdAt', descending: true)
                      .snapshots(),
                  builder: (context, snap) {
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return _buildNoDuels(context);
                    }
                    return ListView.builder(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: docs.length,
                      itemBuilder: (ctx, i) {
                        final d =
                            docs[i].data() as Map<String, dynamic>;
                        return _DuelCard(
                          duelId: docs[i].id,
                          data: d,
                          myUid: uid,
                          isHighlighted:
                              docs[i].id == initialDuelId,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
  }

  Widget _buildNoDuels(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.sports_kabaddi_rounded,
              size: 48, color: AppColors.textMuted),
          const SizedBox(height: 16),
          const Text('No active duels.',
              style: AppTextStyles.bodySecondary),
          const SizedBox(height: 8),
          const Text('Challenge a friend to a head-to-head problem!',
              style: AppTextStyles.caption, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _showNewDuelSheet(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.background,
            ),
            child: const Text('+ Challenge a Friend'),
          ),
        ],
      ),
    );
  }

  void _showNewDuelSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _NewDuelSheet(),
    );
  }
}

class _DuelCard extends StatelessWidget {
  final String duelId;
  final Map<String, dynamic> data;
  final String myUid;
  final bool isHighlighted;

  const _DuelCard({
    required this.duelId,
    required this.data,
    required this.myUid,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    final status = data['status'] as String? ?? 'pending';
    final problemTitle =
        data['problemTitle'] as String? ?? 'Unknown Problem';
    final difficulty = data['difficulty'] as String? ?? 'Medium';
    final opponentName =
        data['opponentName'] as String? ?? 'Friend';
    final myAttempted = data['${myUid}_attempted'] as bool? ?? false;
    final opponentAttempted =
        data['opponent_attempted'] as bool? ?? false;
    final expiresAt = data['expiresAt'];
    String expiry = '';
    if (expiresAt is Timestamp) {
      final diff = expiresAt.toDate().difference(DateTime.now());
      if (diff.isNegative) {
        expiry = 'Expired';
      } else if (diff.inHours < 24) {
        expiry = 'Expires in ${diff.inHours}h ${diff.inMinutes % 60}m';
      } else {
        expiry = 'Expires in ${diff.inDays}d';
      }
    }

    final isCompleted = status == 'completed';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted
              ? AppColors.primary
              : isCompleted
                  ? AppColors.amber
                  : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sports_kabaddi_rounded,
                  size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                status.toUpperCase(),
                style: AppTextStyles.caption.copyWith(
                  color: isCompleted ? AppColors.amber : AppColors.primary,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (expiry.isNotEmpty)
                Text(expiry,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 8),
          Text('vs. $opponentName',
              style: AppTextStyles.label
                  .copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text('$problemTitle · $difficulty',
              style: AppTextStyles.bodySecondary),
          const SizedBox(height: 8),
          Row(
            children: [
              _AttemptPill(
                  label: 'You', attempted: myAttempted),
              const SizedBox(width: 8),
              _AttemptPill(
                  label: opponentName,
                  attempted: opponentAttempted),
            ],
          ),
          if (!isCompleted) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () =>
                    context.push('/problem/${data['problemSlug']}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                ),
                child: const Text('View Problem →'),
              ),
            ),
          ],
          if (isCompleted && data['aiVerdict'] != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                data['aiVerdict'] as String,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AttemptPill extends StatelessWidget {
  final String label;
  final bool attempted;
  const _AttemptPill({required this.label, required this.attempted});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: attempted
            ? AppColors.primary.withValues(alpha: 0.12)
            : AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: attempted ? AppColors.primary : AppColors.border,
        ),
      ),
      child: Text(
        attempted ? '$label ✓' : '$label: Pending',
        style: AppTextStyles.caption.copyWith(
          color: attempted ? AppColors.primary : AppColors.textMuted,
        ),
      ),
    );
  }
}

class _NewDuelSheet extends StatefulWidget {
  const _NewDuelSheet();

  @override
  State<_NewDuelSheet> createState() => _NewDuelSheetState();
}

class _NewDuelSheetState extends State<_NewDuelSheet> {
  int _step = 0;
  String _difficulty = 'Medium';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _step == 0
                ? 'Choose Difficulty'
                : 'Challenge is ready!',
            style: AppTextStyles.sectionHeader
                .copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),

          if (_step == 0) ...[
            Row(
              children: ['Easy', 'Medium', 'Hard'].map((d) {
                final isActive = _difficulty == d;
                return Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _difficulty = d),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10),
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.primary
                                  .withValues(alpha: 0.15)
                              : AppColors.surfaceRaised,
                          borderRadius:
                              BorderRadius.circular(8),
                          border: Border.all(
                            color: isActive
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        child: Center(
                          child: Text(d,
                              style: AppTextStyles.label
                                  .copyWith(
                                      color: isActive
                                          ? AppColors.primary
                                          : AppColors
                                              .textSecondary)),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => setState(() => _step = 1),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Next →'),
              ),
            ),
          ],

          if (_step == 1) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceRaised,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'A "$_difficulty" problem will be chosen for you and your friend. This feature requires the backend Cloud Function to be active.',
                style: AppTextStyles.bodySecondary,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.background,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Coming soon'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── TAB 3 — Learning Cards ────────────────────────────────────────────────────

class _LearningCardsTab extends ConsumerWidget {
  const _LearningCardsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).value?.uid;

    if (uid == null) {
      return const Center(
          child: Text('Sign in to see learning cards.',
              style: AppTextStyles.bodySecondary));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('learning_cards')
          .orderBy('createdAt', descending: true)
          .limit(40)
          .snapshots(),
      builder: (context, snap) {
        final docs = snap.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.library_books_outlined,
                    size: 48, color: AppColors.textMuted),
                const SizedBox(height: 16),
                const Text('No learning cards yet.',
                    style: AppTextStyles.bodySecondary),
                const SizedBox(height: 8),
                const Text(
                  'After solving a problem, share your key insight from the Notes tab.',
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final d = docs[i].data() as Map<String, dynamic>;
            return _LearningCard(
              cardId: docs[i].id,
              data: d,
              myUid: uid,
            );
          },
        );
      },
    );
  }
}

class _LearningCard extends StatelessWidget {
  final String cardId;
  final Map<String, dynamic> data;
  final String myUid;

  const _LearningCard({
    required this.cardId,
    required this.data,
    required this.myUid,
  });

  String _relativeTime(dynamic ts) {
    if (ts is! Timestamp) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(ts.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final authorName = data['displayName'] as String? ?? 'Someone';
    final handle = data['handle'] as String? ?? '';
    final insight = data['insight'] as String? ?? '';
    final problemTitle = data['problemTitle'] as String? ?? '';
    final problemSlug = data['problemSlug'] as String? ?? '';
    final tags = List<String>.from(data['tags'] ?? []);
    final likes = data['likes'] as int? ?? 0;
    final hasLiked =
        (data['likedBy'] as List<dynamic>?)?.contains(myUid) ?? false;
    final ts = data['createdAt'];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () =>
                      context.push('/profile/$handle'),
                  child: Text(
                    '$authorName · ${_relativeTime(ts)}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),

          // Insight quote
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              '"$insight"',
              style: AppTextStyles.body.copyWith(
                  color: AppColors.textPrimary,
                  fontStyle: FontStyle.italic),
            ),
          ),
          const SizedBox(height: 10),

          // Problem chip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: GestureDetector(
              onTap: () => context.push('/problem/$problemSlug'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceRaised,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(problemTitle,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.primary)),
              ),
            ),
          ),

          // Tags
          if (tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              child: Wrap(
                spacing: 4,
                children: tags.take(3).map((t) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color:
                          AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(t,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.primary,
                                fontSize: 10)),
                  );
                }).toList(),
              ),
            ),

          // Actions
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    hasLiked
                        ? Icons.favorite_rounded
                        : Icons.favorite_outline_rounded,
                    size: 18,
                    color: hasLiked
                        ? AppColors.error
                        : AppColors.textMuted,
                  ),
                  onPressed: () => _toggleLike(context),
                ),
                Text('$likes',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textMuted)),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline_rounded,
                      size: 18, color: AppColors.textMuted),
                  onPressed: () {},
                ),
                const Text('Reply',
                    style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleLike(BuildContext context) async {
    final hasLiked =
        (data['likedBy'] as List<dynamic>?)?.contains(myUid) ?? false;
    await FirebaseFirestore.instance
        .collection('learning_cards')
        .doc(cardId)
        .update({
      'likedBy': hasLiked
          ? FieldValue.arrayRemove([myUid])
          : FieldValue.arrayUnion([myUid]),
      'likes': FieldValue.increment(hasLiked ? -1 : 1),
    });
  }
}
