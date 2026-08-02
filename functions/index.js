/**
 * Scheduled reminder functions — the server half of the app's reminders
 * system (see lib/core/services/notification_service.dart for the client
 * half that keeps each device's FCM token saved on its user doc).
 *
 * These only cover the features actually built in the Flutter app today:
 * mock-test/dictionary due-reviews, the student's own timetable, and a
 * weekly attempts summary. They are NOT deployed automatically — see
 * README.md "Deploying these functions" for the one-time setup (Blaze
 * billing plan required; Cloud Functions don't run on Firebase's free
 * Spark plan).
 *
 * All schedules assume Indian Standard Time (UTC+5:30), since every exam
 * this app supports (CTET, State TETs) is India-only — there's no
 * per-student timezone stored to do otherwise.
 */

const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

const IST_OFFSET_MINUTES = 5 * 60 + 30;

/** Current time shifted into IST, for computing "today"/day-of-week/minutes-of-day. */
function nowInIst() {
  const now = new Date();
  return new Date(now.getTime() + IST_OFFSET_MINUTES * 60 * 1000);
}

/** JS getUTCDay() is 0=Sunday..6=Saturday; TimetableBlock.dayOfWeek is 1=Monday..7=Sunday. */
function istDayOfWeek(istDate) {
  const jsDay = istDate.getUTCDay();
  return jsDay === 0 ? 7 : jsDay;
}

function istMinutesSinceMidnight(istDate) {
  return istDate.getUTCHours() * 60 + istDate.getUTCMinutes();
}

async function sendToUser(uid, title, body) {
  const userDoc = await db.collection("users").doc(uid).get();
  const tokens = userDoc.get("fcmTokens");
  if (!tokens || !tokens.length) return;
  try {
    await messaging.sendEachForMulticast({
      tokens,
      notification: { title, body },
    });
  } catch (err) {
    console.error(`Failed to notify ${uid}:`, err);
  }
}

/**
 * Daily, 8 AM IST — "N items due today" across mock-test questions and
 * dictionary words combined. Requires composite indexes on both
 * `questionProgress` and `dictionaryProgress` (collection group, field
 * `dueDate`) — Firestore will log a direct link to create these the first
 * time this runs, if they don't already exist.
 */
exports.dueReviewsReminderFn = onSchedule(
  { schedule: "0 8 * * *", timeZone: "Asia/Kolkata" },
  async () => {
    const now = admin.firestore.Timestamp.now();
    const usersSnap = await db.collection("users").get();

    for (const userDoc of usersSnap.docs) {
      const uid = userDoc.id;
      const [questionsSnap, wordsSnap] = await Promise.all([
        db
          .collection("users")
          .doc(uid)
          .collection("questionProgress")
          .where("dueDate", "<=", now)
          .get(),
        db
          .collection("users")
          .doc(uid)
          .collection("dictionaryProgress")
          .where("dueDate", "<=", now)
          .get(),
      ]);
      const dueCount = questionsSnap.size + wordsSnap.size;
      if (dueCount > 0) {
        await sendToUser(
          uid,
          "Revision due today",
          `${dueCount} item${dueCount === 1 ? "" : "s"} waiting for you — mock test questions and dictionary words combined.`
        );
      }
    }
  }
);

/**
 * Every 15 minutes — pings students whose next timetable block starts in
 * the next 15 minutes. Requires a composite index on the `timetable`
 * collection group (`dayOfWeek` ASC, `startMinutes` ASC).
 */
exports.timetableReminderFn = onSchedule(
  { schedule: "*/15 * * * *", timeZone: "Asia/Kolkata" },
  async () => {
    const ist = nowInIst();
    const day = istDayOfWeek(ist);
    const minutesNow = istMinutesSinceMidnight(ist);
    const windowEnd = minutesNow + 15;

    const blocksSnap = await db
      .collectionGroup("timetable")
      .where("dayOfWeek", "==", day)
      .where("startMinutes", ">=", minutesNow)
      .where("startMinutes", "<", windowEnd)
      .get();

    for (const blockDoc of blocksSnap.docs) {
      // A /users/{uid}/timetable/{blockId} doc's parent-of-parent is the user doc.
      const uid = blockDoc.ref.parent.parent.id;
      const subject = blockDoc.get("subject") || "your study block";
      await sendToUser(uid, "Time to study", `${subject} starts soon.`);
    }
  }
);

/**
 * Weekly, Sunday 7 PM IST — a simple score summary of the past 7 days'
 * mock test attempts.
 */
exports.weeklySummaryFn = onSchedule(
  { schedule: "0 19 * * 0", timeZone: "Asia/Kolkata" },
  async () => {
    const sevenDaysAgo = admin.firestore.Timestamp.fromMillis(
      Date.now() - 7 * 24 * 60 * 60 * 1000
    );
    const usersSnap = await db.collection("users").get();

    for (const userDoc of usersSnap.docs) {
      const uid = userDoc.id;
      const attemptsSnap = await db
        .collection("users")
        .doc(uid)
        .collection("attempts")
        .where("submittedAt", ">=", sevenDaysAgo)
        .get();

      if (attemptsSnap.empty) continue;

      let correct = 0;
      let total = 0;
      for (const doc of attemptsSnap.docs) {
        correct += doc.get("correctCount") || 0;
        total += doc.get("totalQuestions") || 0;
      }
      const accuracy = total === 0 ? 0 : Math.round((correct / total) * 100);
      await sendToUser(
        uid,
        "Your week in review",
        `${attemptsSnap.size} mock test${attemptsSnap.size === 1 ? "" : "s"} this week — ${accuracy}% accuracy.`
      );
    }
  }
);
