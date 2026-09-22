import 'package:flutter/widgets.dart';

import 'responsly.dart';

/// Reports named routes to the SDK as screens.
///
/// ```dart
/// MaterialApp(
///   navigatorObservers: [ResponslyNavigatorObserver()],
///   routes: {
///     '/': (context) => const HomePage(),
///     '/checkout': (context) => const CheckoutPage(),
///   },
/// );
/// ```
///
/// Calls [Responsly.screen] with the `settings.name` of the route that is on top after a push,
/// a pop or a replace, so the current screen stays correct when the user goes back. Routes
/// without a name are skipped: name the ones you push by hand with
/// `RouteSettings(name: 'Checkout')`.
class ResponslyNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _report(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _report(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute?.isCurrent ?? false) {
      _report(newRoute);
    }
  }

  void _report(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name == null || name.isEmpty) return;
    Responsly.screen(name);
  }
}
