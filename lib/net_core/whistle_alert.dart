import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'geared_client.dart';
import 'keep_box.dart';

// ============================================================
// WHISTLE ALERT — Firebase Messaging + local notifications
// ============================================================
// Cold-start taps (app was killed) stash the URL so the shell opens it
// on next boot. Warm taps (background / foreground) deliver the URL
// live via [onUrl] without persisting (push URLs are one-time).
//
// The Android channel id here must match the manifest meta-data
// `default_notification_channel_id`. The small icon is the dedicated
// flame drawable, never the launcher icon.
// ============================================================

// Project-unique channel identifiers. Keep the manifest meta-data
// `default_notification_channel_id` in perfect lockstep with kChannelId.
const String kChannelId = 'gr_pitch_alerts_v1';
const String kChannelName = 'Match Alerts';
const String _smallIcon = '@drawable/ic_notification';

@pragma('vm:entry-point')
Future<void> _backgroundIsolate(RemoteMessage message) async {
  // OS renders the background notification on our behalf; the tap is
  // handled on resume (warm) or boot (cold) — nothing to do here.
}

class WhistleAlert {
  WhistleAlert(this._box);

  final KeepBox _box;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  FirebaseMessaging? _fm;
  String? _token;
  bool _armed = false;

  // Completer that resolves as soon as the cold-start initial message has
  // been fully processed (URL written to vault, or confirmed absent).
  // _resumeGray() awaits this before draining so the race between
  // stashPendingPush and drainPendingPush is eliminated.
  final Completer<void> _coldTapCompleter = Completer<void>();

  /// Resolves when the cold-start tap URL (if any) has been safely written
  /// to the secure vault. Always await this in _resumeGray before calling
  /// drainPendingPush on a cold start.
  Future<void> get coldTapReady => _coldTapCompleter.future;

  /// Live (warm) push URL delivery → loaded straight into the WebView.
  void Function(String url)? onUrl;

  /// Fired when FCM rotates the token → re-post the gate body.
  void Function(String token)? onTokenRotated;

  String? get token => _token;

  Future<void> ignite() async {
    if (_armed) {
      if (!_coldTapCompleter.isCompleted) _coldTapCompleter.complete();
      return;
    }
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _fm = FirebaseMessaging.instance;
      FirebaseMessaging.onBackgroundMessage(_backgroundIsolate);

      await _wireLocal();

      _token = await _fm!.getToken();
      _fm!.onTokenRefresh.listen((String fresh) {
        _token = fresh;
        onTokenRotated?.call(fresh);
      });

      FirebaseMessaging.onMessage.listen(_onForeground);
      FirebaseMessaging.onMessageOpenedApp.listen(_onWarmTap);

      final RemoteMessage? initial = await _fm!.getInitialMessage();
      // Await _onColdTap so the vault write completes before coldTapReady
      // resolves — eliminating the stash/drain race condition on cold start.
      if (initial != null) await _onColdTap(initial);

      _armed = true;
    } catch (_) {
      // Firebase not wired yet — push stays dormant, app keeps running.
    } finally {
      // Always resolve so _resumeGray() is never stuck waiting.
      if (!_coldTapCompleter.isCompleted) _coldTapCompleter.complete();
    }
  }

  Future<void> _wireLocal() async {
    const AndroidInitializationSettings android =
        AndroidInitializationSettings(_smallIcon);
    const DarwinInitializationSettings ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (NotificationResponse r) {
        final String? payload = r.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final Map<String, dynamic> data =
              jsonDecode(payload) as Map<String, dynamic>;
          final String? url = data['url'] as String?;
          if (url != null && url.isNotEmpty) onUrl?.call(url);
        } catch (_) {}
      },
    );

    if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? android = _local
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          kChannelId,
          kChannelName,
          description: 'Live match alerts and offers',
          importance: Importance.high,
        ),
      );
    }
  }

  /// Asks for notification permission (Android 13+ system dialog).
  /// Records an OS-denied flag so the invite screen never loops.
  Future<bool> askPermission() async {
    if (_fm == null) return false;
    final NotificationSettings settings = await _fm!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final AuthorizationStatus status = settings.authorizationStatus;
    final bool granted = status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional;

    await _box.savePushGranted(granted);
    if (status == AuthorizationStatus.denied) {
      await _box.markPushBlockedByOs();
    }
    return granted;
  }

  void _onForeground(RemoteMessage message) async {
    final RemoteNotification? n = message.notification;
    if (n == null || !Platform.isAndroid) return;

    AndroidNotificationDetails? details;
    final String? imageUrl = n.android?.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      final Uint8List? bytes = await _grabImage(imageUrl);
      if (bytes != null) {
        details = AndroidNotificationDetails(
          kChannelId,
          kChannelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: _smallIcon,
          styleInformation: BigPictureStyleInformation(
            ByteArrayAndroidBitmap(bytes),
            largeIcon:
                const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
          ),
        );
      }
    }

    details ??= const AndroidNotificationDetails(
      kChannelId,
      kChannelName,
      importance: Importance.high,
      priority: Priority.high,
      icon: _smallIcon,
    );

    await _local.show(
      n.hashCode,
      n.title,
      n.body,
      NotificationDetails(android: details),
      payload: message.data.isNotEmpty ? jsonEncode(message.data) : null,
    );
  }

  Future<void> _onColdTap(RemoteMessage message) async {
    final String? url = message.data['url'] as String?;
    if (url != null && url.isNotEmpty) {
      await _box.stashPendingPush(url);
    }
  }

  void _onWarmTap(RemoteMessage message) {
    final String? url = message.data['url'] as String?;
    if (url != null && url.isNotEmpty) {
      onUrl?.call(url);
    }
  }

  Future<Uint8List?> _grabImage(String url) async {
    try {
      final dynamic res = await stadiumWire
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) return res.bodyBytes as Uint8List;
    } catch (_) {}
    return null;
  }
}
