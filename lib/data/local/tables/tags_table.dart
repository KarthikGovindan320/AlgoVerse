import 'package:drift/drift.dart';

class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get category => text().nullable()();
  TextColumn get conceptDifficulty => text().nullable()();
  TextColumn get eli5 => text().nullable()();
}

class ProblemTags extends Table {
  IntColumn get problemId => integer().references(
        Tags, #id,
      )();
  IntColumn get tagId => integer()();
  BoolColumn get isPrimary => boolean().withDefault(const Constant(false))();
  BoolColumn get isAlternative =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {problemId, tagId};
}

class ConceptPrerequisites extends Table {
  IntColumn get tagId => integer()();
  IntColumn get requiresTagId => integer()();

  @override
  Set<Column> get primaryKey => {tagId, requiresTagId};
}
