# Cloud Functions Setup (StyleBridge AI)

Cloud Functions code exists in `functions/`, but deployment is optional and currently not required for Spark-plan development.

Use manual Firebase Console notification sends for current testing.

## What is implemented

- `onPurchaseRequestWritten`
  - Trigger: `purchase_requests/{requestId}` write
  - Sends notification when status becomes `accepted`
  - Payload:
    - `type: purchase_request_accepted`
    - `requestId: <doc id>`

- `onOrderWritten`
  - Trigger: `orders/{orderId}` write
  - Sends notification when `status` changes
  - Payload:
    - `type: order_status_updated`
    - `orderId: <doc id>`

Both functions look up `users/{uid}.fcmToken`.

## One-time local setup (optional)

Run from project root:

```powershell
cd C:\Projects\stylebridge_ai
npm install -g firebase-tools
firebase login
firebase use stylebridgeai
```

Install function dependencies:

```powershell
cd C:\Projects\stylebridge_ai\functions
npm install
```

## Deploy functions (requires Blaze)

From project root:

```powershell
cd C:\Projects\stylebridge_ai
firebase deploy --only functions
```

## Deploy Firestore rules (purchase_requests access)

From project root:

```powershell
cd C:\Projects\stylebridge_ai
firebase deploy --only firestore:rules
```

## Verify (when functions are deployed)

1. Make sure app user has a recent `users/{uid}.fcmToken`.
2. Update an order status in Firestore.
3. Confirm device receives `order_status_updated` notification.
4. Approve/set `purchase_requests/{id}.status = accepted`.
5. Confirm device receives `purchase_request_accepted` notification.
