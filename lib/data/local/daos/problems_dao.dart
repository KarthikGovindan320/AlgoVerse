import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/problems_table.dart';
import '../tables/tags_table.dart';

part 'problems_dao.g.dart';

@DaoAccessor(tables: [Problems, ProblemTags, Tags])
class ProblemsDao extends DatabaseAccessor<AppDatabase>
    with _$ProblemsDaoMixin {
  ProblemsDao(super.db);

  /// Fetch all non-premium problems (no concept gating — used for full list).
  Future<List<Problem>> getAllProblems() =>
      (select(problems)..where((p) => p.isPremium.equals(false))).get();

  /// Fetch a single problem by slug.
  Future<Problem?> getProblemBySlug(String slug) =>
      (select(problems)..where((p) => p.slug.equals(slug)))
          .getSingleOrNull();

  /// Fetch a single problem by ID.
  Future<Problem?> getProblemById(int id) =>
      (select(problems)..where((p) => p.id.equals(id))).getSingleOrNull();

  /// Concept-gated problem list:
  /// Returns problems where ALL required tags are in the user's learnt set.
  /// i.e. problems with NO tags outside the learnt set.
  Future<List<Problem>> getGatedProblems(List<int> learntTagIds) async {
    if (learntTagIds.isEmpty) return [];

    // Problems where every tag they have IS in learntTagIds
    final query = customSelect(
      '''
      SELECT p.* FROM problems p
      WHERE p.is_premium = 0
        AND p.tagging_skipped = 0
        AND p.id NOT IN (
          SELECT pt.problem_id FROM problem_tags pt
          WHERE pt.tag_id NOT IN (${learntTagIds.map((_) => '?').join(',')})
        )
      ORDER BY p.acceptance_rate DESC
      ''',
      variables: learntTagIds.map((id) => Variable.withInt(id)).toList(),
      readsFrom: {problems, problemTags},
    );

    final rows = await query.get();
    return rows.map((row) => Problem.fromData(row.data)).toList();
  }

  /// Search problems by title (case-insensitive LIKE).
  Future<List<Problem>> searchByTitle(String query) =>
      (select(problems)
            ..where((p) =>
                p.title.like('%$query%') & p.isPremium.equals(false)))
          .get();

  /// Fetch problems solved by the user (by IDs from Firestore).
  Future<List<Problem>> getProblemsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    return (select(problems)..where((p) => p.id.isIn(ids))).get();
  }

  /// Problems filtered by a specific tag ID.
  Future<List<Problem>> getProblemsByTag(int tagId, List<int> learntTagIds) async {
    final query = customSelect(
      '''
      SELECT p.* FROM problems p
      INNER JOIN problem_tags pt ON p.id = pt.problem_id
      WHERE pt.tag_id = ?
        AND p.is_premium = 0
        AND p.id NOT IN (
          SELECT pt2.problem_id FROM problem_tags pt2
          WHERE pt2.tag_id NOT IN (${learntTagIds.map((_) => '?').join(',')})
        )
      ORDER BY p.difficulty ASC
      ''',
      variables: [
        Variable.withInt(tagId),
        ...learntTagIds.map((id) => Variable.withInt(id)),
      ],
      readsFrom: {problems, problemTags},
    );

    final rows = await query.get();
    return rows.map((row) => Problem.fromData(row.data)).toList();
  }
}
