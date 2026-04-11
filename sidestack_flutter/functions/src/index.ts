import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineString } from "firebase-functions/params";
import * as admin from "firebase-admin";
import axios from "axios";

admin.initializeApp();
const db = admin.firestore();

// ─────────────────────────────────────────────────────────────────────────────
// TrueLayer configuration
//
// Set these in Firebase environment config:
//   firebase functions:config:set \
//     truelayer.client_id="YOUR_CLIENT_ID" \
//     truelayer.client_secret="YOUR_CLIENT_SECRET" \
//     truelayer.redirect_uri="YOUR_REDIRECT_URI" \
//     truelayer.env="sandbox"
//
// truelayer.env options: "sandbox" | "live"
//
// Get your keys at https://console.truelayer.com
// Redirect URI must be registered in your TrueLayer console.
// For mobile apps use a deep link e.g. "sidestack://bank-callback"
// ─────────────────────────────────────────────────────────────────────────────

const tlClientId     = defineString("TRUELAYER_CLIENT_ID",     { default: "" });
const tlClientSecret = defineString("TRUELAYER_CLIENT_SECRET", { default: "" });
const tlRedirectUri  = defineString("TRUELAYER_REDIRECT_URI",  { default: "sidestack://bank-callback" });
const tlEnv          = defineString("TRUELAYER_ENV",           { default: "sandbox" });

const isSandbox = () => tlEnv.value() !== "live";

const AUTH_BASE = () =>
  isSandbox() ? "https://auth.truelayer-sandbox.com" : "https://auth.truelayer.com";

const API_BASE = () =>
  isSandbox() ? "https://api.truelayer-sandbox.com" : "https://api.truelayer.com";

const CLIENT_ID     = () => tlClientId.value();
const CLIENT_SECRET = () => tlClientSecret.value();
const REDIRECT_URI  = () => tlRedirectUri.value();

// Scopes needed: accounts + transactions
const SCOPES = "accounts transactions offline_access";

// ─────────────────────────────────────────────────────────────────────────────
// createAuthLink
//
// Returns a TrueLayer OAuth URL. The Flutter app opens this URL in a browser
// or WebView. After the user selects their bank and authenticates, TrueLayer
// redirects to REDIRECT_URI with a `code` query parameter.
// ─────────────────────────────────────────────────────────────────────────────

function requireAppCheck(request: any) {
  if (!request.app) {
    throw new HttpsError("unauthenticated", "App Check token missing or invalid.");
  }
}

