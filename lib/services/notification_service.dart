import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../screens/notification_screen.dart';
import 'user_status_service.dart';

/// Top-level background handler for FCM notifications when app is terminated or in background
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    developer.log(
      'Handling background message: ${message.messageId} | Title: ${message.notification?.title}',
      name: 'NotificationService',
    );
  } catch (e) {
    developer.log('Background handler error: $e', name: 'NotificationService', error: e);
  }
}

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  FirebaseMessaging? get _firebaseMessaging =>
      Firebase.apps.isNotEmpty ? FirebaseMessaging.instance : null;

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'kmr_push_channel', // id matching AndroidManifest.xml
    'KMR Push Notifications', // name
    description: 'Channel used for KMR CRM push notifications',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  bool _isInitialized = false;

  /// Initialize Firebase Messaging & Local Notifications setup
  Future<void> initialize() async {
    if (_isInitialized) return;
    if (Firebase.apps.isEmpty || _firebaseMessaging == null) {
      developer.log('Firebase not initialized. Skipping NotificationService initialization.', name: 'NotificationService');
      return;
    }

    final messaging = _firebaseMessaging!;

    try {
      // 1. Request Notification Permissions (Required for Android 13+ & iOS)
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      developer.log(
        'User Notification Permission status: ${settings.authorizationStatus}',
        name: 'NotificationService',
      );

      // 2. Initialize Flutter Local Notifications Plugin for Foreground Banners
      const androidInitSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInitSettings = DarwinInitializationSettings();
      const initSettings = InitializationSettings(
        android: androidInitSettings,
        iOS: iosInitSettings,
      );

      await _localNotificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          developer.log(
            'Local notification tapped with payload: ${response.payload}',
            name: 'NotificationService',
          );
          _navigateToNotificationScreen();
        },
      );

      // 3. Create Android Notification Channel
      await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      // 4. Configure Foreground Presentation Options for iOS/macOS
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 5. Listen to Foreground Messages (App is active in foreground)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        developer.log(
          'Received Foreground Message: ${message.notification?.title}',
          name: 'NotificationService',
        );

        RemoteNotification? notification = message.notification;
        AndroidNotification? android = message.notification?.android;

        if (notification != null) {
          _showLocalNotification(
            id: notification.hashCode,
            title: notification.title ?? 'New Notification',
            body: notification.body ?? '',
            payload: message.data.toString(),
            android: android,
          );
        }
      });

      // 6. Listen to Notification Tap when App is in Background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        developer.log(
          'Notification Tapped (Background App State): ${message.notification?.title}',
          name: 'NotificationService',
        );
        _navigateToNotificationScreen();
      });

      // 7. Check if App was opened from Terminated State by tapping Notification
      RemoteMessage? initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        developer.log(
          'App launched from Terminated Notification: ${initialMessage.notification?.title}',
          name: 'NotificationService',
        );
        _navigateToNotificationScreen();
      }

      // 8. Fetch & Log FCM Device Token
      await getFcmToken();

      // 9. Listen for FCM Token Refreshes
      messaging.onTokenRefresh.listen((newToken) {
        developer.log('FCM Token Refreshed: $newToken', name: 'NotificationService');
      });

      _isInitialized = true;
      developer.log('NotificationService initialized successfully!', name: 'NotificationService');
    } catch (e) {
      developer.log('Error initializing NotificationService: $e', name: 'NotificationService', error: e);
    }
  }

  /// Trigger a test notification banner to verify notifications locally
  Future<void> sendTestNotification({
    String title = 'Test KMR Push Notification 🔔',
    String body = 'Push notifications are working perfectly in KMR Live App!',
  }) async {
    await _showLocalNotification(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      payload: 'test_notification_payload',
    );
  }

  /// Display a heads-up local notification banner for foreground messages
  Future<void> _showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    AndroidNotification? android,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: android?.smallIcon ?? '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotificationsPlugin.show(
      id,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Retrieve FCM Device Token
  Future<String?> getFcmToken() async {
    try {
      if (Firebase.apps.isNotEmpty && _firebaseMessaging != null) {
        String? token = await _firebaseMessaging!.getToken();
        if (token != null) {
          developer.log('FCM Token: $token', name: 'NotificationService');
        }
        return token;
      }
    } catch (e) {
      developer.log('Error getting FCM Token: $e', name: 'NotificationService', error: e);
    }
    return null;
  }

  /// Navigates directly to NotificationScreen when any push notification banner is tapped
  void _navigateToNotificationScreen() {
    try {
      final context = UserStatusService.navigatorKey.currentContext;
      if (context != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const NotificationScreen(),
          ),
        );
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = UserStatusService.navigatorKey.currentContext;
          if (ctx != null) {
            Navigator.of(ctx).push(
              MaterialPageRoute(
                builder: (_) => const NotificationScreen(),
              ),
            );
          }
        });
      }
    } catch (e) {
      developer.log('Error navigating to NotificationScreen on tap: $e', name: 'NotificationService');
    }
  }
}
