import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../local/database.dart';
import '../remote/firestore_service.dart';
import '../repositories/local_repository.dart';
import '../../services/auth_service.dart';

// ── Auth ──────────────────────────────────────────────────────────────────────

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final firestoreServiceProvider =
    Provider<FirestoreService>((ref) => FirestoreService());

/// Stream of Firebase Auth user — the root authentication state.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateStream;
});

// ── Local Database ────────────────────────────────────────────────────────────

final localDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() async {
    final dynamic d = db;
    try { await (d.close() as Future); } catch (_) {}
  });
  return db;
});

/// Type-safe wrapper around the Drift DB using dynamic dispatch.
/// Allows the UI to access problem/tag data without depending on
/// build_runner-generated Drift accessors at compile time.
final localRepositoryProvider = Provider<LocalRepository>((ref) {
  final db = ref.watch(localDatabaseProvider);
  return LocalRepository(db);
});

// ── User Profile ──────────────────────────────────────────────────────────────

final userProfileProvider =
    StreamProvider<Map<String, dynamic>?>((ref) async* {
  final authState = await ref.watch(authStateProvider.future);
  if (authState == null) {
    yield null;
    return;
  }
  yield* ref.watch(firestoreServiceProvider).watchProfile(authState.uid);
});

// ── Learnt Concepts ───────────────────────────────────────────────────────────

final learntConceptsProvider = StreamProvider<List<int>>((ref) async* {
  final authState = await ref.watch(authStateProvider.future);
  if (authState == null) {
    yield [];
    return;
  }
  yield* ref.watch(firestoreServiceProvider).watchLearntConcepts(authState.uid);
});

// ── Solved Problems ───────────────────────────────────────────────────────────

final solvedProblemsProvider = StreamProvider<List<int>>((ref) async* {
  final authState = await ref.watch(authStateProvider.future);
  if (authState == null) {
    yield [];
    return;
  }
  yield* ref
      .watch(firestoreServiceProvider)
      .watchSolvedProblems(authState.uid);
});

// ── Bookmarks ─────────────────────────────────────────────────────────────────

final bookmarksProvider = StreamProvider<List<int>>((ref) async* {
  final authState = await ref.watch(authStateProvider.future);
  if (authState == null) {
    yield [];
    return;
  }
  yield* ref.watch(firestoreServiceProvider).watchBookmarks(authState.uid);
});

// ── Radar Scores ──────────────────────────────────────────────────────────────

final radarScoresProvider =
    StreamProvider<Map<String, dynamic>?>((ref) async* {
  final authState = await ref.watch(authStateProvider.future);
  if (authState == null) {
    yield null;
    return;
  }
  yield* ref.watch(firestoreServiceProvider).watchRadarScores(authState.uid);
});

// ── Daily Problem ─────────────────────────────────────────────────────────────

final dailyProblemProvider =
    StreamProvider<Map<String, dynamic>?>((ref) async* {
  final authState = await ref.watch(authStateProvider.future);
  if (authState == null) {
    yield null;
    return;
  }
  yield* ref.watch(firestoreServiceProvider).watchDailyProblem(authState.uid);
});
