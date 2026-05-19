import 'package:flutter/material.dart';
import 'dart:async';
import '../main.dart';
import 'auth_screen.dart';
import 'home_screen.dart'; // To get the HomeShell class if we need it
// Actually, HomeShell is defined in auth_screen.dart, so we're good.

class CustomSplashScreen extends StatefulWidget {
  final bool isLoggedIn;
  const CustomSplashScreen({Key? key, required this.isLoggedIn}) : super(key: key);

  @override
  State<CustomSplashScreen> createState() => _CustomSplashScreenState();
}

class _CustomSplashScreenState extends State<CustomSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    // Setup a subtle breathing animation for the logo
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Wait for 2.5 seconds, then navigate based on login state
    Timer(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => widget.isLoggedIn ? const HomeShell() : const AuthScreen(),
          transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 600),
        ),
      );
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo inside a circular loading ring
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 3,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  ),
                ),
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Image.asset(
                    'assets/logo.png',
                    width: 90,
                    height: 90,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
