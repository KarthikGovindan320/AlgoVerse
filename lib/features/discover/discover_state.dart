import '../../data/models/problem_model.dart';
import '../../data/models/tag_model.dart';

enum DifficultyFilter { all, easy, medium, hard }

enum StatusFilter { all, unsolved, solved, bookmarked }

enum SortOrder { bestMatch, easyFirst, hardFirst, mostSolved, newest }

extension DifficultyFilterLabel on DifficultyFilter {
  String get label => switch (this) {
        DifficultyFilter.all => 'All',
        DifficultyFilter.easy => 'Easy',
        DifficultyFilter.medium => 'Medium',
        DifficultyFilter.hard => 'Hard',
      };
}

extension StatusFilterLabel on StatusFilter {
  String get label => switch (this) {
        StatusFilter.all => 'All',
        StatusFilter.unsolved => 'Unsolved',
        StatusFilter.solved => 'Solved',
        StatusFilter.bookmarked => 'Bookmarked',
      };
}

extension SortOrderLabel on SortOrder {
  String get label => switch (this) {
        SortOrder.bestMatch => 'Best Match',
        SortOrder.easyFirst => 'Easy First',
        SortOrder.hardFirst => 'Hard First',
        SortOrder.mostSolved => 'Most Solved',
        SortOrder.newest => 'Newest',
      };
}

class DiscoverState {
  final bool loading;
  final bool dbUnavailable; // true when SQLite DB hasn't been populated
  final List<ProblemModel> allGatedProblems; // full concept-gated pool
  final List<ProblemModel> displayedProblems; // after search + filter
  final List<TagModel> learntTags; // tags the user knows (from DB + Firestore)
  final Set<int> activeConcepts; // tag IDs currently filtering
  final String searchQuery;
  final DifficultyFilter difficultyFilter;
  final StatusFilter statusFilter;
  final SortOrder sortOrder;
  final Set<int> solvedProblemIds;
  final Set<int> bookmarkedProblemIds;

  const DiscoverState({
    this.loading = true,
    this.dbUnavailable = false,
    this.allGatedProblems = const [],
    this.displayedProblems = const [],
    this.learntTags = const [],
    this.activeConcepts = const {},
    this.searchQuery = '',
    this.difficultyFilter = DifficultyFilter.all,
    this.statusFilter = StatusFilter.all,
    this.sortOrder = SortOrder.bestMatch,
    this.solvedProblemIds = const {},
    this.bookmarkedProblemIds = const {},
  });

  DiscoverState copyWith({
    bool? loading,
    bool? dbUnavailable,
    List<ProblemModel>? allGatedProblems,
    List<ProblemModel>? displayedProblems,
    List<TagModel>? learntTags,
    Set<int>? activeConcepts,
    String? searchQuery,
    DifficultyFilter? difficultyFilter,
    StatusFilter? statusFilter,
    SortOrder? sortOrder,
    Set<int>? solvedProblemIds,
    Set<int>? bookmarkedProblemIds,
  }) {
    return DiscoverState(
      loading: loading ?? this.loading,
      dbUnavailable: dbUnavailable ?? this.dbUnavailable,
      allGatedProblems: allGatedProblems ?? this.allGatedProblems,
      displayedProblems: displayedProblems ?? this.displayedProblems,
      learntTags: learntTags ?? this.learntTags,
      activeConcepts: activeConcepts ?? this.activeConcepts,
      searchQuery: searchQuery ?? this.searchQuery,
      difficultyFilter: difficultyFilter ?? this.difficultyFilter,
      statusFilter: statusFilter ?? this.statusFilter,
      sortOrder: sortOrder ?? this.sortOrder,
      solvedProblemIds: solvedProblemIds ?? this.solvedProblemIds,
      bookmarkedProblemIds: bookmarkedProblemIds ?? this.bookmarkedProblemIds,
    );
  }
}
