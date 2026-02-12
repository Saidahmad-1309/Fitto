import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitto/core/navigation/root_navigator_key.dart';
import 'package:fitto/core/navigation/root_route_observer.dart';
import 'package:fitto/services/notification_service.dart';

import 'firebase_options.dart';
import 'features/auth/presentation/screens/auth_gate_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _initializeFirebaseSafely();

  final analytics = FirebaseAnalytics.instance;
  await analytics.setAnalyticsCollectionEnabled(true);
  await analytics.logAppOpen();

  runApp(
    ProviderScope(
      child: FittoApp(analytics: analytics),
    ),
  );
}

Future<void> _initializeFirebaseSafely() async {
  if (Firebase.apps.isNotEmpty) {
    return;
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (error) {
    final isDuplicateDefault = error.code == 'duplicate-app' ||
        error.message?.toLowerCase().contains('[default] already exists') ==
            true;
    if (!isDuplicateDefault) {
      rethrow;
    }
  }
}

class FittoApp extends ConsumerStatefulWidget {
  const FittoApp({super.key, required this.analytics});

  final FirebaseAnalytics analytics;

  @override
  ConsumerState<FittoApp> createState() => _FittoAppState();
}

class _FittoAppState extends ConsumerState<FittoApp> {
  late final FirebaseAnalyticsObserver _observer = FirebaseAnalyticsObserver(
    analytics: widget.analytics,
  );

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(notificationServiceProvider).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'Fitto',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [_observer, rootRouteObserver],
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
      ),
      home: const AuthGateScreen(),
    );
  }
}
