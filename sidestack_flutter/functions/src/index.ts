import * as admin from "firebase-admin";
import { auth } from "firebase-functions/v1";

admin.initializeApp();
const db = admin.firestore();

// ─────────────────────────────────────────────────────────────────────────────
// deleteUserData
//
// Triggered automatically when a Firebase Auth user is deleted.
// Deletes the username index doc and the entire /users/{uid} Firestore subtree.
// ─────────────────────────────────────────────────────────────────────────────

export const deleteUserData = auth.user().onDelete(async (user) => {
  const uid = user.uid;
  console.log(`deleteUserData: cleaning up data for uid=${uid}`);

  try {
    // 1. Delete username index doc
    const usernameSnap = await db
      .collection("usernames")
      .where("uid", "==", uid)
      .get();

    if (!usernameSnap.empty) {
      const batch = db.batch();
      for (const doc of usernameSnap.docs) {
        batch.delete(doc.ref);
      }
      await batch.commit();
      console.log(`deleteUserData: removed ${usernameSnap.size} username doc(s)`);
    }

    // 2. Recursively delete all Firestore data for this user
    await admin.firestore().recursiveDelete(db.collection("users").doc(uid));
    console.log(`deleteUserData: recursively deleted /users/${uid}`);
  } catch (err) {
    console.error(`deleteUserData error for uid=${uid}:`, err);
    // Do not re-throw — failure here must not prevent Auth deletion completing
  }
});
