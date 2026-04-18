import 'package:drift/drift.dart';

class Problems extends Table {
  IntColumn get id => integer()();
  TextColumn get slug => text().unique()();
  TextColumn get title => text()();
  TextColumn get difficulty => text()();
  TextColumn get statement => text().nullable()();
  TextColumn get exampleTestcases => text().nullable()();
  TextColumn get hints => text().nullable()(); // JSON array
  RealColumn get acceptanceRate => real().nullable()();
  BoolColumn get isPremium => boolean().withDefault(const Constant(false))();
  BoolColumn get taggingSkipped => boolean().withDefault(const Constant(false))();
  TextColumn get insightSummary => text().nullable()();
  TextColumn get eli5 => text().nullable()();
  TextColumn get lcTags => text().nullable()(); // JSON array
  IntColumn get likes => integer().nullable()();
  TextColumn get similarQuestions => text().nullable()(); // JSON array

  @override
  Set<Column> get primaryKey => {id};
}
