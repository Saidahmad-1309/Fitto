const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { logger } = require("firebase-functions");
const { onDocumentWritten } = require("firebase-functions/v2/firestore");

initializeApp();

const db = getFirestore();
const messaging = getMessaging();
const REGION = "asia-south1";

exports.onPurchaseRequestWritten = onDocumentWritten(
  {
    document: "purchase_requests/{requestId}",
    region: REGION,
  },
  async (event) => {
    const before = event.data.before.exists ? event.data.before.data() : null;
    const after = event.data.after.exists ? event.data.after.data() : null;

    if (!after) return;

    const beforeStatus = asString(before?.status).toLowerCase();
    const afterStatus = asString(after.status).toLowerCase();
    if (afterStatus !== "accepted" || beforeStatus === "accepted") return;

    const requestId = asString(event.params.requestId);
    const userId = asString(after.userId);
    if (!userId || !requestId) return;

    const title = "Request approved";
    const body = "Your purchase request was accepted";

    await sendToUser({
      userId,
      notification: { title, body },
      data: {
        type: "purchase_request_accepted",
        requestId,
      },
    });
  },
);

exports.onOrderWritten = onDocumentWritten(
  {
    document: "orders/{orderId}",
    region: REGION,
  },
  async (event) => {
    const before = event.data.before.exists ? event.data.before.data() : null;
    const after = event.data.after.exists ? event.data.after.data() : null;
    if (!after) return;

    const beforeStatus = asString(before?.status).toLowerCase();
    const afterStatus = asString(after.status).toLowerCase();
    if (!afterStatus || beforeStatus === afterStatus) return;

    const orderId = asString(event.params.orderId);
    const userId = asString(after.userId);
    if (!orderId || !userId) return;

    await sendToUser({
      userId,
      notification: {
        title: "Order update",
        body: `Your order is now ${afterStatus}`,
      },
      data: {
        type: "order_status_updated",
        orderId,
      },
    });
  },
);

async function sendToUser({ userId, notification, data }) {
  const userRef = db.collection("users").doc(userId);
  const userSnap = await userRef.get();
  if (!userSnap.exists) {
    logger.warn("User doc not found, notification skipped", { userId, data });
    return;
  }

  const userData = userSnap.data() || {};
  const token = asString(userData.fcmToken);
  if (!token) {
    logger.info("User has no fcmToken, notification skipped", { userId, data });
    return;
  }

  try {
    const response = await messaging.send({
      token,
      notification,
      data: stringifyData(data),
      android: { priority: "high" },
    });
    logger.info("Notification sent", { userId, response, data });
  } catch (error) {
    logger.error("Notification send failed", {
      userId,
      data,
      error: error?.message || String(error),
      code: error?.code,
    });
    if (isTokenInvalid(error)) {
      await userRef.set(
        {
          fcmToken: null,
          fcmTokenUpdatedAt: null,
        },
        { merge: true },
      );
      logger.info("Invalid token removed", { userId });
    }
  }
}

function stringifyData(data) {
  const out = {};
  Object.entries(data || {}).forEach(([k, v]) => {
    out[k] = String(v ?? "");
  });
  return out;
}

function asString(value) {
  if (value == null) return "";
  return String(value).trim();
}

function isTokenInvalid(error) {
  const code = asString(error?.code).toLowerCase();
  return (
    code === "messaging/invalid-registration-token" ||
    code === "messaging/registration-token-not-registered"
  );
}