export const createAuthLink = onCall({ enforceAppCheck: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  requireAppCheck(request);

  const userId = request.auth.uid;
  // `state` ties the callback back to this user securely
  const state = Buffer.from(JSON.stringify({ uid: userId, ts: Date.now() })).toString("base64url");

  // Store state temporarily so we can validate it on callback
  await db.collection("users").doc(userId).collection("bank_auth_state").doc(state).set({
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  const params = new URLSearchParams({
    response_type: "code",
    client_id: CLIENT_ID(),
    scope: SCOPES,
    redirect_uri: REDIRECT_URI(),
    providers: "uk-ob-all uk-oauth-all de-ob-all au-ob-all eu-ob-all",
    state,
  });

  const authUrl = `${AUTH_BASE()}/?${params.toString()}`;
  return { auth_url: authUrl };
});

// ─────────────────────────────────────────────────────────────────────────────
// exchangeCode
//
// Called after TrueLayer redirects back to the app with a `code`.
// Exchanges the code for access_token + refresh_token, stores them
// server-side in Firestore (never sent to the client).
// ─────────────────────────────────────────────────────────────────────────────

export const exchangeCode = onCall({ enforceAppCheck: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  requireAppCheck(request);

  const { code, state } = request.data;

  if (typeof code !== "string" || code.trim().length === 0 || code.length > 512) {
    throw new HttpsError("invalid-argument", "Invalid code.");
  }
  if (typeof state !== "string" || state.trim().length === 0 || state.length > 512) {
    throw new HttpsError("invalid-argument", "Invalid state.");
  }

  const userId = request.auth.uid;

  // Validate state belongs to this user
  const stateRef = db.collection("users").doc(userId).collection("bank_auth_state").doc(state);
  const stateDoc = await stateRef.get();
  if (!stateDoc.exists) {
    throw new HttpsError("permission-denied", "Invalid or expired auth state.");
  }
  await stateRef.delete(); // one-time use

  try {
    // Exchange code for tokens
    const tokenRes = await axios.post(
      `${AUTH_BASE()}/connect/token`,
      new URLSearchParams({
        grant_type: "authorization_code",
        client_id: CLIENT_ID(),
        client_secret: CLIENT_SECRET(),
        redirect_uri: REDIRECT_URI(),
        code,
      }).toString(),
      { headers: { "Content-Type": "application/x-www-form-urlencoded" } }
    );

    const { access_token, refresh_token, expires_in } = tokenRes.data;

    // Fetch account + provider info to get institution name
    let institutionName = "Bank";
    try {
      const meRes = await axios.get(`${API_BASE()}/data/v1/me`, {
        headers: { Authorization: `Bearer ${access_token}` },
      });
      institutionName = meRes.data?.results?.[0]?.provider?.display_name ?? "Bank";
    } catch (_) {}

    const connectionId = admin.firestore().collection("_").doc().id; // random ID

    await db
      .collection("users")
      .doc(userId)
      .collection("bank_connections")
      .doc(connectionId)
      .set({
        access_token,
        refresh_token,
        expires_at: Date.now() + (expires_in ?? 3600) * 1000,
        institution_name: institutionName,
        connected_at: admin.firestore.FieldValue.serverTimestamp(),
        last_synced: null,
      });

    await db.collection("users").doc(userId).set(
      { bank_connected: true, bank_institution: institutionName },
      { merge: true }
    );

    return { success: true, institution_name: institutionName };
  } catch (err: any) {
    console.error("exchangeCode error:", err?.response?.data ?? err.message);
    throw new HttpsError("internal", "Could not connect bank account.");
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// refreshAccessToken (internal helper)
// ─────────────────────────────────────────────────────────────────────────────

async function refreshToken(connectionRef: FirebaseFirestore.DocumentReference): Promise<string> {
  const doc = await connectionRef.get();
  const { access_token, refresh_token, expires_at } = doc.data()!;

  // Return existing token if still valid (with 60s buffer)
  if (Date.now() < expires_at - 60_000) return access_token;

  const res = await axios.post(
    `${AUTH_BASE()}/connect/token`,
    new URLSearchParams({
      grant_type: "refresh_token",
      client_id: CLIENT_ID(),
      client_secret: CLIENT_SECRET(),
      refresh_token,
    }).toString(),
    { headers: { "Content-Type": "application/x-www-form-urlencoded" } }
  );

  const { access_token: newToken, expires_in } = res.data;
  await connectionRef.update({
    access_token: newToken,
    expires_at: Date.now() + (expires_in ?? 3600) * 1000,
  });

  return newToken;
}

// ─────────────────────────────────────────────────────────────────────────────
// fetchBankTransactions
//
// Fetches the last [days_back] days of transactions across all connected banks.
// Deduplicates against already-imported IDs.
// ─────────────────────────────────────────────────────────────────────────────

export const fetchBankTransactions = onCall({ enforceAppCheck: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  requireAppCheck(request);

  const userId = request.auth.uid;
  const daysBack: number = request.data?.days_back ?? 90;
  if (!Number.isInteger(daysBack) || daysBack < 1 || daysBack > 365) {
    throw new HttpsError("invalid-argument", "days_back must be between 1 and 365.");
  }

  const connectionsSnap = await db
    .collection("users")
    .doc(userId)
    .collection("bank_connections")
    .get();

  if (connectionsSnap.empty) {
    return { transactions: [], count: 0 };
  }

  // Load already-imported IDs
  const importedSnap = await db
    .collection("users")
    .doc(userId)
    .collection("imported_bank_tx_ids")
    .get();
  const importedIds = new Set(importedSnap.docs.map((d) => d.id));

  const fromDate = new Date();
  fromDate.setDate(fromDate.getDate() - daysBack);
  const fromStr = fromDate.toISOString().split("T")[0];
  const toStr = new Date().toISOString().split("T")[0];

  const allTransactions: any[] = [];

  for (const connDoc of connectionsSnap.docs) {
    const { institution_name } = connDoc.data();
    let token: string;

    try {
      token = await refreshToken(connDoc.ref);
    } catch (err) {
      console.error(`Token refresh failed for ${connDoc.id}:`, err);
      continue;
    }

    try {
      // Get all accounts first
      const accountsRes = await axios.get(`${API_BASE()}/data/v1/accounts`, {
        headers: { Authorization: `Bearer ${token}` },
      });

      const accounts: any[] = accountsRes.data?.results ?? [];

      for (const account of accounts) {
        try {
          const txRes = await axios.get(
            `${API_BASE()}/data/v1/accounts/${account.account_id}/transactions`,
            {
              headers: { Authorization: `Bearer ${token}` },
              params: { from: fromStr, to: toStr },
            }
          );

          const txs: any[] = txRes.data?.results ?? [];

          for (const tx of txs) {
            if (importedIds.has(tx.transaction_id)) continue;
            if (tx.running_balance != null && tx.amount === 0) continue; // skip zero-amount

            allTransactions.push({
              transaction_id: tx.transaction_id,
              date: tx.timestamp?.split("T")[0] ?? tx.normalised_provider_transaction_id,
              amount: Math.abs(tx.amount),
              is_income: tx.transaction_type === "CREDIT" || tx.amount > 0,
              name: tx.description ?? tx.merchant_name ?? "Transaction",
              category: _mapCategory(tx.transaction_classification?.[0] ?? ""),
              institution: institution_name,
              account_id: account.account_id,
            });
          }
        } catch (err: any) {
          console.error(`Tx fetch failed for account ${account.account_id}:`, err?.response?.data ?? err.message);
        }
      }

      await connDoc.ref.update({ last_synced: admin.firestore.FieldValue.serverTimestamp() });
    } catch (err: any) {
      console.error(`Connection ${connDoc.id} failed:`, err?.response?.data ?? err.message);
    }
  }

  allTransactions.sort((a, b) => b.date.localeCompare(a.date));
  return { transactions: allTransactions, count: allTransactions.length };
});

// ─── Category mapper ──────────────────────────────────────────────────────────

function _mapCategory(truelayerCategory: string): string {
  const map: Record<string, string> = {
    "ATM": "Other",
    "BILL_PAYMENT": "Rent & Utilities",
    "CASH": "Other",
    "CHEQUE": "Other",
    "CORRECTION": "Other",
    "CREDIT": "Revenue",
    "DIRECT_DEBIT": "Subscriptions",
    "DIVIDEND": "Revenue",
    "FEE_CHARGE": "Fees",
    "INTEREST": "Revenue",
    "OTHER": "Other",
    "PURCHASE": "Supplies",
    "STANDING_ORDER": "Subscriptions",
    "TRANSFER": "Other",
    "DEBIT": "Other",
    "ENTERTAINMENT": "Subscriptions",
    "EATING_OUT": "Meals",
    "EXPENSES": "Supplies",
    "TRANSPORT": "Travel",
    "ACCOMMODATION": "Travel",
    "SHOPPING": "Supplies",
    "INSURANCE": "Fees",
    "INCOME": "Revenue",
    "SAVINGS": "Other",
    "TAX": "Taxes",
    "WAGES": "Revenue",
    "FREELANCE": "Revenue",
  };
  return map[truelayerCategory.toUpperCase()] ?? "Other";
}

// ─────────────────────────────────────────────────────────────────────────────
// markTransactionsImported
// ─────────────────────────────────────────────────────────────────────────────

export const markTransactionsImported = onCall({ enforceAppCheck: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  requireAppCheck(request);

  const userId = request.auth.uid;
  const { transaction_ids } = request.data;
  if (!Array.isArray(transaction_ids) || transaction_ids.length === 0) return { success: true };
  if (transaction_ids.length > 500) {
    throw new HttpsError("invalid-argument", "Maximum 500 transaction IDs per request.");
  }

  const batch = db.batch();
  const col = db.collection("users").doc(userId).collection("imported_bank_tx_ids");
  for (const id of transaction_ids) {
    if (typeof id !== "string" || id.length === 0 || id.length > 256) {
      throw new HttpsError("invalid-argument", "Invalid transaction ID format.");
    }
    batch.set(col.doc(id), { imported_at: admin.firestore.FieldValue.serverTimestamp() });
  }
  await batch.commit();
  return { success: true };
});

// ─────────────────────────────────────────────────────────────────────────────
// disconnectBank
//
// Revokes the TrueLayer access token and deletes the connection from Firestore.
// ─────────────────────────────────────────────────────────────────────────────

export const disconnectBank = onCall({ enforceAppCheck: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  requireAppCheck(request);

  const userId = request.auth.uid;
  const { connection_id } = request.data as { connection_id?: string };

  if (typeof connection_id !== "string" || connection_id.trim().length === 0 || connection_id.length > 256) {
    throw new HttpsError("invalid-argument", "Invalid connection_id.");
  }

  try {
    const connRef = db
      .collection("users")
      .doc(userId)
      .collection("bank_connections")
      .doc(connection_id);

    const connDoc = await connRef.get();
    if (connDoc.exists) {
      const { access_token } = connDoc.data()!;
      // Revoke token at TrueLayer
      await axios
        .post(
          `${AUTH_BASE()}/connect/token/revoke`,
          new URLSearchParams({ token: access_token }).toString(),
          {
            auth: { username: CLIENT_ID(), password: CLIENT_SECRET() },
            headers: { "Content-Type": "application/x-www-form-urlencoded" },
          }
        )
        .catch(() => {}); // Don't fail hard if revoke fails
      await connRef.delete();
    }

    const remaining = await db
      .collection("users")
      .doc(userId)
      .collection("bank_connections")
      .get();

    if (remaining.empty) {
      await db
        .collection("users")
        .doc(userId)
        .set({ bank_connected: false, bank_institution: null }, { merge: true });
    }

    return { success: true };
  } catch (err: any) {
    console.error("disconnectBank error:", err);
    throw new HttpsError("internal", "Could not disconnect bank.");
  }
});
