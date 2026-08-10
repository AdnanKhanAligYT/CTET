import 'package:flutter/widgets.dart';

/// Shared RouteObserver registered on GoRouter's Navigator (see
/// `navigatorObservers` in app_router.dart). Screens that need to know
/// "the user came back to me via back navigation" — not the same as
/// initState, which never re-runs when popping back onto a widget that's
/// still alive further down the stack — subscribe to this and override
/// didPopNext().
final routeObserver = RouteObserver<ModalRoute<void>>();
