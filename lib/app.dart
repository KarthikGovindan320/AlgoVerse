import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/providers.dart';
import 'services/notification_service.dart';

class AlgoVerseApp extends ConsumerStatefulWidget {
  const AlgoVerseApp({super.key});

  @override
  ConsumerState<AlgoVerseApp> createState() => _AlgoVerseAppState();
}

class _AlgoVerseAppState extends ConsumerState<AlgoVerseApp> {
  bool _permissionChecked = false;

  @override
  void initState() {
    super.initState();
    // Wire the global navigator key so NotificationService can show banners
    // and navigate on notification taps.
    NotificationService.navigatorKey = rootNavigatorKey;
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    // When the user transitions from signed-out → signed-in, check whether
    // we should request notification permission (Day-2 anti-fatigue rule).
    ref.listen(authStateProvider, (previous, next) {
      final wasSignedOut = previous?.value == null;
      final isSignedIn = next.value != null;
      if (wasSignedOut && isSignedIn && !_permissionChecked) {
        _permissionChecked = true;
        _maybeRequestPermission();
      }
    });

    return MaterialApp.router(
      title: 'AlgoVerse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: router,
    );
  }

  Future<void> _maybeRequestPermission() async {
    final prefs = await SharedPreferences.getInstance();
    final count = prefs.getInt('launch_count') ?? 1;
    if (count >= 2) {
      await NotificationService().requestPermission();
    } else {
      // Already granted from a previous session? Refresh the stored token.
      await NotificationService().storeTokenIfGranted();
    }
  }
}
