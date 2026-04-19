import * as admin from "firebase-admin";
import {onCall} from "firebase-functions/v2/https";
import {onDocumentWritten} from "firebase-functions/v2/firestore";
import {onSchedule} from "firebase-functions/v2/scheduler";
import {onRequest} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import {logger} from "firebase-functions";

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

// Secret: set via `firebase functions:secrets:set GEMINI_API_KEY`
const geminiApiKey = defineSecret("GEMINI_API_KEY");

// ─────────────────────────────────────────────────────────────────────────────
// 1. onNewUser — create default Firestore documents for every new account
// ─────────────────────────────────────────────────────────────────────────────

import {auth} from "firebase-functions/v1";

export const onNewUser = auth.user().onCreate(async (user) => {
  const uid = user.uid;
  const now = admin.firestore.FieldValue.serverTimestamp();

  const batch = db.batch();

  // Profile document
  batch.set(db.doc(`users/${uid}/profile/profile`), {
    uid,
    displayName: user.displayName ?? "",
    username: "",
    email: user.email ?? "",
    photoURL: user.photoURL ?? "",
    xp: 0,
    level: 1,
    streak: 0,
    bestStreak: 0,
    lastActiveDate: "",
    solvedCount: 0,
    easyCount: 0,
    mediumCount: 0,
    hardCount: 0,
    onboardingComplete: false,
    onboardingStep: 0,
    linkedAccounts: {},
    fcmToken: "",
    createdAt: now,
    updatedAt: now,
  });

  // Learnt concepts
  batch.set(db.doc(`users/${uid}/learnt_concepts/learnt_concepts`), {
    tagIds: [],
    updatedAt: now,
  });

  // Solved problems
  batch.set(db.doc(`users/${uid}/solved_problems/solved_problems`), {
    problemIds: [],
    solvedDates: {},
    updatedAt: now,
  });

  // Radar scores (6 axes matching the Flutter RadarChart)
  batch.set(db.doc(`users/${uid}/radar_scores/radar_scores`), {
    arrays: 0,
    strings: 0,
    dp: 0,
    graphs: 0,
    trees: 0,
    math: 0,
    updatedAt: now,
  });

  // Bookmarks
  batch.set(db.doc(`users/${uid}/bookmarks/bookmarks`), {
    problemIds: [],
    updatedAt: now,
  });

  // Preferences
  batch.set(db.doc(`users/${uid}/preferences/preferences`), {
    soundEffects: true,
    haptics: true,
    dailyReminder: true,
    reminderTime: "09:00",
    streakAlerts: true,
    updatedAt: now,
  });

  await batch.commit();
  logger.info(`Created default docs for new user: ${uid}`);
});

// ─────────────────────────────────────────────────────────────────────────────
// 2. generateDailyProblem — runs every day at 00:00 UTC
//    Writes to config/daily_problem and sends FCM to daily_problem topic.
// ─────────────────────────────────────────────────────────────────────────────

