import * as admin from "firebase-admin";
import { auth } from "firebase-functions/v1";
import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";

admin.initializeApp();
const db = admin.firestore();

// ─────────────────────────────────────────────────────────────────────────────
// RevenueCat webhook secret — stored as a Firebase Secret (never in source code)
// Set it once via CLI:  firebase functions:secrets:set REVENUECAT_WEBHOOK_SECRET
// ─────────────────────────────────────────────────────────────────────────────

const rcSecret = defineSecret("REVENUECAT_WEBHOOK_SECRET");

// ─────────────────────────────────────────────────────────────────────────────
// handleRevenueCatWebhook
//
// Called by RevenueCat whenever a subscription event occurs.
// Sets or clears the `premium` field on the user's Firestore doc.
//
// Events that grant premium:  INITIAL_PURCHASE, RENEWAL, UNCANCELLATION,
//                              SUBSCRIPTION_EXTENDED, TRANSFER (new subscriber)
// Events that revoke premium: EXPIRATION, BILLING_ISSUE (after grace period)
// Events we log but ignore:   CANCELLATION (sub is cancelled but still active
//                              until EXPIRATION — don't revoke yet)
// ─────────────────────────────────────────────────────────────────────────────

const GRANT_EVENTS = new Set([
  "INITIAL_PURCHASE",
  "RENEWAL",
  "UNCANCELLATION",
  "SUBSCRIPTION_EXTENDED",
  "TRANSFER",
]);

const REVOKE_EVENTS = new Set([
  "EXPIRATION",
  "BILLING_ISSUE",
]);

export const handleRevenueCatWebhook = onRequest(
  { secrets: [rcSecret] },
  async (req, res) => {
    // Only accept POST
    if (req.method !== "POST") {
      res.status(405).send("Method Not Allowed");
      return;
    }

    // Verify the shared secret RevenueCat sends in the Authorization header
    const authHeader = req.headers["authorization"] ?? "";
    if (authHeader !== rcSecret.value()) {
      console.warn("handleRevenueCatWebhook: invalid secret");
      res.status(401).send("Unauthorized");
      return;
    }

    const event = req.body?.event;
    if (!event) {
      res.status(400).send("Bad Request: missing event");
      return;
    }

    const eventType: string = event.type ?? "";
    const appUserId: string = event.app_user_id ?? "";

    console.log(`handleRevenueCatWebhook: ${eventType} for uid=${appUserId}`);

    if (!appUserId) {
      // No user to update — acknowledge and move on
      res.status(200).send("OK");
      return;
    }

    const userRef = db.collection("users").doc(appUserId);

    if (GRANT_EVENTS.has(eventType)) {
      await userRef.set({ premium: true }, { merge: true });
      console.log(`handleRevenueCatWebhook: granted premium to ${appUserId}`);
    } else if (REVOKE_EVENTS.has(eventType)) {
      await userRef.set({ premium: false }, { merge: true });
      console.log(`handleRevenueCatWebhook: revoked premium from ${appUserId}`);
    } else {
      console.log(`handleRevenueCatWebhook: no action for event type ${eventType}`);
    }

    res.status(200).send("OK");
  }
);

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
