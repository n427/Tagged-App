const { onDocumentCreated, onDocumentUpdated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { DateTime }   = require("luxon");
const admin          = require("firebase-admin");

admin.initializeApp();
const db        = admin.firestore();
const messaging = admin.messaging();

exports.notifyOnNewComment = onDocumentCreated(
  "Posts/{postID}/comments/{commentID}",
  async (event) => {
    try {
      const comment = event.data?.data();
      if (!comment) return;

      const { postID, commentID } = event.params;
      const postSnap = await db.doc(`Posts/${postID}`).get();
      if (!postSnap.exists) return;

      const post = postSnap.data();

      const ownerID = post.authorID || post.ownerID || post.userUID || post.userId || post.creatorID;
      if (!ownerID) {
        console.error('❌ [notifyOnNewComment] No ownerID found');
        return;
      }

      const userSnap = await db.doc(`Users/${ownerID}`).get();
      if (!userSnap.exists) return;

      const token = userSnap.data()?.fcmToken;
      if (!token) {
        console.error("❌ [notifyOnNewComment] No token for", ownerID);
        return;
      }

      const msg = {
        token,
          notification: {
            title: `💬 ${comment.username}`,
            body: `Commented: “${comment.text || ''}”`
          },
        data: { type: 'new_comment', postID, commentID }
      };

      const response = await messaging.send(msg);
    } catch (err) {
      console.error("❌ [notifyOnNewComment] Error:", err);
    }
  }
);

exports.notifyOnNewLike = onDocumentCreated(
  "Posts/{postID}/likes/{likerID}",
  async (event) => {
    try {
      const { postID, likerID } = event.params;
      const likeData = event.data?.data();
      if (!likeData) return;

      const postSnap = await db.doc(`Posts/${postID}`).get();
      if (!postSnap.exists) return;

      const post = postSnap.data();

      const ownerID = post.authorID || post.ownerID || post.userUID || post.userId || post.creatorID;
      if (!ownerID || likerID === ownerID) {
        console.error('❌ [notifyOnNewLike] Invalid ownerID');
        return;
      }

      const userSnap = await db.doc(`Users/${ownerID}`).get();
      if (!userSnap.exists) return;

      const token = userSnap.data()?.fcmToken;
      if (!token) {
        console.error("❌ [notifyOnNewLike] No token for", ownerID);
        return;
      }

      const msg = {
        token,
          notification: {
            title: `❤️ “${post.title || 'Your post'}”`,
            body: `Just got a like!`
          },
        data: { type: 'new_like', postID }
      };

      const response = await messaging.send(msg);
    } catch (err) {
      console.error("❌ [notifyOnNewLike] Error:", err);
    }
  }
);

exports.notifyOnTagRotation = onDocumentUpdated(
  "Groups/{groupID}",
  async (event) => {
    try {
        const groupID = event.params.groupID;
          const before = event.data?.before.data();
          const after = event.data?.after.data();

          if (!before || !after || before.currentTag === after.currentTag) return;

          const groupSnap = await db.doc(`Groups/${groupID}`).get();
          const memberIDs = groupSnap.data()?.members || [];

      for (const uid of memberIDs) {
        const snap = await db.doc(`Users/${uid}`).get();
        const token = snap.data()?.fcmToken;
        if (!token) continue;

        const msg = {
          token,
          notification: {
            title: `🔁 ${after.title || 'Your group'}`,
            body: `This week's Tag: ${after.currentTag || ''}`
          },
          data: { type: 'tag_rotated', groupID }
        };

        try {
          await messaging.send(msg);
        } catch (err) {
          console.error(`❌ [notifyOnTagRotation] Error sending to ${uid}:`, err);
        }
      }
    } catch (err) {
      console.error("❌ [notifyOnTagRotation] Error:", err);
    }
  }
);

exports.rotateTags = onSchedule(
  { schedule: "every sunday 23:59", timeZone: "America/Los_Angeles" },
  async () => {
    const nowLA = DateTime.now().setZone("America/Los_Angeles");
    let nextSwitch = nowLA.plus({ days: (7 - nowLA.weekday) % 7 })
      .set({ hour: 23, minute: 59, second: 0, millisecond: 0 });
    if (nextSwitch <= nowLA) nextSwitch = nextSwitch.plus({ weeks: 1 });
    const ts = admin.firestore.Timestamp.fromDate(nextSwitch.toJSDate());

    const snap = await db.collection("Groups").get();
    const batch = db.batch();
    snap.forEach(doc => {
      const d = doc.data();
      const switchDate = d.nextTagSwitchDate?.toDate?.() || new Date(0);
      if (switchDate > new Date()) return;
      const queue = Array.isArray(d.queuedTags) ? d.queuedTags : [];
      const newTag = queue.length ? queue[0] : d.currentTag;
      const newQ   = queue.slice(1);
        batch.update(doc.ref, {
          currentTag: newTag,
          queuedTags: newQ,
          pastTags: admin.firestore.FieldValue.arrayUnion(d.currentTag || ""),
          nextTagSwitchDate: ts,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

    });
    await batch.commit();
  }
);

const vision = require("@google-cloud/vision");
const client = new vision.ImageAnnotatorClient();


exports.moderatePost = onDocumentCreated(
  "Posts/{postId}",
  async (event) => {
    const post = event.data?.data() || {};
    const { postTitle = "", postText = "", imageURL = "", imageReferenceID = "" } = post;

    let unsafeImage = false;
    try {
      let sourceForVision = null;

      if (imageReferenceID) {
        const file = admin.storage().bucket().file(`Post_Images/${imageReferenceID}`);
        const [meta] = await file.getMetadata();
        sourceForVision = `gs://${meta.bucket}/${meta.name}`;
      } else if (imageURL) {
        sourceForVision = imageURL;
      }

      if (sourceForVision) {
        const [result] = await client.safeSearchDetection(sourceForVision);
        const a = result.safeSearchAnnotation || {};
        const bad = new Set(["LIKELY", "VERY_LIKELY"]);
        if (bad.has(a.adult) || bad.has(a.violence) || bad.has(a.racy)) {
          unsafeImage = true;
        }
      }
    } catch (err) {
      console.error("Vision check failed:", err);
    }

    const rejected = unsafeImage;

    await event.data?.ref.update({
      moderationStatus: rejected ? "rejected" : "approved",
      moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
      moderationReason: rejected ? "Content violation" : admin.firestore.FieldValue.delete(),
    });
  }
);
