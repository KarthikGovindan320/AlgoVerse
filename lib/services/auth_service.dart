import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<User?> get authStateStream => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // Create Firestore user document on first sign-in
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        await _createUserDocument(userCredential.user!);
      }

      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _createUserDocument(User user) async {
    final userRef =
        _firestore.collection('users').doc(user.uid).collection('profile');
    await userRef.doc('profile').set({
      'uid': user.uid,
      'displayName': user.displayName ?? '',
      'handle': _generateHandle(user.displayName ?? user.uid),
      'email': user.email ?? '',
      'avatarUrl': user.photoURL ?? '',
      'accentColor': '#00F5A0',
      'leetcodeUsername': null,
      'leetcodeSolvedCount': 0,
      'level': 'Beginner',
      'levelNumber': 1,
      'xp': 0,
      'xpToNextLevel': 500,
      'currentStreak': 0,
      'bestStreak': 0,
      'lastActiveDate': FieldValue.serverTimestamp(),
      'openToWork': false,
      'onboardingComplete': false,
      'onboardingStep': 1,
      'linkedAccounts': {
        'linkedin': {'connected': false},
        'github': {'connected': false},
        'instagram': {'connected': false},
        'twitter': {'connected': false},
        'codeforces': {'connected': false},
      },
      'aboutMe': '',
      'totalProblems': 0,
      'easyCount': 0,
      'mediumCount': 0,
      'hardCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'lastSyncedAt': null,
    });

    // Initialize other user documents
    final userDoc = _firestore.collection('users').doc(user.uid);
    await userDoc.collection('learnt_concepts').doc('learnt_concepts').set({
      'tagIds': [],
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await userDoc.collection('solved_problems').doc('solved_problems').set({
      'problemIds': [],
      'updatedAt': FieldValue.serverTimestamp(),
      'solvedDates': {},
    });
    await userDoc.collection('bookmarks').doc('bookmarks').set({
      'problemIds': [],
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  String _generateHandle(String displayName) {
    return displayName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .substring(0, displayName.length.clamp(0, 15));
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Delete all Firestore data for the user
    final userRef = _firestore.collection('users').doc(user.uid);
    await _deleteCollection(userRef.collection('profile'));
    await _deleteCollection(userRef.collection('preferences'));
    await _deleteCollection(userRef.collection('learnt_concepts'));
    await _deleteCollection(userRef.collection('solved_problems'));
    await _deleteCollection(userRef.collection('bookmarks'));
    await _deleteCollection(userRef.collection('radar_scores'));
    await _deleteCollection(userRef.collection('notifications'));
    await _deleteCollection(userRef.collection('srs_queue'));
    await userRef.delete();

    await user.delete();
    await _googleSignIn.signOut();
  }

  Future<void> _deleteCollection(CollectionReference collection) async {
    final docs = await collection.get();
    for (final doc in docs.docs) {
      await doc.reference.delete();
    }
  }
}
