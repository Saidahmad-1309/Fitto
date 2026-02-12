# FCM Manual Testing Guide (Spark-safe)

This guide validates push notification routing without Cloud Functions deployment.

## Prerequisites

- App runs on device/emulator and user is logged in.
- `users/{uid}.fcmToken` exists.
- At least one token doc exists at `users/{uid}/fcm_tokens/{tokenDocId}`.
- Android notifications are enabled for the app.

## 1) Verify token storage

1. Open Firestore `users/{uid}`.
2. Confirm top-level fields:
   - `fcmToken`
   - `primaryFcmToken`
3. Open subcollection `fcm_tokens`.
4. Confirm token docs include:
   - `token`
   - `platform`
   - `isActive`
   - `createdAt`, `updatedAt` (and optionally `lastSeenAt`)

## 2) Send a manual notification from Firebase Console

1. Firebase Console -> Cloud Messaging -> Compose notification.
2. Enter title/body.
3. Target Android app.
4. In Additional options -> Custom data, add:
   - `type = purchase_request_accepted`
   - `requestId = <real purchase_requests doc id>`
5. Send.

Expected:
- Notification appears.
- Tap opens app.
- App switches to Orders tab.
- My Requests opens.
- Request Details opens if `requestId` exists.

## 3) Multi-device behavior test

1. Login on device A with same user.
2. Login on device B with same user.
3. Confirm two docs exist under `users/{uid}/fcm_tokens`.
4. Send manual notification to device A token and verify routing.
5. Send manual notification to device B token and verify routing.

## 4) Payload parser test matrix

Repeat manual sends using these key variants:

- `type + requestId`
- `eventType + request_id`
- `event_type + purchase_request_id`
- `type=order_status_updated + orderId`
- `type=order_status_updated + order_id`

Expected:
- All supported aliases route correctly.
- Unknown type performs no navigation.
- Missing IDs open the list tab/screen with fallback snackbar.

## 5) Common failure checks

- Request details shows "Request not found":
  - Usually wrong `requestId`.
  - Use exact document ID from Firestore middle column.
- Notification arrives but no deep-link:
  - Verify custom data keys are set.
  - Verify app process was rebuilt after code changes.
- No notification at all:
  - Check token belongs to currently logged-in user/device.
  - Confirm notification permission is enabled.
