class AppConstants {
  AppConstants._();

  // Asset paths
  static const String dbAssetPath = 'assets/data/leetcode_problems.db';
  static const String conceptAliasesPath = 'assets/data/concept_aliases.json';
  static const String dbFileName = 'leetcode_problems.db';

  // Firestore collections
  static const String usersCollection = 'users';
  static const String jobsCollection = 'jobs';
  static const String recruitersCollection = 'recruiters';
  static const String duelsCollection = 'duels';
  static const String friendshipsCollection = 'friendships';
  static const String learningCardsCollection = 'learning_cards';
  static const String problemsMetaCollection = 'problems_meta';

  // Firestore user sub-documents
  static const String profileDoc = 'profile';
  static const String preferencesDoc = 'preferences';
  static const String careerPreferencesDoc = 'careerPreferences';
  static const String learntConceptsDoc = 'learnt_concepts';
  static const String solvedProblemsDoc = 'solved_problems';
  static const String bookmarksDoc = 'bookmarks';
  static const String conceptWishlistDoc = 'concept_wishlist';
  static const String radarScoresDoc = 'radar_scores';

  // Firestore user sub-collections
  static const String chatsCollection = 'chats';
  static const String messagesCollection = 'messages';
  static const String srsQueueCollection = 'srs_queue';
  static const String notificationsCollection = 'notifications';
  static const String socialInferencesCollection = 'social_inferences';

  // XP values
  static const int xpEasy = 10;
  static const int xpMedium = 25;
  static const int xpHard = 50;

  // SRS defaults
  static const int srsInitialInterval = 3;
  static const double srsInitialEaseFactor = 2.5;

  // LeetCode GraphQL
  static const String leetcodeGraphqlUrl = 'https://leetcode.com/graphql';

  // Gemini
  static const String geminiModel = 'gemini-1.5-flash';
}
