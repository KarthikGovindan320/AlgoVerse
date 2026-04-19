# AlgoVerse — Remaining Manual Setup Steps

The agent has completed:
- build_runner (Drift code generation)
- Step 4: Cloud Functions code written + compiled
- Step 5: NotificationService.navigatorKey wired, FCM topics subscribed, launch-count permission flow

The only things left for you to do manually are below.

---

## Step 3 — Add Sound Assets

The `SoundService` plays `.mp3` files from `assets/sounds/`. Drop in real audio files —
the app silently skips any that are missing, so it won't crash.

### File names required (exact)

| File | Trigger |
|---|---|
| `assets/sounds/chip_select.mp3` | Tapping a concept chip |
| `assets/sounds/bookmark.mp3` | Bookmarking a problem |
| `assets/sounds/message_send.mp3` | Sending a chat message |
| `assets/sounds/ai_typing.mp3` | AI starts responding |
| `assets/sounds/problem_solved.mp3` | Marking a problem solved |
| `assets/sounds/concept_learnt.mp3` | Marking a concept learnt |
| `assets/sounds/level_up.mp3` | XP level-up |
| `assets/sounds/streak_milestone.mp3` | 7/14/30-day streak milestone |
| `assets/sounds/daily_open.mp3` | Opening daily problem card |
| `assets/sounds/duel_challenge.mp3` | Receiving a duel challenge |
| `assets/sounds/duel_complete.mp3` | Completing a duel |

### Free sources
- **Kenney.nl/assets/category/audio** — UI SFX packs, free for commercial use (recommended)
- **Freesound.org** — CC0 / Attribution, search "UI click", "chime", "success"
- **Pixabay** — royalty-free SFX, no attribution required

---

## Step 4 — Deploy Firebase Cloud Functions

All function code is written and compiled (`functions/src/index.ts`). You only need to
install the Firebase CLI and deploy.

### One-time CLI setup (if not already done)

```bash
npm install -g firebase-tools
firebase login        # opens browser — sign in with your Google account
```

### Set the Gemini API key as a Firebase secret

The `duelAiVerdict` function uses your Gemini API key. Store it as a secret so it's
never in source code:

```bash
firebase functions:secrets:set GEMINI_API_KEY
# Paste your key when prompted
```

Your Gemini API key is the same one stored in `.env` under `GEMINI_API_KEY`.

### Deploy

```bash
cd "C:\Users\vkart\OneDrive\Documents\Play area\AlgoVerse\AlgoVerse"
firebase deploy --only functions,firestore
```

This deploys all 5 functions plus Firestore security rules and indexes.

### What each function does

| Function | Trigger | Purpose |
|---|---|---|
| `onNewUser` | Auth: new account | Creates all default Firestore docs (profile, radar scores, bookmarks, etc.) |
| `generateDailyProblem` | Scheduled 00:00 UTC | Picks daily problem, writes `config/daily_problem`, sends FCM |
| `leaderboardFanout` | Profile doc write | Keeps `leaderboard_global` denormalised in real time |
| `duelAiVerdict` | Duel doc write | Calls Gemini to compare solutions, writes verdict, notifies players |
| `streakCheck` | Scheduled 01:00 UTC | Resets broken streaks, sends at-risk FCM warnings |

### Populate the Firestore `problems` collection (for daily problem picker)

The `generateDailyProblem` function picks from a Firestore `problems` collection.
After running the Python pipeline, export the SQLite data to Firestore:

```bash
# After pipeline/ingest.py has run and created algoverse.db:
cd pipeline
python export_to_firestore.py   # (see note below — create this script)
```

Alternatively, the function has a hardcoded fallback seed list of 3 problems while
the collection is empty — so daily problems will still show up without this step.

---

## Step 4b — Run the Data Pipeline

The Kaggle CSV is already downloaded at:
```
C:\Users\vkart\.cache\kagglehub\datasets\ashutoshpapnoi\latest-complete-leetcode-problems-dataset-2025\versions\1\Leetcode.csv
```

```bash
cd "C:\Users\vkart\OneDrive\Documents\Play area\AlgoVerse\AlgoVerse\pipeline"
pip install -r requirements.txt
python ingest.py
python tagger.py
python graph_builder.py
python validate.py
```

Then copy the output database into assets:
```bash
copy algoverse.db "..\assets\data\leetcode_problems.db"
```

---

## What's already done (no action needed)

| Item | Status |
|---|---|
| `build_runner` — Drift code generated | Done |
| `NotificationService.navigatorKey` wired in `app.dart` | Done |
| FCM topic subscriptions on permission grant | Done |
| Day-2 anti-fatigue permission request flow | Done |
| Launch count tracking in `main.dart` | Done |
| Global daily problem at `config/daily_problem` | Done |
| Cloud Functions code + TypeScript compilation | Done |
| `firebase.json`, `.firebaserc` | Done |
| `firestore.rules`, `firestore.indexes.json` | Done |
