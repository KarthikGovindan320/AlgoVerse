import 'dart:convert';

/// A plain-Dart model mirroring the `problems` SQLite table.
/// This avoids any dependency on Drift-generated code in the UI layer.
class ProblemModel {
  final int id;
  final String slug;
  final String title;
  final String difficulty; // 'Easy' | 'Medium' | 'Hard'
  final String? statement; // markdown (converted from HTML by ingest.py)
  final String? exampleTestcases;
  final List<String> hints;
  final double? acceptanceRate;
  final bool isPremium;
  final bool taggingSkipped;
  final String? insightSummary;
  final String? eli5;
  final List<String> lcTags;
  final int? likes;
  final List<String> similarQuestions;

  const ProblemModel({
    required this.id,
    required this.slug,
    required this.title,
    required this.difficulty,
    this.statement,
    this.exampleTestcases,
    this.hints = const [],
    this.acceptanceRate,
    this.isPremium = false,
    this.taggingSkipped = false,
    this.insightSummary,
    this.eli5,
    this.lcTags = const [],
    this.likes,
    this.similarQuestions = const [],
  });

  /// Construct from a Drift-generated row via dynamic access.
  factory ProblemModel.fromDynamic(dynamic row) {
    return ProblemModel(
      id: row.id as int,
      slug: row.slug as String,
      title: row.title as String,
      difficulty: row.difficulty as String,
      statement: row.statement as String?,
      exampleTestcases: row.exampleTestcases as String?,
      hints: _parseJsonList(row.hints as String?),
      acceptanceRate: row.acceptanceRate as double?,
      isPremium: row.isPremium as bool? ?? false,
      taggingSkipped: row.taggingSkipped as bool? ?? false,
      insightSummary: row.insightSummary as String?,
      eli5: row.eli5 as String?,
      lcTags: _parseJsonList(row.lcTags as String?),
      likes: row.likes as int?,
      similarQuestions: _parseJsonList(row.similarQuestions as String?),
    );
  }

  static List<String> _parseJsonList(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.cast<String>();
    } catch (_) {}
    return [];
  }

  String get leetcodeUrl => 'https://leetcode.com/problems/$slug/';
}
