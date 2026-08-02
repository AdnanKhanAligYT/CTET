import 'dart:async';

import 'package:flutter/foundation.dart';

/// Bridges any Stream (here, `FirebaseAuth.authStateChanges()`) into a
/// `Listenable` so `GoRouter`'s `refreshListenable` re-runs the `redirect`
/// callback the instant the user signs in or out — this is the standard
/// go_router + Firebase Auth wiring pattern.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
