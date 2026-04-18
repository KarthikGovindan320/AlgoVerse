/// A plain-Dart model mirroring the `tags` SQLite table.
class TagModel {
  final int id;
  final String name;
  final String? category;
  final String? eli5;
  final String? conceptDifficulty;

  const TagModel({
    required this.id,
    required this.name,
    this.category,
    this.eli5,
    this.conceptDifficulty,
  });

  factory TagModel.fromDynamic(dynamic row) {
    return TagModel(
      id: row.id as int,
      name: row.name as String,
      category: row.category as String?,
      eli5: row.eli5 as String?,
      conceptDifficulty: row.conceptDifficulty as String?,
    );
  }
}
