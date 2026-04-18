import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/tags_table.dart';

part 'tags_dao.g.dart';

@DriftAccessor(tables: [Tags, ProblemTags])
class TagsDao extends DatabaseAccessor<AppDatabase> with _$TagsDaoMixin {
  TagsDao(super.db);

  /// All tags, grouped by category.
  Future<List<Tag>> getAllTags() => select(tags).get();

  /// Tags for a specific problem.
  Future<List<Tag>> getTagsForProblem(int problemId) async {
    final query = select(tags).join([
      innerJoin(
        problemTags,
        problemTags.tagId.equalsExp(tags.id),
      ),
    ])
      ..where(problemTags.problemId.equals(problemId));

    final rows = await query.get();
    return rows.map((row) => row.readTable(tags)).toList();
  }

  /// Tag IDs for a specific problem.
  Future<List<int>> getTagIdsForProblem(int problemId) async {
    final rows = await (select(problemTags)
          ..where((pt) => pt.problemId.equals(problemId)))
        .get();
    return rows.map((r) => r.tagId).toList();
  }

  /// Tags belonging to specific IDs (for user's learnt set display).
  Future<List<Tag>> getTagsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    return (select(tags)..where((t) => t.id.isIn(ids))).get();
  }

  /// Tags grouped by category (for onboarding checklist).
  Future<Map<String, List<Tag>>> getTagsByCategory() async {
    final allTags = await select(tags).get();
    final Map<String, List<Tag>> grouped = {};
    for (final tag in allTags) {
      final category = tag.category ?? 'Other';
      grouped.putIfAbsent(category, () => []).add(tag);
    }
    return grouped;
  }

  /// Primary tag for a problem.
  Future<Tag?> getPrimaryTagForProblem(int problemId) async {
    final query = select(tags).join([
      innerJoin(
        problemTags,
        problemTags.tagId.equalsExp(tags.id),
      ),
    ])
      ..where(
        problemTags.problemId.equals(problemId) &
            problemTags.isPrimary.equals(true),
      );

    final rows = await query.get();
    return rows.isEmpty ? null : rows.first.readTable(tags);
  }
}
