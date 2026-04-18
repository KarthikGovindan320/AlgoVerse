import '../models/problem_model.dart';
import '../models/tag_model.dart';

/// Wraps the Drift [AppDatabase] using dynamic dispatch so the rest of the app
/// compiles and runs without requiring [build_runner] to generate the Drift
/// boilerplate. Once [build_runner] is executed, all dynamic calls resolve
/// correctly to the generated accessors.
class LocalRepository {
  final dynamic _db;

  const LocalRepository(this._db);

  // ── Problems ─────────────────────────────────────────────────────────────

  Future<List<ProblemModel>> getGatedProblems(List<int> learntTagIds) async {
    try {
      final dynamic dao = _db.problemsDao;
      final List rows = await (dao.getGatedProblems(learntTagIds) as Future);
      return rows.map((r) => ProblemModel.fromDynamic(r)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<ProblemModel>> searchByTitle(String query) async {
    try {
      final dynamic dao = _db.problemsDao;
      final List rows = await (dao.searchByTitle(query) as Future);
      return rows.map((r) => ProblemModel.fromDynamic(r)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<ProblemModel?> getProblemBySlug(String slug) async {
    try {
      final dynamic dao = _db.problemsDao;
      final dynamic row = await (dao.getProblemBySlug(slug) as Future);
      if (row == null) return null;
      return ProblemModel.fromDynamic(row);
    } catch (_) {
      return null;
    }
  }

  Future<List<ProblemModel>> getProblemsByTag(
      int tagId, List<int> learntTagIds) async {
    try {
      final dynamic dao = _db.problemsDao;
      final List rows =
          await (dao.getProblemsByTag(tagId, learntTagIds) as Future);
      return rows.map((r) => ProblemModel.fromDynamic(r)).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Tags ─────────────────────────────────────────────────────────────────

  Future<List<TagModel>> getAllTags() async {
    try {
      final dynamic dao = _db.tagsDao;
      final List rows = await (dao.getAllTags() as Future);
      return rows.map((r) => TagModel.fromDynamic(r)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<TagModel>> getTagsByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    try {
      final dynamic dao = _db.tagsDao;
      final List rows = await (dao.getTagsByIds(ids) as Future);
      return rows.map((r) => TagModel.fromDynamic(r)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<TagModel>> getTagsForProblem(int problemId) async {
    try {
      final dynamic dao = _db.tagsDao;
      final List rows = await (dao.getTagsForProblem(problemId) as Future);
      return rows.map((r) => TagModel.fromDynamic(r)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<TagModel?> getPrimaryTagForProblem(int problemId) async {
    try {
      final dynamic dao = _db.tagsDao;
      final dynamic row =
          await (dao.getPrimaryTagForProblem(problemId) as Future);
      if (row == null) return null;
      return TagModel.fromDynamic(row);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, List<TagModel>>> getTagsByCategory() async {
    try {
      final dynamic dao = _db.tagsDao;
      final Map raw = await (dao.getTagsByCategory() as Future);
      return raw.map((key, value) => MapEntry(
            key as String,
            (value as List).map((r) => TagModel.fromDynamic(r)).toList(),
          ));
    } catch (_) {
      return {};
    }
  }

  Future<List<int>> getTagIdsForProblem(int problemId) async {
    try {
      final dynamic dao = _db.tagsDao;
      final List rows = await (dao.getTagIdsForProblem(problemId) as Future);
      return rows.cast<int>();
    } catch (_) {
      return [];
    }
  }

  // ── Concept Graph ─────────────────────────────────────────────────────────

  /// All prerequisite edges: tagId requires requiresTagId.
  Future<List<Map<String, int>>> getAllEdges() async {
    try {
      final dynamic dao = _db.conceptGraphDao;
      final List rows = await (dao.getAllEdges() as Future);
      return rows.map<Map<String, int>>((r) {
        return {'tagId': r.tagId as int, 'requiresTagId': r.requiresTagId as int};
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Problem count per tag for node sizing.
  Future<Map<int, int>> getProblemCountPerTag() async {
    try {
      final dynamic dao = _db.conceptGraphDao;
      final Map raw = await (dao.getProblemCountPerTag() as Future);
      return raw.map((k, v) => MapEntry(k as int, v as int));
    } catch (_) {
      return {};
    }
  }

  /// Prerequisites for a specific tag.
  Future<List<TagModel>> getPrerequisitesFor(int tagId) async {
    try {
      final dynamic dao = _db.conceptGraphDao;
      final List rows = await (dao.getPrerequisitesFor(tagId) as Future);
      return rows.map((r) => TagModel.fromDynamic(r)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Dependents (what this tag unlocks).
  Future<List<TagModel>> getDependentsOf(int tagId) async {
    try {
      final dynamic dao = _db.conceptGraphDao;
      final List rows = await (dao.getDependentsOf(tagId) as Future);
      return rows.map((r) => TagModel.fromDynamic(r)).toList();
    } catch (_) {
      return [];
    }
  }
}
