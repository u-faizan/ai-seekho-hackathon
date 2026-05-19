import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/auth_screen.dart';
import 'screens/splash_screen.dart';

// ── App Color Palette — Clean Professional Light Theme ───────────────────────
class AppColors {
  // Backgrounds
  static const scaffold     = Color(0xFFF8FAFC);  // Soft off-white
  static const card         = Color(0xFFFFFFFF);  // Pure white cards
  static const cardAlt      = Color(0xFFF1F5F9);  // Subtle gray for input bg
  static const border       = Color(0xFFE2E8F0);  // Soft slate border
  static const borderFocus  = Color(0xFF6366F1);  // Indigo focus ring

  // Brand
  static const primary      = Color(0xFF6366F1);  // Indigo
  static const primaryLight = Color(0xFFEEF2FF);  // Indigo tint background
  static const primaryEnd   = Color(0xFF8B5CF6);  // Violet

  // Semantic
  static const success      = Color(0xFF10B981);
  static const successLight = Color(0xFFECFDF5);
  static const warning      = Color(0xFFF59E0B);
  static const warningLight = Color(0xFFFFFBEB);
  static const danger       = Color(0xFFEF4444);
  static const dangerLight  = Color(0xFFFEF2F2);

  // Text
  static const textPrimary  = Color(0xFF0F172A);  // Near-black
  static const textSub      = Color(0xFF475569);  // Slate 600
  static const textMuted    = Color(0xFF94A3B8);  // Slate 400

  // Bottom nav
  static const navBg        = Color(0xFFFFFFFF);
  static const navBorder    = Color(0xFFE2E8F0);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase using the manual config
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final prefs = await SharedPreferences.getInstance();
  final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  
  runApp(AntigravityOpsApp(isLoggedIn: isLoggedIn));
}

class AntigravityOpsApp extends StatelessWidget {
  final bool isLoggedIn;
  const AntigravityOpsApp({Key? key, required this.isLoggedIn}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Antigravity Ops',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.scaffold,
        cardColor: AppColors.card,
        primaryColor: AppColors.primary,
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme)
            .apply(bodyColor: AppColors.textPrimary),
        colorScheme: const ColorScheme.light(
          primary: AppColors.primary,
          surface: AppColors.card,
        ),
        dividerColor: AppColors.border,
      ),
      home: CustomSplashScreen(isLoggedIn: isLoggedIn),
    );
  }
}
