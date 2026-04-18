import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/haptics.dart';
import '../../data/repositories/providers.dart';

// ── Static concept catalogue ─────────────────────────────────────────────────
// Used for onboarding. Names match the canonical names in graph_builder.py
// ALIASES / KNOWN_PREREQUISITES so they resolve correctly when the DB is live.

const _kCategories = <String, List<String>>{
  'Foundations': [
    'Arrays',
    'Strings',
    'Hash Maps / Hash Tables',
    'Two Pointers',
    'Prefix Sums',
    'Sliding Window (Variable Size)',
    'Sorting',
  ],
  'Data Structures': [
    'Linked Lists',
    'Stacks',
    'Queues',
    'Trees',
    'Binary Trees',
    'Heaps',
    'Priority Queue / Min-Heap',
    'Trie',
    'Graphs',
  ],
  'Algorithms': [
    'Binary Search',
    'Recursion',
    'Breadth-First Search',
    'Depth-First Search',
    'Backtracking',
    'Divide and Conquer',
    'Greedy',
  ],
  'Dynamic Programming': [
    'Dynamic Programming',
    'DP with Memoization',
    'DP (Bottom-Up / Tabulation)',
    'Bitmask DP',
    'Kadane\'s Algorithm',
  ],
  'Graph Algorithms': [
    'Topological Sort',
    'Union-Find / Disjoint Set',
    "Dijkstra's Algorithm",
    'Bellman-Ford',
    'Floyd-Warshall',
    "Kruskal's Algorithm",
  ],
  'Math & Advanced': [
    'Bit Manipulation',
    'Math',
    'Monotonic Stack',
    'Monotonic Queue / Deque',
    'Fast and Slow Pointers',
    'Cycle Detection',
  ],
};

/// Which concept names are in the "Foundations" category for "Select all basics"
const _kFoundationsCategory = 'Foundations';

// ── Screen ───────────────────────────────────────────────────────────────────

class ConceptsScreen extends ConsumerStatefulWidget {
  const ConceptsScreen({super.key});

  @override
  ConsumerState<ConceptsScreen> createState() => _ConceptsScreenState();
}

class _ConceptsScreenState extends ConsumerState<ConceptsScreen> {
  final Set<String> _selected = {};
  bool _saving = false;

  void _toggle(String name) {
    setState(() {
      if (_selected.contains(name)) {
        _selected.remove(name);
      } else {
        _selected.add(name);
      }
    });
    AppHaptics.selection();
  }

  Future<void> _selectAllBasics() async {
    final basics = _kCategories[_kFoundationsCategory] ?? [];
    // Cascade with 40ms delay per chip (left-to-right animation feel)
    for (int i = 0; i < basics.length; i++) {
      await Future.delayed(Duration(milliseconds: i * 40));
      if (!mounted) return;
      setState(() => _selected.add(basics[i]));
    }
  }

  Future<void> _onContinue() async {
    if (_saving) return;
    setState(() => _saving = true);

    try {
      final authAsync = ref.read(authStateProvider);
      final user = authAsync.value;
      if (user != null) {
        final fs = ref.read(firestoreServiceProvider);

        // Resolve selected concept names to tag IDs from the local DB
        final tagIds = await _resolveTagIds(_selected.toList());

        // Write learnt_concepts to Firestore
        await fs.setLearntConcepts(user.uid, tagIds);

        // Mark onboarding as complete
        await fs.updateProfile(user.uid, {
          'onboardingComplete': true,
          'onboardingStep': 3,
        });
      }
    } catch (_) {
      // Non-fatal: app still works without persisted concepts
    } finally {
      if (mounted) {
        // Navigate to home
        context.go('/home');
      }
    }
  }

  /// Try to resolve concept names to integer tag IDs from the local SQLite DB.
  /// Uses dynamic dispatch so it compiles before build_runner generates the
  /// Drift accessors; falls back to empty list if the DB isn't ready yet.
  Future<List<int>> _resolveTagIds(List<String> conceptNames) async {
    if (conceptNames.isEmpty) return [];
    try {
      final dynamic db = ref.read(localDatabaseProvider);
      final List<dynamic> allTags =
          await (db.tagsDao.getAllTags() as Future<List<dynamic>>);
      final nameToId = <String, int>{};
      for (final t in allTags) {
        final dynamic tag = t;
        final name = tag.name as String;
        final id = tag.id as int;
        nameToId[name.toLowerCase()] = id;
      }
      final ids = <int>[];
      for (final name in conceptNames) {
        final id = nameToId[name.toLowerCase()];
        if (id != null) ids.add(id);
      }
      return ids;
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('What do you already know?',
                      style: AppTextStyles.screenTitle),
                  const SizedBox(height: 8),
                  Text(
                    'This seeds your concept list. The app works best when it reflects your real starting point.',
                    style: AppTextStyles.bodySecondary,
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _selectAllBasics,
                    child: Text(
                      'Select all basics',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Scrollable chip grid
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: _kCategories.entries.map((entry) {
                  return _CategorySection(
                    category: entry.key,
                    concepts: entry.value,
                    selected: _selected,
                    onTap: _toggle,
                  );
                }).toList(),
              ),
            ),

            // Sticky footer
            _Footer(
              count: _selected.length,
              loading: _saving,
              onContinue: _onContinue,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category Section ─────────────────────────────────────────────────────────

class _CategorySection extends StatelessWidget {
  final String category;
  final List<String> concepts;
  final Set<String> selected;
  final ValueChanged<String> onTap;

  const _CategorySection({
    required this.category,
    required this.concepts,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
          child: Text(
            category.toUpperCase(),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: concepts
              .map((name) => _ConceptChip(
                    name: name,
                    isSelected: selected.contains(name),
                    onTap: () => onTap(name),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

// ── Concept Chip ──────────────────────────────────────────────────────────────

class _ConceptChip extends StatelessWidget {
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _ConceptChip({
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryMuted : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check, size: 12, color: AppColors.primary),
              const SizedBox(width: 4),
            ],
            Text(
              name,
              style: AppTextStyles.label.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Footer ───────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  final int count;
  final bool loading;
  final VoidCallback onContinue;

  const _Footer({
    required this.count,
    required this.loading,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Count
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Text(
                key: ValueKey(count),
                count == 0 ? 'No concepts selected' : '$count concepts selected',
                style: AppTextStyles.bodySecondary.copyWith(
                  color:
                      count == 0 ? AppColors.textMuted : AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Continue button
          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: loading ? null : onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.background,
                disabledBackgroundColor:
                    AppColors.primary.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.background),
                      ),
                    )
                  : const Text('Looks good →'),
            ),
          ),
        ],
      ),
    );
  }
}
