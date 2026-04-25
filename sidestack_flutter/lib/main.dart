import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:app_links/app_links.dart';
import 'firebase_options.dart';
import 'providers/app_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/mileage_provider.dart';
import 'theme/app_theme.dart';
import 'screens/main_shell.dart';
import 'screens/auth_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/username_setup_screen.dart';
import 'screens/bank_import_screen.dart';
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
      home: const _DeepLinkHandler(),
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

// ─── Deep-link handler ────────────────────────────────────────────────────────
// Wraps the entire app tree and listens for sidestack://bank-callback URIs
// produced by the TrueLayer OAuth redirect. When one arrives it hands off the
// code + state to AppProvider, then pushes BankImportScreen so the user can
// review and import the fetched transactions.
class _DeepLinkHandler extends StatefulWidget {
  const _DeepLinkHandler();

  @override
  State<_DeepLinkHandler> createState() => _DeepLinkHandlerState();
}

class _DeepLinkHandlerState extends State<_DeepLinkHandler> {
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    _linkSub = AppLinks().uriLinkStream.listen(_handleLink);
  }

  Future<void> _handleLink(Uri uri) async {
    // Only handle our custom OAuth-return scheme.
    if (uri.scheme != 'sidestack' || uri.host != 'bank-callback') return;

    final code = uri.queryParameters['code'];
    final state = uri.queryParameters['state'];
    if (code == null || state == null) return;

    if (!mounted) return;
    final provider = context.read<AppProvider>();

    try {
      await provider.handleBankCallback(code, state);
      if (!mounted) return;
      // Navigate to the review screen.  Use push so the user can go back
      // to whatever screen they were on before the OAuth flow started.
      await Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => const BankImportScreen()),
      );
    } catch (e) {
      debugPrint('Bank callback error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bank connection failed: $e'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const RootScreen();
}

