import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _webhookCtrl = TextEditingController();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  bool _webhookSaved  = false;
  bool _saving        = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _emailCtrl.text = user.email ?? '';
      
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data()!;
          setState(() {
            _nameCtrl.text = data['name'] ?? '';
            _webhookCtrl.text = data['webhookUrl'] ?? '';
          });
        }
      } catch (e) {
        debugPrint('Error loading profile: $e');
      }
    }
  }

  @override
  void dispose() {
    _webhookCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() { _saving = true; _webhookSaved = false; });
    
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _nameCtrl.text.trim(),
        'webhookUrl': _webhookCtrl.text.trim(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving profile: $e');
    }
    
    if (!mounted) return;
    setState(() { _saving = false; _webhookSaved = true; });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _webhookSaved = false);
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Clear all saved data
    
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AuthScreen(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        child: Column(children: [
          // ── Header ───────────────────────────────────────────────────
          Container(
            color: AppColors.card,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(children: [
              Text('Profile',
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
            ]),
          ),

          // ── Scrollable body ───────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                // ── Avatar + user summary ─────────────────────────────
                _card(
                  child: Row(children: [
                    // Initial avatar
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryEnd],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text('O',
                            style: GoogleFonts.inter(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(_nameCtrl.text,
                            style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 2),
                        Text(_emailCtrl.text,
                            style: GoogleFonts.inter(
                                fontSize: 12, color: AppColors.textMuted)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('Operations Admin',
                              style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
                        ),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),

                // ── Basic info ────────────────────────────────────────
                _card(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    _sectionLabel('Personal Information'),
                    const SizedBox(height: 14),
                    _profileField('Full Name', _nameCtrl,
                        Icons.person_outline_rounded),
                    const SizedBox(height: 12),
                    _profileField('Email Address', _emailCtrl,
                        Icons.mail_outline_rounded,
                        readOnly: true),
                  ]),
                ),
                const SizedBox(height: 14),

                // ── Discord webhook ───────────────────────────────────
                _card(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    _sectionLabel('Discord Integration'),
                    const SizedBox(height: 4),
                    Text(
                      'Alerts for your AI pipeline runs will be posted to this webhook URL.',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.textMuted, height: 1.45),
                    ),
                    const SizedBox(height: 14),
                    // Discord icon header
                    Row(children: [
                      Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEEEFC),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.discord,
                            color: Color(0xFF5865F2), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text('Discord Webhook URL',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                    ]),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _webhookCtrl,
                      style: GoogleFonts.inter(
                          fontSize: 12, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'https://discord.com/api/webhooks/...',
                        hintStyle: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.cardAlt,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 1.5),
                        ),
                      ),
                    ),
                    if (_webhookSaved) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.successLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.success.withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.check_circle_outline_rounded,
                              color: AppColors.success, size: 15),
                          const SizedBox(width: 8),
                          Text('Saved to Firebase successfully!',
                              style: GoogleFonts.inter(
                                  fontSize: 12, color: AppColors.success)),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: _saving ? null : _saveProfile,
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryEnd]),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.primary.withOpacity(0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 4))
                          ],
                        ),
                        child: Center(
                          child: _saving
                              ? const SizedBox(
                                  width: 18, height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Text('Save Profile',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),

                // ── App info ──────────────────────────────────────────
                _card(
                  child: Column(children: [
                    _infoRow(Icons.info_outline_rounded, 'Version', '1.0.0'),
                    const Divider(height: 20, color: AppColors.border),
                    _infoRow(Icons.security_outlined, 'Auth Provider', 'Firebase Auth'),
                    const Divider(height: 20, color: AppColors.border),
                    _infoRow(Icons.storage_outlined, 'Database', 'Firestore + SQLite'),
                  ]),
                ),
                const SizedBox(height: 14),

                // ── Logout ────────────────────────────────────────────
                GestureDetector(
                  onTap: _logout,
                  child: Container(
                    width: double.infinity,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.danger.withOpacity(0.3)),
                    ),
                    child: Center(
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.logout_rounded,
                            color: AppColors.danger, size: 17),
                        const SizedBox(width: 8),
                        Text('Sign Out',
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.danger)),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: child,
      );

  Widget _sectionLabel(String label) => Text(
        label,
        style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textSub,
            letterSpacing: 0.3),
      );

  Widget _profileField(
    String label,
    TextEditingController ctrl,
    IconData icon, {
    bool readOnly = false,
  }) =>
      TextField(
        controller: ctrl,
        readOnly: readOnly,
        style: GoogleFonts.inter(fontSize: 13, color: AppColors.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle:
              GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
          prefixIcon: Icon(icon, size: 17, color: AppColors.textMuted),
          filled: true,
          fillColor:
              readOnly ? AppColors.scaffold : AppColors.cardAlt,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: readOnly
                ? const BorderSide(color: AppColors.border)
                : const BorderSide(color: AppColors.primary, width: 1.5),
          ),
        ),
      );

  Widget _infoRow(IconData icon, String label, String value) => Row(children: [
        Icon(icon, size: 16, color: AppColors.textMuted),
        const SizedBox(width: 10),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.textSub)),
        const Spacer(),
        Text(value,
            style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
      ]);
}
