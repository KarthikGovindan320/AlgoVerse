import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/problem_model.dart';
import '../../data/models/tag_model.dart';
import '../../data/repositories/providers.dart';
import 'discover_state.dart';

class DiscoverNotifier extends StateNotifier<DiscoverState> {
  final Ref _ref;
  Timer? _searchDebounce;

  DiscoverNotifier(this._ref) : super(const DiscoverState()) {
    _init();
  }

  Future<void> _init() async {
    final repo = _ref.read(localRepositoryProvider);

    // Fetch learnt tag IDs from Firestore
    final learntIdsAsync = _ref.read(learntConceptsProvider);
    final learntIds = learntIdsAsync.value ?? [];

    // Fetch solved + bookmarked from Firestore
    final solvedAsync = _ref.read(solvedProblemsProvider);
    final solvedIds = Set<int>.from(solvedAsync.value ?? []);
    final bookmarkedAsync = _ref.read(bookmarksProvider);
    final bookmarkedIds = Set<int>.from(bookmarkedAsync.value ?? []);

    // Load tags for filter chips
    final List<TagModel> learntTags = await repo.getTagsByIds(learntIds);

    // Load concept-gated problems
    final List<ProblemModel> problems = await repo.getGatedProblems(learntIds);

    final dbUnavailable = learntIds.isNotEmpty && problems.isEmpty;

    state = state.copyWith(
      loading: false,
      dbUnavailable: dbUnavailable,
      allGatedProblems: problems,
      displayedProblems: _applyFilters(
        problems: problems,
        searchQuery: '',
        activeConcepts: {},
        difficulty: DifficultyFilter.all,
        status: StatusFilter.all,
        sort: SortOrder.bestMatch,
        solvedIds: solvedIds,
        bookmarkedIds: bookmarkedIds,
      ),
      learntTags: learntTags,
      solvedProblemIds: solvedIds,
      bookmarkedProblemIds: bookmarkedIds,
    );
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  void onSearchChanged(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 200), () {
      _applyAndSetFilters(searchQuery: query);
    });
  }

  void clearSearch() => _applyAndSetFilters(searchQuery: '');

  // ── Concept filter ─────────────────────────────────────────────────────────

  void toggleConceptFilter(int tagId) {
    final current = Set<int>.from(state.activeConcepts);
    if (current.contains(tagId)) {
      current.remove(tagId);
    } else {
      current.add(tagId);
    }
    _applyAndSetFilters(activeConcepts: current);
  }

  // ── Difficulty / Status / Sort ──────────────────────────────────────────────

  void setDifficulty(DifficultyFilter d) => _applyAndSetFilters(difficulty: d);
  void setStatus(StatusFilter s) => _applyAndSetFilters(status: s);
  void setSort(SortOrder s) => _applyAndSetFilters(sort: s);

  // ── Bookmark toggle (optimistic) ───────────────────────────────────────────

  Future<void> toggleBookmark(int problemId) async {
    final isBookmarked = state.bookmarkedProblemIds.contains(problemId);
    final updated = Set<int>.from(state.bookmarkedProblemIds);
    if (isBookmarked) {
      updated.remove(problemId);
    } else {
      updated.add(problemId);
    }
    state = state.copyWith(bookmarkedProblemIds: updated);

    try {
      final authAsync = _ref.read(authStateProvider);
      final user = authAsync.value;
      if (user != null) {
        final fs = _ref.read(firestoreServiceProvider);
        await fs.toggleBookmark(user.uid, problemId, !isBookmarked);
      }
    } catch (_) {
      // Revert on error
      state = state.copyWith(
        bookmarkedProblemIds: Set<int>.from(state.bookmarkedProblemIds)
          ..remove(problemId)
          ..addAll(isBookmarked ? [problemId] : []),
      );
    }
  }

  // ── Mark concept as learnt ─────────────────────────────────────────────────

  Future<int> markConceptAsLearnt(TagModel tag) async {
    // Save to Firestore
    final authAsync = _ref.read(authStateProvider);
    final user = authAsync.value;
    if (user != null) {
      final fs = _ref.read(firestoreServiceProvider);
      await fs.addLearntConcept(user.uid, tag.id);
    }

    // Re-compute gated problems with new concept added
    final repo = _ref.read(localRepositoryProvider);
    final newLearntIds = [
      ...state.learntTags.map((t) => t.id),
      tag.id,
    ];
    final newProblems = await repo.getGatedProblems(newLearntIds);
    final newTags = [...state.learntTags, tag];
    final previousCount = state.allGatedProblems.length;
    final newlyUnlocked = newProblems.length - previousCount;

    state = state.copyWith(
      allGatedProblems: newProblems,
      learntTags: newTags,
      displayedProblems: _applyFilters(
        problems: newProblems,
        searchQuery: state.searchQuery,
        activeConcepts: state.activeConcepts,
        difficulty: state.difficultyFilter,
        status: state.statusFilter,
        sort: state.sortOrder,
        solvedIds: state.solvedProblemIds,
        bookmarkedIds: state.bookmarkedProblemIds,
      ),
    );

    return newlyUnlocked.clamp(0, 9999);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  void _applyAndSetFilters({
    String? searchQuery,
    Set<int>? activeConcepts,
    DifficultyFilter? difficulty,
    StatusFilter? status,
    SortOrder? sort,
  }) {
    final newQuery = searchQuery ?? state.searchQuery;
    final newConcepts = activeConcepts ?? state.activeConcepts;
    final newDiff = difficulty ?? state.difficultyFilter;
    final newStatus = status ?? state.statusFilter;
    final newSort = sort ?? state.sortOrder;

    state = state.copyWith(
      searchQuery: newQuery,
      activeConcepts: newConcepts,
      difficultyFilter: newDiff,
      statusFilter: newStatus,
      sortOrder: newSort,
      displayedProblems: _applyFilters(
        problems: state.allGatedProblems,
        searchQuery: newQuery,
        activeConcepts: newConcepts,
        difficulty: newDiff,
        status: newStatus,
        sort: newSort,
        solvedIds: state.solvedProblemIds,
        bookmarkedIds: state.bookmarkedProblemIds,
      ),
    );
  }

  List<ProblemModel> _applyFilters({
    required List<ProblemModel> problems,
    required String searchQuery,
    required Set<int> activeConcepts,
    required DifficultyFilter difficulty,
    required StatusFilter status,
    required SortOrder sort,
    required Set<int> solvedIds,
    required Set<int> bookmarkedIds,
  }) {
    var filtered = problems;

    // Search filter
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      filtered = filtered.where((p) {
        return p.title.toLowerCase().contains(q) ||
            p.lcTags.any((t) => t.toLowerCase().contains(q)) ||
            p.id.toString().contains(q);
      }).toList();
    }

    // Difficulty filter
    if (difficulty != DifficultyFilter.all) {
      final d = difficulty.label;
      filtered = filtered.where((p) => p.difficulty == d).toList();
    }

    // Status filter
    switch (status) {
      case StatusFilter.solved:
        filtered = filtered.where((p) => solvedIds.contains(p.id)).toList();
      case StatusFilter.unsolved:
        filtered = filtered.where((p) => !solvedIds.contains(p.id)).toList();
      case StatusFilter.bookmarked:
        filtered =
            filtered.where((p) => bookmarkedIds.contains(p.id)).toList();
      case StatusFilter.all:
        break;
    }

    // Sort
    switch (sort) {
      case SortOrder.easyFirst:
        filtered.sort((a, b) => _diffOrder(a.difficulty)
            .compareTo(_diffOrder(b.difficulty)));
      case SortOrder.hardFirst:
        filtered.sort((a, b) => _diffOrder(b.difficulty)
            .compareTo(_diffOrder(a.difficulty)));
      case SortOrder.mostSolved:
        filtered.sort((a, b) =>
            (b.acceptanceRate ?? 0).compareTo(a.acceptanceRate ?? 0));
      case SortOrder.newest:
        filtered.sort((a, b) => b.id.compareTo(a.id));
      case SortOrder.bestMatch:
        // Default: sort by acceptance rate (approachable first)
        filtered.sort((a, b) =>
            (b.acceptanceRate ?? 0).compareTo(a.acceptanceRate ?? 0));
    }

    return filtered;
  }

  int _diffOrder(String diff) => switch (diff) {
        'Easy' => 0,
        'Medium' => 1,
        'Hard' => 2,
        _ => 3,
      };

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}

final discoverNotifierProvider =
    StateNotifierProvider<DiscoverNotifier, DiscoverState>((ref) {
  return DiscoverNotifier(ref);
});
