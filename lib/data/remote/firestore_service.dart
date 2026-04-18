import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Profile ──────────────────────────────────────────────────────────────

  DocumentReference _profileRef(String uid) =>
      _db.collection('users').doc(uid).collection('profile').doc('profile');

  Stream<Map<String, dynamic>?> watchProfile(String uid) =>
      _profileRef(uid).snapshots().map((s) => s.data() as Map<String, dynamic>?);

  Future<void> updateProfile(String uid, Map<String, dynamic> data) =>
      _profileRef(uid).update(data);

  // ── Learnt Concepts ──────────────────────────────────────────────────────

  DocumentReference _learntConceptsRef(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('learnt_concepts')
      .doc('learnt_concepts');

  Stream<List<int>> watchLearntConcepts(String uid) =>
      _learntConceptsRef(uid).snapshots().map((s) {
        final data = s.data() as Map<String, dynamic>?;
        return List<int>.from(data?['tagIds'] ?? []);
      });

  Future<void> addLearntConcept(String uid, int tagId) =>
      _learntConceptsRef(uid).update({
        'tagIds': FieldValue.arrayUnion([tagId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> setLearntConcepts(String uid, List<int> tagIds) =>
      _learntConceptsRef(uid).set({
        'tagIds': tagIds,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  // ── Solved Problems ───────────────────────────────────────────────────────

  DocumentReference _solvedRef(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('solved_problems')
      .doc('solved_problems');

  Stream<List<int>> watchSolvedProblems(String uid) =>
      _solvedRef(uid).snapshots().map((s) {
        final data = s.data() as Map<String, dynamic>?;
        return List<int>.from(data?['problemIds'] ?? []);
      });

  Future<void> addSolvedProblem(
      String uid, int problemId, String date) =>
      _solvedRef(uid).update({
        'problemIds': FieldValue.arrayUnion([problemId]),
        'solvedDates.$problemId': date,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  // ── Bookmarks ─────────────────────────────────────────────────────────────

  DocumentReference _bookmarksRef(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('bookmarks')
      .doc('bookmarks');

  Stream<List<int>> watchBookmarks(String uid) =>
      _bookmarksRef(uid).snapshots().map((s) {
        final data = s.data() as Map<String, dynamic>?;
        return List<int>.from(data?['problemIds'] ?? []);
      });

  Future<void> toggleBookmark(
      String uid, int problemId, bool isBookmarked) async {
    if (isBookmarked) {
      await _bookmarksRef(uid).update({
        'problemIds': FieldValue.arrayUnion([problemId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await _bookmarksRef(uid).update({
        'problemIds': FieldValue.arrayRemove([problemId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ── Chat ──────────────────────────────────────────────────────────────────

  CollectionReference _chatsRef(String uid) =>
      _db.collection('users').doc(uid).collection('chats');

  CollectionReference _messagesRef(String uid, String problemId) =>
      _chatsRef(uid).doc(problemId).collection('messages');

  Stream<QuerySnapshot> watchMessages(String uid, String problemId) =>
      _messagesRef(uid, problemId).orderBy('timestamp').snapshots();

  Future<void> sendMessage(
      String uid, String problemId, Map<String, dynamic> message) async {
    await _messagesRef(uid, problemId).add({
      ...message,
      'timestamp': FieldValue.serverTimestamp(),
    });
    await _chatsRef(uid).doc(problemId).set({
      'problemId': int.tryParse(problemId) ?? 0,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'messageCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  Stream<QuerySnapshot> watchAllChats(String uid) =>
      _chatsRef(uid).orderBy('lastMessageAt', descending: true).snapshots();

  // ── SRS ───────────────────────────────────────────────────────────────────

  CollectionReference _srsRef(String uid) =>
      _db.collection('users').doc(uid).collection('srs_queue');

  Stream<QuerySnapshot> watchSrsQueue(String uid) => _srsRef(uid).snapshots();

  Future<void> setSrsEntry(
      String uid, int problemId, Map<String, dynamic> entry) =>
      _srsRef(uid).doc(problemId.toString()).set(entry);

  Future<void> updateSrsEntry(
      String uid, int problemId, Map<String, dynamic> data) =>
      _srsRef(uid).doc(problemId.toString()).update(data);

  // ── Radar Scores ──────────────────────────────────────────────────────────

  DocumentReference _radarRef(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('radar_scores')
      .doc('radar_scores');

  Stream<Map<String, dynamic>?> watchRadarScores(String uid) =>
      _radarRef(uid).snapshots().map((s) => s.data() as Map<String, dynamic>?);

  // ── Notifications ─────────────────────────────────────────────────────────

  CollectionReference _notificationsRef(String uid) =>
      _db.collection('users').doc(uid).collection('notifications');

  Stream<QuerySnapshot> watchNotifications(String uid) =>
      _notificationsRef(uid)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots();

  Future<void> markNotificationRead(String uid, String notifId) =>
      _notificationsRef(uid).doc(notifId).update({'read': true});

  // ── Preferences ───────────────────────────────────────────────────────────

  DocumentReference _prefsRef(String uid) =>
      _db.collection('users').doc(uid).collection('preferences').doc('preferences');

  Stream<Map<String, dynamic>?> watchPreferences(String uid) =>
      _prefsRef(uid).snapshots().map((s) => s.data() as Map<String, dynamic>?);

  Future<void> updatePreferences(String uid, Map<String, dynamic> data) =>
      _prefsRef(uid).set(data, SetOptions(merge: true));

  // ── Daily Problem ─────────────────────────────────────────────────────────

  DocumentReference _dailyProblemRef(String uid) =>
      _db.collection('users').doc(uid).collection('daily_problem').doc('today');

  Stream<Map<String, dynamic>?> watchDailyProblem(String uid) =>
      _dailyProblemRef(uid)
          .snapshots()
          .map((s) => s.data() as Map<String, dynamic>?);

  // ── Wishlist ──────────────────────────────────────────────────────────────

  DocumentReference _wishlistRef(String uid) => _db
      .collection('users')
      .doc(uid)
      .collection('concept_wishlist')
      .doc('concept_wishlist');

  Future<void> toggleWishlist(
      String uid, int tagId, bool add) async {
    await _wishlistRef(uid).set({
      'tagIds': add
          ? FieldValue.arrayUnion([tagId])
          : FieldValue.arrayRemove([tagId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
