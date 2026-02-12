import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitto/core/navigation/app_routes.dart';
import 'package:fitto/core/navigation/root_navigator_key.dart';
import 'package:fitto/core/navigation/root_route_observer.dart';
import 'package:fitto/features/auth/presentation/controllers/auth_providers.dart';
import 'package:fitto/features/orders/presentation/screens/order_detail_screen.dart';
import 'package:fitto/features/purchase_requests/presentation/controllers/purchase_requests_providers.dart';
import 'package:fitto/features/purchase_requests/presentation/screens/my_requests_screen.dart';
import 'package:fitto/main_shell.dart';
import 'package:fitto/services/notification_deep_link.dart';

const AndroidNotificationChannel _notificationChannel =
    AndroidNotificationChannel(
  'fitto_high_importance',
  'Fitto Notifications',
  description: 'Order and purchase request updates',
  importance: Importance.high,
);

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService(
    ref: ref,
    navigatorKey: rootNavigatorKey,
    messaging: FirebaseMessaging.instance,
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firestoreProvider),
    localNotifications: FlutterLocalNotificationsPlugin(),
  );

  ref.listen<bool>(appReadyProvider, (_, isReady) {
    if (isReady) {
      unawaited(service.tryHandlePendingDeepLink());
    }
  });

  ref.listen<AsyncValue<User?>>(authStateProvider, (_, next) {
    if (next.valueOrNull != null) {
      unawaited(service.tryHandlePendingDeepLink());
    }
  });

  ref.onDispose(service.dispose);
  return service;
});

class NotificationService {
  NotificationService({
    required Ref ref,
    required GlobalKey<NavigatorState> navigatorKey,
    required FirebaseMessaging messaging,
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required FlutterLocalNotificationsPlugin localNotifications,
  })  : _ref = ref,
        _navigatorKey = navigatorKey,
        _messaging = messaging,
        _auth = auth,
        _firestore = firestore,
        _localNotifications = localNotifications;

  final Ref _ref;
  final GlobalKey<NavigatorState> _navigatorKey;
  final FirebaseMessaging _messaging;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FlutterLocalNotificationsPlugin _localNotifications;

  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedSub;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<User?>? _authSub;

  NotificationDeepLink? _pendingDeepLink;
  String _lastKnownToken = '';
  bool _isInitialized = false;
  bool _isHandlingPending = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    await _requestPermissions();
    await _configureLocalNotifications();
    await _syncTokenForCurrentUser();
    await _handleLocalNotificationLaunch();

    _onMessageSub = FirebaseMessaging.onMessage.listen((message) {
      unawaited(_showForegroundNotification(message));
    });