export const generateDailyProblem = onSchedule(
  {schedule: "0 0 * * *", timeZone: "UTC"},
  async () => {
    // Pull candidate problems from Firestore `problems` collection.
    // The data pipeline populates this via: pipeline/ingest.py → Firestore export step.
    // Falls back to a hardcoded seed list if the collection is empty.
    const today = new Date().toISOString().split("T")[0]; // YYYY-MM-DD

    let slug = "";
    let title = "";
    let difficulty = "medium";

    const snapshot = await db
      .collection("problems")
      .where("isPremium", "==", false)
      .limit(500)
      .get();

    if (!snapshot.empty) {
      const docs = snapshot.docs;
      // Deterministic pick based on date so all users see the same problem
      const index = hashDate(today) % docs.length;
      const chosen = docs[index].data();
      slug = chosen.slug ?? docs[index].id;
      title = chosen.title ?? slug;
      difficulty = chosen.difficulty ?? "medium";
    } else {
      // Fallback seed — replace with real slugs once pipeline runs
      const seeds = [
        {slug: "two-sum", title: "Two Sum", difficulty: "easy"},
        {slug: "longest-substring-without-repeating-characters", title: "Longest Substring Without Repeating Characters", difficulty: "medium"},
        {slug: "median-of-two-sorted-arrays", title: "Median of Two Sorted Arrays", difficulty: "hard"},
      ];
      const pick = seeds[hashDate(today) % seeds.length];
      slug = pick.slug;
      title = pick.title;
      difficulty = pick.difficulty;
    }

    // Write global daily problem doc (Flutter app watches config/daily_problem)
    await db.doc("config/daily_problem").set({
      slug,
      title,
      difficulty,
      date: today,
      generatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Send FCM broadcast to users subscribed to the daily_problem topic
    await messaging.send({
      topic: "daily_problem",
      notification: {
        title: "Today's problem is live!",
        body: `${title} — tap to start.`,
      },
      data: {
        type: "daily_problem",
        deepLink: `/problem/${slug}`,
        date: today,
      },
      android: {priority: "high"},
      apns: {payload: {aps: {sound: "default"}}},
    });

    logger.info(`Daily problem set: ${slug} (${today})`);
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 3. leaderboardFanout — triggers when a user's profile doc is written
//    Keeps leaderboard_global denormalised and up to date.
// ─────────────────────────────────────────────────────────────────────────────

export const leaderboardFanout = onDocumentWritten(
  "users/{uid}/profile/profile",
  async (event) => {
    const uid = event.params.uid;
    const after = event.data?.after?.data();

    if (!after) {
      // Profile deleted — remove from leaderboard
      await db.doc(`leaderboard_global/${uid}`).delete();
      return;
    }

    const entry = {
      uid,
      displayName: after.displayName ?? "",
      username: after.username ?? "",
      photoURL: after.photoURL ?? "",
      xp: after.xp ?? 0,
      level: after.level ?? 1,
      solvedCount: after.solvedCount ?? 0,
      streak: after.streak ?? 0,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.doc(`leaderboard_global/${uid}`).set(entry, {merge: true});
    logger.info(`Leaderboard updated for ${uid}: xp=${entry.xp}`);
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 4. duelAiVerdict — triggers when a duel document is written
//    When both participants have submitted, calls Gemini to compare solutions
//    and writes a structured verdict back to the duel doc.
// ─────────────────────────────────────────────────────────────────────────────

export const duelAiVerdict = onDocumentWritten(
  {document: "duels/{duelId}", secrets: [geminiApiKey]},
  async (event) => {
    const duelId = event.params.duelId;
    const after = event.data?.after?.data();

    if (!after) return;

    // Only run when both participants have submitted and verdict is pending
    const {participant1, participant2, status, verdict} = after;
    if (status !== "both_submitted" || verdict) return;

    const p1 = participant1 as {uid: string; solution?: string; language?: string} | undefined;
    const p2 = participant2 as {uid: string; solution?: string; language?: string} | undefined;

    if (!p1?.solution || !p2?.solution) return;

    logger.info(`Generating AI verdict for duel ${duelId}`);

    const problemTitle: string = after.problemTitle ?? "the problem";
    const prompt = `
You are a code reviewer judging a coding duel. Two participants solved "${problemTitle}".

Participant 1 (${p1.language ?? "unknown"} solution):
\`\`\`
${p1.solution}
\`\`\`

Participant 2 (${p2.language ?? "unknown"} solution):
\`\`\`
${p2.solution}
\`\`\`

Compare the two solutions. Respond in JSON with this exact schema:
{
  "winner": "participant1" | "participant2" | "tie",
  "explanation": "<2-3 sentence summary>",
  "p1Feedback": "<one strength and one improvement for participant 1>",
  "p2Feedback": "<one strength and one improvement for participant 2>",
  "timeComplexity": {"p1": "<e.g. O(n)>", "p2": "<e.g. O(n log n)>"},
  "spaceComplexity": {"p1": "<e.g. O(1)>", "p2": "<e.g. O(n)>"}
}
Respond with valid JSON only — no markdown fences.
`;

    try {
      const apiKey = geminiApiKey.value();
      const response = await fetch(
        `https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=${apiKey}`,
        {
          method: "POST",
          headers: {"Content-Type": "application/json"},
          body: JSON.stringify({
            contents: [{parts: [{text: prompt}]}],
            generationConfig: {temperature: 0.2, maxOutputTokens: 1024},
          }),
        }
      );

      if (!response.ok) {
        throw new Error(`Gemini API error: ${response.status}`);
      }

      const json = (await response.json()) as {
        candidates?: Array<{content?: {parts?: Array<{text?: string}>}}>;
      };
      const raw = json.candidates?.[0]?.content?.parts?.[0]?.text ?? "{}";
      const verdictData = JSON.parse(raw.trim());

      await db.doc(`duels/${duelId}`).update({
        verdict: verdictData,
        status: "verdict_ready",
        verdictGeneratedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Notify both participants
      const tokens = await Promise.all([
        getToken(p1.uid),
        getToken(p2.uid),
      ]);
      const validTokens = tokens.filter(Boolean) as string[];
      if (validTokens.length > 0) {
        await messaging.sendEachForMulticast({
          tokens: validTokens,
          notification: {
            title: "Duel verdict is in!",
            body: `${verdictData.winner === "tie" ? "It's a tie!" : `${verdictData.winner} wins!`} Tap to see the breakdown.`,
          },
          data: {
            type: "duel",
            deepLink: `/duel/${duelId}`,
          },
        });
      }

      logger.info(`Verdict written for duel ${duelId}: winner=${verdictData.winner}`);
    } catch (err) {
      logger.error(`Failed to generate verdict for duel ${duelId}:`, err);
      await db.doc(`duels/${duelId}`).update({
        status: "verdict_error",
        verdictError: String(err),
      });
    }
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// 5. streakCheck — runs every day at 01:00 UTC
//    Resets streaks for users who did not solve anything yesterday.
//    Sends a warning FCM to users whose streak is at risk tonight.
// ─────────────────────────────────────────────────────────────────────────────

export const streakCheck = onSchedule(
  {schedule: "0 1 * * *", timeZone: "UTC"},
  async () => {
    const yesterday = offsetDate(-1); // YYYY-MM-DD
    const today = offsetDate(0);

    // Batch reads: find users whose lastActiveDate is not today
    // We process in pages to avoid memory issues on large user bases.
    let lastDoc: admin.firestore.QueryDocumentSnapshot | undefined;
    let processed = 0;
    let reset = 0;
    let warned = 0;

    // eslint-disable-next-line no-constant-condition
    while (true) {
      let query = db
        .collectionGroup("profile")
        .where("streak", ">", 0)
        .orderBy("streak")
        .limit(200);

      if (lastDoc) query = query.startAfter(lastDoc);

      const snap = await query.get();
      if (snap.empty) break;

      const batch = db.batch();
      const tokenPromises: Promise<void>[] = [];

      for (const doc of snap.docs) {
        const data = doc.data();
        const lastActive: string = data.lastActiveDate ?? "";
        const streak: number = data.streak ?? 0;
        const fcmToken: string = data.fcmToken ?? "";
        processed++;

        if (lastActive < yesterday) {
          // Streak broken — reset
          batch.update(doc.ref, {streak: 0, updatedAt: admin.firestore.FieldValue.serverTimestamp()});
          reset++;
        } else if (lastActive === yesterday && fcmToken) {
          // Active yesterday but not yet today — send streak warning
          tokenPromises.push(
            messaging.send({
              token: fcmToken,
              notification: {
                title: "Don't lose your streak!",
                body: `You're on a ${streak}-day streak. Solve one problem today to keep it alive.`,
              },
              data: {
                type: "streak",
                deepLink: "/home",
                date: today,
              },
              android: {priority: "high"},
              apns: {payload: {aps: {sound: "default"}}},
            }).then(() => undefined).catch(() => undefined)
          );
          warned++;
        }
      }

      await batch.commit();
      await Promise.all(tokenPromises);

      lastDoc = snap.docs[snap.docs.length - 1];
      if (snap.size < 200) break;
    }

    logger.info(`Streak check done. Processed=${processed}, reset=${reset}, warned=${warned}`);
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// Utility: callable health-check (useful during development)
// ─────────────────────────────────────────────────────────────────────────────

export const ping = onRequest((_req, res) => {
  res.json({status: "ok", project: "algoverse-492311"});
});

// ─────────────────────────────────────────────────────────────────────────────
// Utility: callable to manually trigger daily problem (admin only)
// ─────────────────────────────────────────────────────────────────────────────

export const triggerDailyProblem = onCall({enforceAppCheck: false}, async (request) => {
  // Verify the caller is an admin (has admin custom claim)
  if (!request.auth?.token?.admin) {
    throw new Error("Permission denied: admin only");
  }
  // Re-use the same logic — just invoke the scheduler function indirectly
  // by writing a trigger doc that the real function responds to.
  // For development, call generateDailyProblem directly via the emulator.
  return {message: "Use firebase emulators:start and call the scheduler trigger."};
});

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

/** Deterministic date hash for consistent daily problem selection. */
function hashDate(dateStr: string): number {
  let hash = 0;
  for (let i = 0; i < dateStr.length; i++) {
    hash = (hash * 31 + dateStr.charCodeAt(i)) >>> 0;
  }
  return hash;
}

/** Returns YYYY-MM-DD offset by `days` from today (UTC). */
function offsetDate(days: number): string {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().split("T")[0];
}

/** Retrieves the stored FCM token for a user from their profile doc. */
async function getToken(uid: string): Promise<string | null> {
  try {
    const doc = await db.doc(`users/${uid}/profile/profile`).get();
    return (doc.data()?.fcmToken as string) || null;
  } catch {
    return null;
  }
}
