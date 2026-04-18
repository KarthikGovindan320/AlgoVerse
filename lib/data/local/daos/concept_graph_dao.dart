import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/tags_table.dart';

part 'concept_graph_dao.g.dart';

@DriftAccessor(tables: [Tags, ConceptPrerequisites, ProblemTags])
class ConceptGraphDao extends DatabaseAccessor<AppDatabase>
    with _$ConceptGraphDaoMixin {
  ConceptGraphDao(super.db);

  /// All concept prerequisite edges.
  Future<List<ConceptPrerequisite>> getAllEdges() =>
      select(conceptPrerequisites).get();

  /// Prerequisites for a specific tag (what you must know first).
  Future<List<Tag>> getPrerequisitesFor(int tagId) async {
    final prereqRows = await (select(conceptPrerequisites)
          ..where((cp) => cp.tagId.equals(tagId)))
        .get();

    if (prereqRows.isEmpty) return [];

    final prereqIds = prereqRows.map((r) => r.requiresTagId).toList();
    return (select(tags)..where((t) => t.id.isIn(prereqIds))).get();
  }

  /// What concepts unlock once you learn the given tag (dependents).
  Future<List<Tag>> getDependentsOf(int tagId) async {
    final depRows = await (select(conceptPrerequisites)
          ..where((cp) => cp.requiresTagId.equals(tagId)))
        .get();

    if (depRows.isEmpty) return [];

    final depIds = depRows.map((r) => r.tagId).toList();
    return (select(tags)..where((t) => t.id.isIn(depIds))).get();
  }

  /// Full adjacency list for the concept graph screen.
  Future<Map<int, List<int>>> getAdjacencyList() async {
    final edges = await select(conceptPrerequisites).get();
    final Map<int, List<int>> adj = {};
    for (final edge in edges) {
      adj.putIfAbsent(edge.tagId, () => []).add(edge.requiresTagId);
    }
    return adj;
  }

  /// Number of problems per tag (for node sizing in graph).
  Future<Map<int, int>> getProblemCountPerTag() async {
    final rows = await customSelect(
      'SELECT tag_id, COUNT(*) as cnt FROM problem_tags GROUP BY tag_id',
      readsFrom: {problemTags},
    ).get();

    return {for (final row in rows) row.read<int>('tag_id'): row.read<int>('cnt')};
  }
}
