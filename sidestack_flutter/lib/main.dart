import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'providers/app_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/mileage_provider.dart';
import 'theme/app_theme.dart';
import 'screens/main_shell.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/username_setup_screen.dart';
import 'services/notification_service.dart';
import 'services/purchase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // App Check: ensures only the real SideStacks app can call Firebase Functions.
  // Uses Play Integrity on Android (requires Play Store distribution or
  // registered debug fingerprint). Falls back gracefully if unavailable.
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity,
    appleProvider: kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
  );

  // Print App Check debug token so it's visible in flutter run output
  if (kDebugMode) {
    try {
      final token = await FirebaseAppCheck.instance.getToken(true);
      debugPrint('🔑 App Check debug token: $token');
    } catch (e) {
      debugPrint('⚠️ App Check token error: $e');
    }
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF161918),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialise push notifications (requests permission on first launch)
  // Wrapped in try-catch: a notification init failure (e.g. scheduling
  // permission denied on Android 12+) must not prevent the app launching.
  try {
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint('NotificationService init failed: $e');
  }

  // Initialise RevenueCat (must run before any purchase calls)
  try {
    await PurchaseService.instance.configure();
  } catch (e) {
    // RC init failure should not prevent the app from launching
    debugPrint('RevenueCat init failed: $e');
  }

  runApp(const SideStackApp());
}

class SideStackApp extends StatelessWidget {
  const SideStackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, AppProvider>(
          create: (_) => AppProvider(),
          update: (_, auth, app) {
            app?.onAuthChanged(auth.userId);
            return app ?? AppProvider();
          },
        ),
        ChangeNotifierProvider(create: (_) => MileageProvider()),
      ],
      child: const _AppMaterial(),
    );
  }
}

// Separate widget so it can watch AppProvider for themeMode changes.
class _AppMaterial extends StatelessWidget {
  const _AppMaterial();

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<AppProvider, ThemeMode>(
      (p) => p.themeMode,
    );
    return MaterialApp(
      title: 'SideStacks',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      // Apply a single consistent max-width to every route so the app
      // looks uniform on all screen sizes.
      builder: (context, child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: child!,
        ),
      ),
      home: const RootScreen(),
    );
  }
}

class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final app = context.watch<AppProvider>();

    if (auth.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6))),
      );
    }

    if (!auth.isSignedIn) return const AuthScreen();

    // OAuth users who haven't chosen a username yet.
    if (auth.needsUsernameSetup) return const UsernameSetupScreen();

    // Wait for prefs to load before deciding onboarding vs shell.
    if (!app.isLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF14B8A6))),
      );
    }

    if (!app.hasSeenOnboarding) return const OnboardingScreen();

    return const MainShell();
  }
}


