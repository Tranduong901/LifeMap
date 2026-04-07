import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

import 'providers/main_navigation_provider.dart';
import 'views/auth/auth_view.dart';
import 'views/main_screen.dart';

const Color _kPrimaryColor = Color(0xFF9575CD);
const Color _kAccentColor = Color(0xFF9575CD);
const Color _kAppBackground = Color(0xFFF0F2F5);
const Color _kSubTextColor = Color(0xFF78909C);

const FirebaseOptions _webFirebaseOptions = FirebaseOptions(
  apiKey: 'AIzaSyBygRDAY1m9goXqkbyW1QUsHxnk7EC8VUM',
  appId: '1:841983025732:web:df3a4ae37b284cb4db1211',
  messagingSenderId: '841983025732',
  projectId: 'lifemap-82da6',
  authDomain: 'lifemap-82da6.firebaseapp.com',
  storageBucket: 'lifemap-82da6.firebasestorage.app',
  measurementId: 'G-GE39814X17',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  bool firebaseReady = false;
  String? firebaseInitError;

  try {
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux) {
      await Firebase.initializeApp(options: _webFirebaseOptions);
    } else {
      await Firebase.initializeApp();
    }
    firebaseReady = true;
  } catch (error, stackTrace) {
    firebaseInitError = error.toString();
    debugPrint('Firebase initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
  runApp(
    LifeMapApp(
      firebaseReady: firebaseReady,
      firebaseInitError: firebaseInitError,
    ),
  );
}

class LifeMapApp extends StatelessWidget {
  const LifeMapApp({
    required this.firebaseReady,
    this.firebaseInitError,
    super.key,
  });

  final bool firebaseReady;
  final String? firebaseInitError;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<MainNavigationProvider>(
          create: (_) => MainNavigationProvider(),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'LifeMap',
        theme: ThemeData(
          useMaterial3: true,
          fontFamily: 'Roboto',
          scaffoldBackgroundColor: _kAppBackground,
          colorScheme: ColorScheme.fromSeed(
            seedColor: _kPrimaryColor,
            primary: _kPrimaryColor,
            secondary: _kAccentColor,
            surface: Colors.white,
            brightness: Brightness.light,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: _kPrimaryColor,
            elevation: 0,
            centerTitle: true,
            iconTheme: IconThemeData(color: _kPrimaryColor),
            actionsIconTheme: IconThemeData(color: _kPrimaryColor),
            titleTextStyle: TextStyle(
              color: _kPrimaryColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0.8,
            shadowColor: Color(0x2278909C),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimaryColor,
              foregroundColor: Colors.white,
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: _kPrimaryColor,
              foregroundColor: Colors.white,
            ),
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: _kPrimaryColor,
            foregroundColor: Colors.white,
          ),
          textTheme: const TextTheme(
            bodySmall: TextStyle(color: _kSubTextColor),
            bodyMedium: TextStyle(color: _kSubTextColor),
          ),
        ),
        home: AuthWrapper(
          firebaseReady: firebaseReady,
          firebaseInitError: firebaseInitError,
        ),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({
    required this.firebaseReady,
    this.firebaseInitError,
    super.key,
  });

  final bool firebaseReady;
  final String? firebaseInitError;

  @override
  Widget build(BuildContext context) {
    if (!firebaseReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasData) {
          return const MainScreen();
        }

        return const AuthView();
      },
    );
  }
}
