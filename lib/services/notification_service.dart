import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Handles FCM setup, permission requests, token storage, and in-app banners.
///
/// Call [init] once on app start (after Firebase is initialized).
/// Call [requestPermission] on Day 2 of app use (per NOTIFICATIONS.md anti-fatigue rules).
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _firestore = FirebaseFirestore.instance;

  // Navigate-to callback set by app.dart (needed for background tap handling)
  static GlobalKey<NavigatorState>? navigatorKey;

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> init() async {
    // Listen for foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background taps (app was in background, user tapped notification)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Handle terminated state tap (app was closed)
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    // Refresh token when it rotates
    _messaging.onTokenRefresh.listen(_storeToken);
  }

  // ── Permission ────────────────────────────────────────────────────────────

  /// Request notification permission. Call this on Day 2 per anti-fatigue rules.
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    final granted = settings.authorizationStatus ==
        AuthorizationStatus.authorized;
    if (granted) {
      await _storeCurrentToken();
      await _subscribeToTopics();
    }
    return granted;
  }

  Future<void> _subscribeToTopics() async {
    // Subscribe to broadcast topics used by Cloud Functions.
    await _messaging.subscribeToTopic('daily_problem');
    await _messaging.subscribeToTopic('streak_alerts');
    await _messaging.subscribeToTopic('platform_updates');
  }

  /// Store FCM token without requesting permission (call if already granted).
  Future<void> storeTokenIfGranted() async {
    final settings = await _messaging.getNotificationSettings();
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      await _storeCurrentToken();
    }
  }

  Future<void> _storeCurrentToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) await _storeToken(token);
    } catch (_) {}
  }

  Future<void> _storeToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('profile')
          .doc('profile')
          .update({'fcmToken': token, 'fcmTokenUpdatedAt': FieldValue.serverTimestamp()});
    } catch (_) {}
  }

  // ── Foreground message handler ────────────────────────────────────────────

  void _handleForegroundMessage(RemoteMessage message) {
    final ctx = navigatorKey?.currentContext;
    if (ctx == null) return;

    final title = message.notification?.title ?? '';
    final body = message.notification?.body ?? '';
    final deepLink = message.data['deepLink'] as String?;

    // Show an in-app banner via ScaffoldMessenger
    ScaffoldMessenger.of(ctx).showMaterialBanner(
      MaterialBanner(
        backgroundColor: const Color(0xFF1E2A40),
        leading: const Icon(Icons.notifications_outlined,
            color: Color(0xFF00F5A0)),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title.isNotEmpty)
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      fontFamily: 'Inter')),
            if (body.isNotEmpty)
              Text(body,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 12, fontFamily: 'Inter'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
          ],
        ),
        actions: [
          if (deepLink != null)
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(ctx).hideCurrentMaterialBanner();
                _navigateToDeepLink(ctx, deepLink);
                _writeNotificationRead(message);
              },
              child: const Text('Open',
                  style: TextStyle(color: Color(0xFF00F5A0))),
            ),
          TextButton(
            onPressed: () =>
                ScaffoldMessenger.of(ctx).hideCurrentMaterialBanner(),
            child: const Text('Dismiss',
                style: TextStyle(color: Colors.white54)),
          ),
        ],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  // ── Notification tap handler ──────────────────────────────────────────────

  void _handleNotificationTap(RemoteMessage message) {
    final deepLink = message.data['deepLink'] as String?;
    final ctx = navigatorKey?.currentContext;
    if (deepLink != null && ctx != null) {
      _navigateToDeepLink(ctx, deepLink);
    }
    _writeNotificationRead(message);
  }

  void _navigateToDeepLink(BuildContext context, String deepLink) {
    try {
      // deepLink is a GoRouter path e.g. "/home", "/problem/two-sum/chat"
      GoRouter.of(context).push(deepLink);
    } catch (_) {}
  }

  Future<void> _writeNotificationRead(RemoteMessage message) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final notifId = message.messageId;
    if (notifId == null) return;
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(notifId)
          .update({'read': true});
    } catch (_) {}
  }
}
