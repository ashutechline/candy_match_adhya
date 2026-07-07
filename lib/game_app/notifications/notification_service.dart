import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Top-level background message handler.
/// Must be top-level or static and annotated with @pragma('vm:entry-point').
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Attempt to initialize Firebase Core if needed
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    debugPrint('NotificationService [Background]: Failed to initialize Firebase: $e');
  }
  debugPrint('NotificationService [Background]: Received background message: ${message.messageId}');
  debugPrint('Title: ${message.notification?.title}');
  debugPrint('Body: ${message.notification?.body}');
  debugPrint('Data: ${message.data}');
}

class NotificationService {
  static final NotificationService instance = NotificationService._();

  NotificationService._();

  bool _isInitialized = false;

  Future<void> init() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        final messaging = FirebaseMessaging.instance;
        
        // Request permissions (primarily for iOS / Web)
        final settings = await messaging.requestPermission(
          alert: true,
          announcement: false,
          badge: true,
          carPlay: false,
          criticalAlert: false,
          provisional: false,
          sound: true,
        );

        debugPrint('NotificationService: User granted permission status: ${settings.authorizationStatus}');

        // Fetch FCM token
        String? token;
        try {
          token = await messaging.getToken();
          debugPrint('NotificationService FCM Token: $token');
        } catch (tokenErr) {
          debugPrint('NotificationService: Could not retrieve FCM token: $tokenErr');
        }

        // Setup Foreground message listener
        FirebaseMessaging.onMessage.listen((RemoteMessage message) {
          debugPrint('NotificationService [Foreground]: Message received: ${message.messageId}');
          debugPrint('Title: ${message.notification?.title}');
          debugPrint('Body: ${message.notification?.body}');
          debugPrint('Data: ${message.data}');
        });

        // Setup OpenedApp message listener (when app is in background but still running)
        FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
          debugPrint('NotificationService [OpenedApp]: App opened from notification: ${message.messageId}');
          debugPrint('Data: ${message.data}');
        });

        // Check if the app was opened from a terminated state via a notification
        final initialMessage = await messaging.getInitialMessage();
        if (initialMessage != null) {
          debugPrint('NotificationService [InitialMessage]: App opened from terminated state: ${initialMessage.messageId}');
          debugPrint('Data: ${initialMessage.data}');
        }

        _isInitialized = true;
        debugPrint('NotificationService: Firebase Messaging initialized successfully.');
      } else {
        debugPrint('NotificationService: Firebase Core not initialized. Running in mock mode.');
      }
    } catch (e) {
      debugPrint('NotificationService: Failed to initialize Firebase Messaging: $e. Running in mock mode.');
    }
  }

  bool get isInitialized => _isInitialized;
}
