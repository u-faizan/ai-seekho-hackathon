import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AUTH SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _nameCtrl  = TextEditingController();
  bool _loading    = false;
  bool _hidePass   = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    
    try {
      final isLogin = _tab.index == 0;
      final password = _passCtrl.text.trim();

      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } else {
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        
        // Save initial profile info to Firestore
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'name': _nameCtrl.text.trim(),
          'email': email,
          'webhookUrl': '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Save flag for auto-login
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);

      if (!mounted) return;
      setState(() => _loading = false);
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const HomeShell(),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _loading = false;
        if (e.code == 'invalid-credential' || e.code == 'wrong-password' || e.code == 'user-not-found') {
          _error = 'Incorrect email address or password.';
        } else if (e.code == 'email-already-in-use') {
          _error = 'An account with this email already exists.';
        } else if (e.code == 'invalid-email') {
          _error = 'Please enter a valid email address.';
        } else {
          _error = e.message ?? 'Authentication failed. Please try again.';
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'An unexpected error occurred. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 32),
                // ── Logo ─────────────────────────────────────────────────
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Antigravity Ops',
                    style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text('Business Intelligence Console',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.textMuted)),
                const SizedBox(height: 36),

                // ── Card ─────────────────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(children: [
                    // Tab toggle
                    Padding(
                      padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.cardAlt,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TabBar(
                          controller: _tab,
                          labelStyle: GoogleFonts.inter(
                              fontWeight: FontWeight.w600, fontSize: 13),
                          unselectedLabelColor: AppColors.textMuted,
                          labelColor: Colors.white,
                          indicator: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryEnd],
                            ),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          tabs: const [
                            Tab(text: 'Sign In'),
                            Tab(text: 'Sign Up'),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
                      child: SizedBox(
                        height: 290,
                        child: TabBarView(
                          controller: _tab,
                          children: [
                            _buildForm(isLogin: true),
                            _buildForm(isLogin: false),
                          ],
                        ),
                      ),
                    ),
                  ]),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _errorBanner(_error!),
                ],
                const SizedBox(height: 32),
                Text('Secured by Firebase Authentication',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: AppColors.textMuted)),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm({required bool isLogin}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!isLogin) ...[
        _field(_nameCtrl, 'Full Name', Icons.person_outline_rounded),
        const SizedBox(height: 12),
      ],
      _field(_emailCtrl, 'Email Address', Icons.mail_outline_rounded,
          type: TextInputType.emailAddress),
      const SizedBox(height: 12),
      _field(_passCtrl, 'Password', Icons.lock_outline_rounded,
          obscure: _hidePass,
          suffix: IconButton(
            icon: Icon(
              _hidePass ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: AppColors.textMuted, size: 18,
            ),
            onPressed: () => setState(() => _hidePass = !_hidePass),
          )),
      const Spacer(),
      _loading
          ? const Center(
              child: SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 2),
              ))
          : _gradientBtn(
              isLogin ? 'Sign In' : 'Create Account',
              _submit,
            ),
    ]);
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType? type,
    bool obscure = false,
    Widget? suffix,
  }) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        obscureText: obscure,
        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted),
          prefixIcon: Icon(icon, color: AppColors.textMuted, size: 18),
          suffixIcon: suffix,
          filled: true,
          fillColor: AppColors.cardAlt,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME SHELL (Bottom Nav)
// ─────────────────────────────────────────────────────────────────────────────
class HomeShell extends StatefulWidget {
  const HomeShell({Key? key}) : super(key: key);

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _idx = 0;

  final _screens = const [HomeScreen(), HistoryScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: IndexedStack(index: _idx, children: _screens),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.navBg,
          border: Border(top: BorderSide(color: AppColors.navBorder, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Color(0x0C000000),
              blurRadius: 12,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _idx,
          onTap: (i) => setState(() => _idx = i),
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textMuted,
          selectedLabelStyle: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: GoogleFonts.inter(fontSize: 11),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
                icon: Icon(Icons.radar_rounded), label: 'Operations'),
            BottomNavigationBarItem(
                icon: Icon(Icons.history_rounded), label: 'History'),
            BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────
Widget _gradientBtn(String label, VoidCallback? onTap) => GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryEnd]),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withOpacity(0.28),
                blurRadius: 14,
                offset: const Offset(0, 5))
          ],
        ),
        child: Center(
          child: Text(label,
              style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ),
      ),
    );

Widget _errorBanner(String msg) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withOpacity(0.25)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: AppColors.danger, size: 15),
        const SizedBox(width: 8),
        Expanded(
            child: Text(msg,
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.danger))),
      ]),
    );