    _onMessageOpenedSub =
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
      unawaited(handleDeepLinkData(message.data));
    });

    _tokenRefreshSub = _messaging.onTokenRefresh.listen((token) {
      unawaited(_handleTokenRefresh(token));
    });

    _authSub = _auth.authStateChanges().listen((user) {
      if (user != null) {
        unawaited(_syncTokenForCurrentUser());
        unawaited(tryHandlePendingDeepLink());
      } else {
        _lastKnownToken = '';
      }
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      await handleDeepLinkData(initialMessage.data);
    }
  }

  Future<void> dispose() async {
    await _onMessageSub?.cancel();
    await _onMessageOpenedSub?.cancel();
    await _tokenRefreshSub?.cancel();
    await _authSub?.cancel();
  }

  Future<void> _requestPermissions() async {
    await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
  }

  Future<void> _configureLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) {
          unawaited(handleDeepLinkData(decoded));
        } else if (decoded is Map) {
          unawaited(
            handleDeepLinkData(
              decoded.map(
                (key, value) => MapEntry(key.toString(), value?.toString()),
              ),
            ),
          );
        }
      },
    );

    final androidPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_notificationChannel);
  }

  Future<void> _handleLocalNotificationLaunch() async {
    final launchDetails =
        await _localNotifications.getNotificationAppLaunchDetails();
    final launchPayload = launchDetails?.notificationResponse?.payload;
    if (launchPayload == null || launchPayload.isEmpty) return;
    final decoded = jsonDecode(launchPayload);
    if (decoded is Map<String, dynamic>) {
      await handleDeepLinkData(decoded);
    } else if (decoded is Map) {
      await handleDeepLinkData(
        decoded
            .map((key, value) => MapEntry(key.toString(), value?.toString())),
      );
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final title = message.notification?.title ??
        (message.data['title']?.toString() ?? 'Fitto');
    final body =
        message.notification?.body ?? (message.data['body']?.toString() ?? '');
    final payload = jsonEncode(message.data);

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _notificationChannel.id,
          _notificationChannel.name,
          channelDescription: _notificationChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      payload: payload,
    );
  }

  Future<void> _syncTokenForCurrentUser() async {
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    _lastKnownToken = token;
    await _upsertTokenForCurrentUser(token);
  }

  Future<void> _handleTokenRefresh(String newToken) async {
    if (newToken.trim().isEmpty) return;

    final oldToken = _lastKnownToken;
    if (oldToken.isNotEmpty && oldToken != newToken) {
      await _deactivateTokenForCurrentUser(oldToken);
    }

    _lastKnownToken = newToken;
    await _upsertTokenForCurrentUser(newToken);
  }

  Future<void> _upsertTokenForCurrentUser(String token) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userRef = _firestore.collection('users').doc(user.uid);
    final tokenRef = userRef.collection('fcm_tokens').doc(_tokenDocId(token));
    final tokenDoc = await tokenRef.get();
    final tokenData = tokenDoc.data() ?? const <String, dynamic>{};

    final updateData = <String, dynamic>{
      'token': token,
      'platform': _platformName(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isActive': true,
    };

    if (!tokenDoc.exists) {
      updateData['createdAt'] = FieldValue.serverTimestamp();
      updateData['lastSeenAt'] = FieldValue.serverTimestamp();
    } else if (_shouldUpdateLastSeen(tokenData['lastSeenAt'])) {
      updateData['lastSeenAt'] = FieldValue.serverTimestamp();
    }

    await tokenRef.set(updateData, SetOptions(merge: true));

    await userRef.set({
      'fcmToken': token,
      'primaryFcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _deactivateTokenForCurrentUser(String token) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final tokenRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('fcm_tokens')
        .doc(_tokenDocId(token));

    await tokenRef.set({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _tokenDocId(String token) {
    return base64UrlEncode(utf8.encode(token));
  }

  bool _shouldUpdateLastSeen(dynamic value) {
    if (value is Timestamp) {
      return DateTime.now().difference(value.toDate()) >
          const Duration(hours: 12);
    }
    return true;
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      _ => 'android',
    };
  }

  Future<void> handleDeepLinkData(Map<String, dynamic> rawData) async {
    final deepLink = NotificationDeepLink.fromRaw(rawData);
    _log('Incoming deep link data: ${deepLink.raw}');

    if (deepLink.type == NotificationDeepLinkType.unknown) {
      _log('Unknown notification type. No navigation performed.');
      return;
    }

    if (!_isNavigationReady()) {
      _pendingDeepLink = deepLink;
      _log('Navigation not ready, deep link queued.');
      return;
    }

    await _navigateByType(deepLink);
  }

  Future<void> tryHandlePendingDeepLink() async {
    if (_isHandlingPending) return;
    final pendingLink = _pendingDeepLink;
    if (pendingLink == null) return;
    if (!_isNavigationReady()) return;

    _isHandlingPending = true;
    _pendingDeepLink = null;
    try {
      await _navigateByType(pendingLink);
    } finally {
      _isHandlingPending = false;
    }
  }

  bool _isNavigationReady() {
    final appReady = _ref.read(appReadyProvider);
    final navReady = _navigatorKey.currentState != null;
    final user = _ref.read(authStateProvider).valueOrNull;
    return appReady && navReady && user != null;
  }

  Future<void> _navigateByType(NotificationDeepLink deepLink) async {
    _log('Resolved notification type: ${deepLink.type}');
    switch (deepLink.type) {
      case NotificationDeepLinkType.purchaseRequestAccepted:
        await _openPurchaseRequests(deepLink);
        break;
      case NotificationDeepLinkType.orderStatusUpdated:
        await _openOrderStatus(deepLink);
        break;
      case NotificationDeepLinkType.unknown:
        break;
    }
  }

  Future<void> _openPurchaseRequests(NotificationDeepLink deepLink) async {
    _ref.read(mainTabIndexProvider.notifier).state = mainTabOrdersIndex;
    _ref.read(myRequestsDeepLinkRequestIdProvider.notifier).state =
        deepLink.requestId;

    if (!deepLink.hasRequestId) {
      _showSnackBar('Request ID missing. Opened My Requests list.');
    }

    await Future<void>.delayed(const Duration(milliseconds: 150));

    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      _pendingDeepLink = deepLink;
      return;
    }

    if (rootRouteObserver.isRouteOnTop(AppRoutes.myRequests)) {
      _log('My Requests already open, skipping duplicate push.');
      return;
    }

    navigator.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: AppRoutes.myRequests),
        builder: (_) => MyRequestsScreen(
          initialRequestId: deepLink.requestId,
        ),
      ),
    );
  }

  Future<void> _openOrderStatus(NotificationDeepLink deepLink) async {
    _ref.read(mainTabIndexProvider.notifier).state = mainTabOrdersIndex;
    if (!deepLink.hasOrderId) {
      _showSnackBar('Order ID missing. Opened Orders tab.');
      return;
    }
    final orderId = deepLink.orderId!;

    await Future<void>.delayed(const Duration(milliseconds: 150));
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      _pendingDeepLink = deepLink;
      return;
    }

    if (rootRouteObserver.isRouteOnTop(
      AppRoutes.orderDetails,
      arguments: orderId,
    )) {
      _log('Order details already on top for this order, skipping push.');
      return;
    }

    navigator.push(
      MaterialPageRoute<void>(
        settings: RouteSettings(
          name: AppRoutes.orderDetails,
          arguments: orderId,
        ),
        builder: (_) => OrderDetailScreen(orderId: orderId),
      ),
    );
  }

  void _showSnackBar(String message) {
    final context = _navigatorKey.currentContext;
    if (context == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[NotificationService] $message');
    }
  }
}
