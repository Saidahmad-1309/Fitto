import 'package:flutter/material.dart';

class RootRouteObserver extends NavigatorObserver {
  String? _topRouteName;
  Object? _topRouteArguments;

  String? get topRouteName => _topRouteName;
  Object? get topRouteArguments => _topRouteArguments;

  bool isRouteOnTop(String routeName, {Object? arguments}) {
    if (_topRouteName != routeName) return false;
    if (arguments == null) return true;
    return _topRouteArguments == arguments;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _captureTop(route);
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _captureTop(previousRoute);
    super.didPop(route, previousRoute);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _captureTop(previousRoute);
    super.didRemove(route, previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _captureTop(newRoute);
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
  }

  void _captureTop(Route<dynamic>? route) {
    _topRouteName = route?.settings.name;
    _topRouteArguments = route?.settings.arguments;
  }
}

final RootRouteObserver rootRouteObserver = RootRouteObserver();
