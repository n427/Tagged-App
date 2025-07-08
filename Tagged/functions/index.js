/**
 * rotateTags – sets nextTagSwitchDate to the coming Sunday 23:59 PT
 * and rotates current / queued / past tags for every group.
 *
 * Deploy with:  firebase deploy --only functions:rotateTags
 */

const { onSchedule } = require("firebase-functions/v2/scheduler");
const { DateTime }   = require("luxon");
const admin          = require("firebase-admin");
const { Timestamp }  = require("firebase-admin/firestore");

admin.initializeApp();
const db = admin.firestore();

exports.rotateTags = onSchedule(
  { schedule: "every sunday 23:59", timeZone: "America/Los_Angeles" },
  async () => {

    /* ───────── 1. Compute upcoming Sunday 23:59 PT ───────── */
    const nowLA = DateTime.now().setZone("America/Los_Angeles");

    // daysUntilSunday = 0..6
    let upcomingSunday = nowLA
      .plus({ days: (7 - nowLA.weekday) % 7 })
      .set({ hour: 23, minute: 59, second: 0, millisecond: 0 });

    // If already past Sunday 23:59 this week, push one week ahead
    if (upcomingSunday <= nowLA) {
      upcomingSunday = upcomingSunday.plus({ weeks: 1 });
    }

    const ts = Timestamp.fromDate(upcomingSunday.toJSDate());

    /* ───────── 2. Rotate every group in a batch ───────── */
    const snap  = await db.collection("Groups").get();
    const batch = db.batch();
    snap.forEach(doc => {
      const d = doc.data();

      // 0️⃣ Skip if group's nextTagSwitchDate is still in the future
      const nextSwitch = d.nextTagSwitchDate?.toDate?.() || new Date(0);
      if (nextSwitch > new Date()) return;

      // 1️⃣ Rotate tags
      const queue  = Array.isArray(d.queuedTags) ? d.queuedTags : [];
      const newTag = queue.length ? queue[0] : d.currentTag;
      const newQ   = queue.length ? queue.slice(1) : [];

      // 2️⃣ Write updates
      batch.update(doc.ref, {
        currentTag:        newTag,
        queuedTags:        newQ,
        pastTags:          admin.firestore.FieldValue.arrayUnion(d.currentTag ?? ""),
        nextTagSwitchDate: ts   // (ts is upcoming Sunday 23:59 PT)
      });
    });
    await batch.commit();

  }
);