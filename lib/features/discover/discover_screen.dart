import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/difficulty_badge.dart';
import '../../data/models/problem_model.dart';
import '../../data/models/tag_model.dart';
import 'discover_notifier.dart';
import 'discover_state.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(discoverNotifierProvider);
    final notifier = ref.read(discoverNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Search bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: _SearchBar(
                controller: _searchController,
                onChanged: notifier.onSearchChanged,
                onClear: () {
                  _searchController.clear();
                  notifier.clearSearch();
                },
              ),
            ),

            // ── Concept filter chips ─────────────────────────────────────
            if (state.learntTags.isNotEmpty)
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: state.learntTags.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, i) {
                    final tag = state.learntTags[i];
                    final active = state.activeConcepts.contains(tag.id);
                    return _FilterChip(
                      label: tag.name,
                      active: active,
                      onTap: () => notifier.toggleConceptFilter(tag.id),
                    );
                  },
                ),
              ),

            // ── Filter bar ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: _FilterBar(
                difficulty: state.difficultyFilter,
                status: state.statusFilter,
                sort: state.sortOrder,
                onDifficultyChanged: notifier.setDifficulty,
                onStatusChanged: notifier.setStatus,
                onSortChanged: notifier.setSort,
              ),
            ),

            // ── Results count ─────────────────────────────────────────────
            if (!state.loading && !state.dbUnavailable)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      '${state.displayedProblems.length} problems',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),

            // ── Main content ─────────────────────────────────────────────
            Expanded(
              child: state.loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    )
                  : state.dbUnavailable
                      ? const _DbUnavailableState()
                      : state.displayedProblems.isEmpty
                          ? _EmptyState(
                              hasLearntConcepts: state.learntTags.isNotEmpty,
                              hasSearch: state.searchQuery.isNotEmpty,
                              searchQuery: state.searchQuery,
                              onClearFilters: () {
                                _searchController.clear();
                                notifier.clearSearch();
                                notifier.setDifficulty(DifficultyFilter.all);
                                notifier.setStatus(StatusFilter.all);
                              },
                            )
                          : _ProblemList(
                              problems: state.displayedProblems,
                              solvedIds: state.solvedProblemIds,
                              bookmarkedIds: state.bookmarkedProblemIds,
                              searchQuery: state.searchQuery,
                              onBookmark: notifier.toggleBookmark,
                              onMarkLearnt: (tag) async {
                                final count =
                                    await notifier.markConceptAsLearnt(tag);
                                if (context.mounted) {
                                  _showMarkLearntToast(
                                      context, tag.name, count);
                                }
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMarkLearntToast(
      BuildContext context, String conceptName, int newCount) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "'$conceptName' added to your concepts. $newCount new problems unlocked.",
          style: AppTextStyles.body.copyWith(color: AppColors.background),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ── Search Bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'Search by concept, title, or tag...',
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textMuted),
        prefixIcon:
            const Icon(Icons.search, color: AppColors.textMuted, size: 20),
        suffixIcon: ValueListenableBuilder(
          valueListenable: controller,
          builder: (_, val, __) => val.text.isNotEmpty
              ? GestureDetector(
                  onTap: onClear,
                  child: const Icon(Icons.close,
                      color: AppColors.textMuted, size: 18),
                )
              : const SizedBox.shrink(),
        ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

// ── Filter Chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primaryMuted : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: active ? AppColors.primary : AppColors.border,
            width: active ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTextStyles.label.copyWith(
                color:
                    active ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            if (active) ...[
              const SizedBox(width: 4),
              const Icon(Icons.close, size: 12, color: AppColors.primary),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Filter Bar ────────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  final DifficultyFilter difficulty;
  final StatusFilter status;
  final SortOrder sort;
  final ValueChanged<DifficultyFilter> onDifficultyChanged;
  final ValueChanged<StatusFilter> onStatusChanged;
  final ValueChanged<SortOrder> onSortChanged;

  const _FilterBar({
    required this.difficulty,
    required this.status,
    required this.sort,
    required this.onDifficultyChanged,
    required this.onStatusChanged,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _DropdownPill<DifficultyFilter>(
          value: difficulty,
          items: DifficultyFilter.values,
          label: (v) => v.label,
          onChanged: onDifficultyChanged,
        ),
        const SizedBox(width: 8),
        _DropdownPill<StatusFilter>(
          value: status,
          items: StatusFilter.values,
          label: (v) => v.label,
          onChanged: onStatusChanged,
        ),
        const SizedBox(width: 8),
        _DropdownPill<SortOrder>(
          value: sort,
          items: SortOrder.values,
          label: (v) => v.label,
          onChanged: onSortChanged,
        ),
      ],
    );
  }
}

class _DropdownPill<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final String Function(T) label;
  final ValueChanged<T> onChanged;

  const _DropdownPill({
    required this.value,
    required this.items,
    required this.label,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final RenderBox box = context.findRenderObject() as RenderBox;
        final offset = box.localToGlobal(Offset.zero);
        final result = await showMenu<T>(
          context: context,
          position: RelativeRect.fromLTRB(
            offset.dx,
            offset.dy + box.size.height + 4,
            0,
            0,
          ),
          color: AppColors.surfaceRaised,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          items: items
              .map((item) => PopupMenuItem<T>(
                    value: item,
                    child: Text(
                      label(item),
                      style: AppTextStyles.body.copyWith(
                        color: item == value
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      ),
                    ),
                  ))
              .toList(),
        );
        if (result != null) onChanged(result);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label(value), style: AppTextStyles.label),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down,
                size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

// ── Problem List ──────────────────────────────────────────────────────────────

class _ProblemList extends StatelessWidget {
  final List<ProblemModel> problems;
  final Set<int> solvedIds;
  final Set<int> bookmarkedIds;
  final String searchQuery;
  final ValueChanged<int> onBookmark;
  final Future<void> Function(TagModel) onMarkLearnt;

  const _ProblemList({
    required this.problems,
    required this.solvedIds,
    required this.bookmarkedIds,
    required this.searchQuery,
    required this.onBookmark,
    required this.onMarkLearnt,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: problems.length,
      itemBuilder: (context, i) {
        final problem = problems[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _ProblemCard(
            problem: problem,
            isSolved: solvedIds.contains(problem.id),
            isBookmarked: bookmarkedIds.contains(problem.id),
            searchQuery: searchQuery,
            onTap: () => context.push('/problem/${problem.slug}'),
            onBookmark: () => onBookmark(problem.id),
            onMarkLearnt: onMarkLearnt,
          ),
        );
      },
    );
  }
}

// ── Problem Card ──────────────────────────────────────────────────────────────

class _ProblemCard extends StatelessWidget {
  final ProblemModel problem;
  final bool isSolved;
  final bool isBookmarked;
  final String searchQuery;
  final VoidCallback onTap;
  final VoidCallback onBookmark;
  final Future<void> Function(TagModel) onMarkLearnt;

  const _ProblemCard({
    required this.problem,
    required this.isSolved,
    required this.isBookmarked,
    required this.searchQuery,
    required this.onTap,
    required this.onBookmark,
    required this.onMarkLearnt,
  });

  Color get _diffColor => switch (problem.difficulty) {
        'Easy' => AppColors.easy,
        'Medium' => AppColors.medium,
        'Hard' => AppColors.hard,
        _ => AppColors.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showContextMenu(context),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left difficulty color bar
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: _diffColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + icons
                    Row(
                      children: [
                        Expanded(
                          child: _HighlightText(
                            text: '#${problem.id}  ${problem.title}',
                            highlight: searchQuery,
                            style: AppTextStyles.cardTitle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            AppHaptics.light();
                            onBookmark();
                          },
                          child: Icon(
                            isBookmarked
                                ? Icons.bookmark
                                : Icons.bookmark_border,
                            size: 18,
                            color: isBookmarked
                                ? AppColors.amber
                                : AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: isSolved
                              ? AppColors.primary
                              : AppColors.textMuted.withValues(alpha: 0.3),
                        ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Concept chips (LC tags as fallback)
                    if (problem.lcTags.isNotEmpty)
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: problem.lcTags.take(4).map((tag) {
                          return _SmallChip(name: tag);
                        }).toList(),
                      ),

                    const SizedBox(height: 8),

                    // Bottom strip: difficulty badge + acceptance rate
                    Row(
                      children: [
                        DifficultyBadge.fromString(problem.difficulty),
                        const SizedBox(width: 8),
                        if (problem.acceptanceRate != null)
                          Text(
                            '${(problem.acceptanceRate! * 100).toStringAsFixed(1)}% acceptance',
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textMuted),
                          ),
                      ],
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

  void _showContextMenu(BuildContext context) {
    AppHaptics.medium();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ContextMenu(
        title: problem.title,
        isBookmarked: isBookmarked,
        onView: () {
          Navigator.pop(context);
          onTap();
        },
        onBookmark: () {
          Navigator.pop(context);
          onBookmark();
        },
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String name;
  const _SmallChip({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        name,
        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

// ── Context Menu ──────────────────────────────────────────────────────────────

class _ContextMenu extends StatelessWidget {
  final String title;
  final bool isBookmarked;
  final VoidCallback onView;
  final VoidCallback onBookmark;

  const _ContextMenu({
    required this.title,
    required this.isBookmarked,
    required this.onView,
    required this.onBookmark,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              title,
              style: AppTextStyles.cardTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(color: AppColors.border, height: 1),
          ListTile(
            leading: const Icon(Icons.open_in_new,
                color: AppColors.textPrimary, size: 20),
            title: Text('View Problem', style: AppTextStyles.body),
            onTap: onView,
          ),
          ListTile(
            leading: Icon(
              isBookmarked ? Icons.bookmark_remove : Icons.bookmark_add,
              color: AppColors.textPrimary,
              size: 20,
            ),
            title: Text(
              isBookmarked ? 'Remove bookmark' : 'Bookmark',
              style: AppTextStyles.body,
            ),
            onTap: onBookmark,
          ),
          ListTile(
            leading: const Icon(Icons.close,
                color: AppColors.textMuted, size: 20),
            title: Text('Cancel',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textMuted)),
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Highlight Text ────────────────────────────────────────────────────────────

class _HighlightText extends StatelessWidget {
  final String text;
  final String highlight;
  final TextStyle style;

  const _HighlightText({
    required this.text,
    required this.highlight,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (highlight.isEmpty) {
      return Text(text,
          style: style, maxLines: 2, overflow: TextOverflow.ellipsis);
    }
    final lower = text.toLowerCase();
    final idx = lower.indexOf(highlight.toLowerCase());
    if (idx < 0) {
      return Text(text,
          style: style, maxLines: 2, overflow: TextOverflow.ellipsis);
    }
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: text.substring(0, idx), style: style),
        TextSpan(
          text: text.substring(idx, idx + highlight.length),
          style: style.copyWith(
              fontWeight: FontWeight.w700, color: AppColors.primary),
        ),
        TextSpan(text: text.substring(idx + highlight.length), style: style),
      ]),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// ── Empty States ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasLearntConcepts;
  final bool hasSearch;
  final String searchQuery;
  final VoidCallback onClearFilters;

  const _EmptyState({
    required this.hasLearntConcepts,
    required this.hasSearch,
    required this.searchQuery,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasLearntConcepts) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.hub_outlined,
                  size: 64, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Text("You haven't added any concepts yet.",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.cardTitle),
              const SizedBox(height: 8),
              Text(
                "Go to the Concept Graph to explore and mark what you know.",
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => context.go('/concepts'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.background,
                ),
                child: const Text('Open Concept Graph'),
              ),
            ],
          ),
        ),
      );
    }

    if (hasSearch) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off,
                  size: 64, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Text("No problems found for '$searchQuery'.",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.cardTitle),
              const SizedBox(height: 8),
              Text(
                "Try a different concept name or problem title.",
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySecondary,
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_list_off,
                size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text("No problems match all selected concepts.",
                textAlign: TextAlign.center,
                style: AppTextStyles.cardTitle),
            const SizedBox(height: 8),
            Text(
              "Try removing a concept filter, or learn new concepts to unlock more problems.",
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: onClearFilters,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
              ),
              child: const Text('Clear filters'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DbUnavailableState extends StatelessWidget {
  const _DbUnavailableState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.storage_outlined,
                size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text("Problem database not ready",
                textAlign: TextAlign.center,
                style: AppTextStyles.cardTitle),
            const SizedBox(height: 8),
            Text(
              "Run the pipeline scripts to populate the local database, then copy it to assets/data/.",
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySecondary,
            ),
          ],
        ),
      ),
    );
  }
}
