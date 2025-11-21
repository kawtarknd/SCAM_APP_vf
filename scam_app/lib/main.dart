import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth; // ✅ CORRECTION: Préfixe
// 🚨 AJOUT ESSENTIEL
import 'package:firebase_database/firebase_database.dart'; 
import 'firebase_options.dart';

// Screens
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/notifications_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ✅ NOUVEL IMPORT SUPABASE

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 🚨 PARAMÈTRES SUPABASE (Clés de votre code ESP32)
  const String supabaseUrl = 'https://tbezjmumeblaiqvnirmm.supabase.co'; // URL de base
  const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRiZXpqbXVtZWJsYWlxdm5pcm1tIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM0MDI0MzAsImV4cCI6MjA3ODk3ODQzMH0.wSdvhlB_I5vPJ-zwpe8yxLFnKSyheUyPRMnSoKDV2Kk'; 
  
  // L'URL de Firebase Realtime Database pour les données en temps réel (si toujours utilisée)
  const String customDatabaseUrl = 'https://scam-742f5-default-rtdb.europe-west1.firebasedatabase.app/'; 

  // 1. Initialiser Firebase Core
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // 2. Initialiser Supabase 🚨 NOUVELLE ÉTAPE
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  
  // 3. Configuration Firebase Realtime DB
  FirebaseDatabase.instance.databaseURL = customDatabaseUrl; 

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.light;

  void toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SCAM App',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: const Color(0xFF77BEF0),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF77BEF0),
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF77BEF0),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(10))),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: const Color(0xFFF3F4F6),
          labelStyle: const TextStyle(color: Color(0xFF6B7280)),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF77BEF0),
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF77BEF0),
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: AuthCheck(toggleTheme: toggleTheme, isDark: _themeMode == ThemeMode.dark),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/dashboard': (context) => DashboardScreen(
              toggleTheme: toggleTheme,
              isDark: _themeMode == ThemeMode.dark,
            ),
        '/settings': (context) => SettingsScreen(
              toggleTheme: toggleTheme,
              isDark: _themeMode == ThemeMode.dark,
            ),
        '/notifications': (context) => NotificationsScreen(),
      },
    );
  }
}

class AuthCheck extends StatelessWidget {
  final Function(bool) toggleTheme;
  final bool isDark;

  const AuthCheck({super.key, required this.toggleTheme, required this.isDark});

  @override
  Widget build(BuildContext context) {
    // 🚨 CORRECTION: Utilisation du préfixe 'firebase_auth' pour le type User
    return StreamBuilder<firebase_auth.User?>( 
      stream: firebase_auth.FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData) {
          // L'utilisateur est connecté → Dashboard
          return DashboardScreen(toggleTheme: toggleTheme, isDark: isDark);
        }

        // Non connecté → Login
        return const LoginScreen();
      },
    );
  }
}