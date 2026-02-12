enum NotificationDeepLinkType {
  purchaseRequestAccepted,
  orderStatusUpdated,
  unknown,
}

class NotificationDeepLink {
  const NotificationDeepLink({
    required this.type,
    required this.requestId,
    required this.orderId,
    required this.raw,
  });

  final NotificationDeepLinkType type;
  final String? requestId;
  final String? orderId;
  final Map<String, String> raw;

  bool get hasRequestId => (requestId ?? '').trim().isNotEmpty;
  bool get hasOrderId => (orderId ?? '').trim().isNotEmpty;

  factory NotificationDeepLink.fromRaw(Map<String, dynamic> payload) {
    final normalized = <String, String>{};
    payload.forEach((key, value) {
      final k = key.toString().trim();
      final v = value?.toString().trim() ?? '';
      normalized[k] = v;
      normalized[k.toLowerCase()] = v;
    });

    final typeRaw = _readFirst(
      normalized,
      const ['type', 'event_type', 'eventType'],
    ).toLowerCase();

    final type = switch (typeRaw) {
      'purchase_request_accepted' =>
        NotificationDeepLinkType.purchaseRequestAccepted,
      'order_status_updated' => NotificationDeepLinkType.orderStatusUpdated,
      _ => NotificationDeepLinkType.unknown,
    };

    final requestId = _readFirst(
      normalized,
      const [
        'requestId',
        'request_id',
        'purchaseRequestId',
        'purchase_request_id',
      ],
    );
    final orderId = _readFirst(
      normalized,
      const ['orderId', 'order_id'],
    );

    return NotificationDeepLink(
      type: type,
      requestId: requestId.isEmpty ? null : requestId,
      orderId: orderId.isEmpty ? null : orderId,
      raw: normalized,
    );
  }

  static String _readFirst(Map<String, String> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key] ?? data[key.toLowerCase()];
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }
}
