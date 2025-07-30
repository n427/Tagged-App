const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule }                  = require("firebase-functions/v2/scheduler");
const { DateTime }                    = require("luxon");
const admin                           = require("firebase-admin");
const { Timestamp }                   = require("firebase-admin/firestore");

admin.initializeApp();
const db        = admin.firestore();
const messaging = admin.messaging();

/**
 * 1️⃣ Notify on new comment
 */
exports.notifyOnNewComment = onDocumentCreated(
  "Posts/{postID}/Comments/{commentID}",
  async (event) => {
    const comment    = event.data.data();           // { authorID, authorName, content, ... }
    const { postID } = event.params;

    // 1. Lookup post to find its owner
    const postSnap = await db.doc(`Posts/${postID}`).get();
    if (!postSnap.exists) return;
    const post = postSnap.data();
    const ownerID = post.authorID;

    // 2. Gather owner’s device tokens
    const tokensSnap = await db.collection(`Users/${ownerID}/tokens`).get();
    const tokens = tokensSnap.docs.map(d => d.id);
    if (tokens.length === 0) return;

    // 3. Send notification
    await messaging.sendMulticast({
      tokens,
      notification: {
        title: `${comment.authorName} commented`,
        body: comment.content.slice(0, 100),    // snippet
      },
      data: {
        type: "new_comment",
        postID,
        commentID: event.params.commentID,
      },
    });
  }
);

/**
 * 2️⃣ Notify on new like
 */
exports.notifyOnNewLike = onDocumentCreated(
  "Posts/{postID}/Likes/{userID}",
  async (event) => {
    const likerID    = event.params.userID;
    const { postID } = event.params;

    // 1. Lookup post owner
    const postSnap = await db.doc(`Posts/${postID}`).get();
    if (!postSnap.exists) return;
    const post = postSnap.data();
    const ownerID = post.authorID;

    // 2. Skip if liker is the owner
    if (ownerID === likerID) return;

    // 3. Fetch liker’s display name
    const userSnap = await db.doc(`Users/${likerID}`).get();
    const liker    = userSnap.exists ? userSnap.data().displayName || "Someone" : "Someone";

    // 4. Gather owner’s tokens
    const tokensSnap = await db.collection(`Users/${ownerID}/tokens`).get();
    const tokens = tokensSnap.docs.map(d => d.id);
    if (tokens.length === 0) return;

    // 5. Send notification
    await messaging.sendMulticast({
      tokens,
      notification: {
        title: `${liker} liked your post`,
        body: post.title?.slice(0, 50) || "Tap to view",
      },
      data: {
        type: "new_like",
        postID,
      },
    });
  }
);

/**
 * 3️⃣ Notify on tag rotation
 */
exports.notifyOnTagRotation = onDocumentUpdated(
  "Groups/{groupID}",
  async (event) => {
    const before = event.data.before.data();
    const after  = event.data.after.data();

    // Only proceed if currentTag actually changed
    if (before.currentTag === after.currentTag) return;

    const groupID = event.params.groupID;

    // 1. Fetch all group members
    const membersSnap = await db.collection(`Groups/${groupID}/members`).get();
    const memberIDs = membersSnap.docs.map(d => d.id);

    // 2. Gather all member tokens
    const tokens = [];
    for (const uid of memberIDs) {
      const tokenSnap = await db.collection(`Users/${uid}/tokens`).get();
      tokenSnap.docs.forEach(d => tokens.push(d.id));
    }
    if (tokens.length === 0) return;

    // 3. Send notification
    await messaging.sendMulticast({
      tokens,
      notification: {
        title: "New Weekly Tag!",
        body: `This week’s prompt: "${after.currentTag}"`,
      },
      data: {
        type: "tag_rotated",
        groupID,
      },
    });
  }
);

/**
 * Your existing rotateTags scheduler stays below unchanged…
 * rotateTags – sets nextTagSwitchDate to the coming Sunday 23:59 PT
 * and rotates current / queued / past tags for every group.
 */
exports.rotateTags = onSchedule(
  { schedule: "every sunday 23:59", timeZone: "America/Los_Angeles" },
  async () => {
    const nowLA = DateTime.now().setZone("America/Los_Angeles");
    let upcomingSunday = nowLA
      .plus({ days: (7 - nowLA.weekday) % 7 })
      .set({ hour: 23, minute: 59, second: 0, millisecond: 0 });
    if (upcomingSunday <= nowLA) {
      upcomingSunday = upcomingSunday.plus({ weeks: 1 });
    }
    const ts = Timestamp.fromDate(upcomingSunday.toJSDate());

    const snap  = await db.collection("Groups").get();
    const batch = db.batch();
    snap.forEach(doc => {
      const d = doc.data();
      const nextSwitch = d.nextTagSwitchDate?.toDate?.() || new Date(0);
      if (nextSwitch > new Date()) return;

      const queue  = Array.isArray(d.queuedTags) ? d.queuedTags : [];
      const newTag = queue.length ? queue[0] : d.currentTag;
      const newQ   = queue.length ? queue.slice(1) : [];

      batch.update(doc.ref, {
        currentTag:        newTag,
        queuedTags:        newQ,
        pastTags:          admin.firestore.FieldValue.arrayUnion(d.currentTag ?? ""),
        nextTagSwitchDate: ts
      });
    });
    await batch.commit();
  }
);