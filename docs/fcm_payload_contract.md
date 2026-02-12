# FCM Payload Contract (StyleBridge AI)

Current mode is manual Firebase Console sends only. Do not depend on Cloud Functions auto-trigger while the project remains on Spark.

## Supported event types

### 1) `purchase_request_accepted`

```json
{
  "type": "purchase_request_accepted",
  "requestId": "fLNWqVRFSkDIx4SsJFvw"
}
```

### 2) `order_status_updated`

```json
{
  "type": "order_status_updated",
  "orderId": "KEnwE2EOci9nUZq06ez9"
}
```

## Accepted key aliases

The app normalizes these keys:

- Type: `type`, `eventType`, `event_type`
- Request ID: `requestId`, `request_id`, `purchaseRequestId`, `purchase_request_id`
- Order ID: `orderId`, `order_id`

Use canonical keys (`type`, `requestId`, `orderId`) whenever possible.

## Routing behavior

- `purchase_request_accepted`
  - Switches to Orders tab.
  - Opens My Requests screen.
  - If `requestId` is valid, opens Request Details.
  - If `requestId` is missing/invalid, My Requests list still opens with a fallback message.

- `order_status_updated`
  - Switches to Orders tab.
  - If `orderId` is valid, opens Order Details.
  - If missing/invalid, stays on Orders tab with a fallback message.

- Unknown `type`
  - No navigation.
  - Debug log only (in debug mode).

## ID requirements

- `requestId` must be the Firestore document ID in `purchase_requests/{requestId}`.
- `orderId` must be the Firestore document ID in `orders/{orderId}`.
- Do not send title/userId/shopId instead of document IDs.

## Token notes

- Backward compatibility field still exists: `users/{uid}.fcmToken`.
- Multi-device tokens are stored at: `users/{uid}/fcm_tokens/{tokenDocId}`.
