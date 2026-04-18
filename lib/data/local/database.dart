import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'tables/problems_table.dart';
import 'tables/tags_table.dart';
import 'daos/problems_dao.dart';
import 'daos/tags_dao.dart';
import 'daos/concept_graph_dao.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [Problems, Tags, ProblemTags, ConceptPrerequisites],
  daos: [ProblemsDao, TagsDao, ConceptGraphDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'leetcode_problems.db'));

    // Copy the asset DB on first launch or if it doesn't exist
    if (!file.existsSync()) {
      final blob = await rootBundle.load('assets/data/leetcode_problems.db');
      final buffer = blob.buffer;
      await file.writeAsBytes(
        buffer.asUint8List(blob.offsetInBytes, blob.lengthInBytes),
      );
    }

    return NativeDatabase.createInBackground(file);
  });
}
