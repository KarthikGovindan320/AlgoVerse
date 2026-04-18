# AlgoVerse — Manual Setup Steps

These are the three manual steps required before the app is fully functional on a device.
Steps 1 and 2 (build_runner + Kaggle pipeline) have already been completed by the agent.

---

## Step 3 — Add Sound Assets

The `SoundService` plays `.mp3` files from `assets/sounds/`. The folder exists in `pubspec.yaml` but the actual audio files need to be sourced and dropped in.

### File names required (exact, case-sensitive)

| File | Trigger |
|---|---|
| `assets/sounds/chip_select.mp3` | Tapping a concept chip in onboarding/discover |
| `assets/sounds/bookmark.mp3` | Bookmarking a problem |
| `assets/sounds/message_send.mp3` | Sending a chat message to AI |
| `assets/sounds/ai_typing.mp3` | AI response starts streaming |
| `assets/sounds/problem_solved.mp3` | Marking a problem as solved |
| `assets/sounds/concept_learnt.mp3` | Marking a concept as learnt |
| `assets/sounds/level_up.mp3` | XP level-up event |
| `assets/sounds/streak_milestone.mp3` | 7 / 14 / 30-day streak milestone |
| `assets/sounds/daily_open.mp3` | Opening the daily problem card |
| `assets/sounds/duel_challenge.mp3` | Receiving a duel challenge |
| `assets/sounds/duel_complete.mp3` | Completing a duel (positive result) |

### Where to get free sounds

- **Freesound.org** — search "UI click", "chime", "success" etc. (CC0 / Attribution licences)
- **Pixabay** — royalty-free SFX, no attribution required for apps
- **Kenney.nl/assets/category/audio** — complete UI SFX packs, free for commercial use

### Steps

1. Download or create the 11 `.mp3` files listed above.
2. Create the folder if it doesn't exist: `assets/sounds/`
3. Copy all files into `assets/sounds/`.
4. Verify `pubspec.yaml` already declares the folder:
   ```yaml
   assets:
     - assets/sounds/
   ```
5. Run `flutter pub get` — no code changes needed; `SoundService` already loads them by name.

> **Note:** If a sound file is missing, `SoundService` silently swallows the error — the app won't crash, you'll just get silence for that trigger.

---

## Step 4 — Deploy Firebase Cloud Functions

The Flutter app is wired to consume data that Cloud Functions produce. Without them, certain features degrade gracefully (they just show empty states) but won't function end-to-end.

### Prerequisites

```bash
npm install -g firebase-tools
firebase login
cd functions   # or wherever you create the functions folder
npm install
```

### Functions to implement

| Function name | Trigger | What it does |
|---|---|---|
| `generateDailyProblem` | Pub/Sub schedule: every day 00:00 UTC | Picks a problem from the DB based on a weighted algorithm, writes to `daily_problem` Firestore collection, sends FCM topic push to `daily_problem` topic |
| `updateRadarScores` | Firestore: `onWrite` of `users/{uid}/solved_problems` | Recalculates the user's radar scores per concept category, writes to `users/{uid}/profile.radarScores` |
| `leaderboardFanout` | Firestore: `onWrite` of `users/{uid}/profile` | Updates denormalised leaderboard entries in `leaderboard_global` and `leaderboard_friends` |
| `duelAiVerdict` | Firestore: `onWrite` of `duels/{duelId}` (both attempts submitted) | Calls Gemini API to compare two solutions, writes verdict back to the duel doc |
| `onNewUser` | Firebase Auth: `onCreate` | Creates default Firestore profile doc for new users |
| `streakCheck` | Pub/Sub schedule: every day 01:00 UTC | Checks users who haven't solved a problem today and resets their streak, sends streak warning FCM |

### Scaffold a function (TypeScript example)

```bash
firebase init functions   # choose TypeScript
```

`functions/src/index.ts` minimal example for `generateDailyProblem`:

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();
const db = admin.firestore();

export const generateDailyProblem = functions.pubsub
  .schedule('0 0 * * *')
  .timeZone('UTC')
  .onRun(async () => {
    // 1. Query a random non-premium problem from your problem bank
    // 2. Write to Firestore
    await db.collection('daily_problem').doc('today').set({
      problemId: /* your logic */,
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    // 3. Send FCM to topic
    await admin.messaging().send({
      topic: 'daily_problem',
      notification: { title: "Today's problem is live!", body: 'Tap to start.' },
      data: { type: 'daily_problem' },
    });
  });
```

### Deploy

```bash
firebase deploy --only functions
```

### Subscribe users to FCM topics

In `NotificationService.requestPermission()` in `lib/services/notification_service.dart`, add:

```dart
await FirebaseMessaging.instance.subscribeToTopic('daily_problem');
await FirebaseMessaging.instance.subscribeToTopic('streak_alerts');
```

---

## Step 5 — Wire NotificationService.navigatorKey

Foreground notification taps use GoRouter to navigate to the correct screen. For this to work, `NotificationService` needs the app's `NavigatorState` key.

### Where to make the change

Open `lib/app.dart`. It currently looks like this (abridged):

```dart
class AlgoVerseApp extends ConsumerWidget {
  const AlgoVerseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      routerConfig: router,
      ...
    );
  }
}
```

### What to add

GoRouter exposes its internal navigator key via `GoRouter.routerDelegate.navigatorKey`. After building the router, pass it to `NotificationService`:

```dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final router = ref.watch(routerProvider);

  // Wire the navigator key so foreground notification taps can navigate
  NotificationService.navigatorKey =
      router.routerDelegate.navigatorKey as GlobalKey<NavigatorState>;

  return MaterialApp.router(
    routerConfig: router,
    ...
  );
}
```

Make sure `notification_service.dart` is imported at the top of `app.dart`:

```dart
import 'services/notification_service.dart';
```

### Why this is needed

When a notification arrives while the app is in the foreground, `NotificationService._handleNotificationTap()` calls:

```dart
NotificationService.navigatorKey?.currentState
    ?.pushNamed(message.data['deepLink'] ?? '/');
```

Without the key set, the navigator is null and taps silently do nothing.

### Calling requestPermission (anti-fatigue rule)

Per `NOTIFICATIONS.md`, permission should NOT be requested on first launch. Call it on the user's second active day:

```dart
// In your home screen or a usage-tracking provider:
final prefs = await SharedPreferences.getInstance();
final launchCount = prefs.getInt('launch_count') ?? 0;
if (launchCount == 2) {
  await NotificationService().requestPermission();
}
await prefs.setInt('launch_count', launchCount + 1);
```

---

## Quick reference — Kaggle dataset location

The downloaded CSV (already on your machine) is at:

```
C:\Users\vkart\.cache\kagglehub\datasets\ashutoshpapnoi\latest-complete-leetcode-problems-dataset-2025\versions\1\Leetcode.csv
```

To run the pipeline that turns it into a SQLite database:

```bash
cd pipeline
pip install -r requirements.txt
python ingest.py
python tagger.py
python graph_builder.py
python validate.py
# Output: algoverse.db — copy to assets/data/leetcode_problems.db
```
