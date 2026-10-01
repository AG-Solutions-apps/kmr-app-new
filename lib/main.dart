import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'services/user_status_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // 1. Initialize Firebase App safely for both Mobile and Web
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }

    // 2. Set Background Notification Handler (Mobile only)
    if (!kIsWeb && Firebase.apps.isNotEmpty) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }

    // 3. Initialize Push Notification Service
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('Firebase initialization warning (Web/Platform): $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: UserStatusService.navigatorKey,
      title: 'KMR Live',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const SplashScreen(),
    );
  }
}
