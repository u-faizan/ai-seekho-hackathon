import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:http_parser/http_parser.dart';
import '../main.dart';

const String _kApiBase = 'https://ai-seekho-backend-1000940240202.us-central1.run.app';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _textCtrl = TextEditingController();
  bool _loading   = false;
  String? _error;
  Map<String, dynamic>? _result;
  int _inputMode = 0; // 0 = text, 1 = PDF
  String? _selectedFileName;
  PlatformFile? _selectedFile;
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  String _historyInsightText(dynamic insight) {
    if (insight is Map) {
      return insight['anomaly']?.toString() ?? 'Analysis complete';
    }
    if (insight is String && insight.isNotEmpty) return insight;
    return 'Analysis complete';
  }

  String _historySeverity(dynamic impact, dynamic severity) {
    if (severity is String && severity.isNotEmpty) return severity;
    if (impact is Map) {
      return impact['severity']?.toString() ?? 'LOW';
    }
    return 'LOW';
  }

  String _historyActionText(dynamic action, dynamic actionTaken) {
    if (action is Map) {
      return action['action_title']?.toString() ??
          action['action_type']?.toString() ??
          'No action required';
    }
    if (actionTaken is String && actionTaken.isNotEmpty) return actionTaken;
    return 'No action required';
  }

  Future<void> _saveHistoryToFirebase(String input, Map<String, dynamic> resultData) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('history')
          .add({
        'timestamp': FieldValue.serverTimestamp(),
        'input': input,
        'insight': _historyInsightText(resultData['insight']),
        'severity': _historySeverity(resultData['impact'], resultData['severity']),
        'action': _historyActionText(
          resultData['recommended_action'],
          resultData['action_taken'],
        ),
      });
    } catch (e) {
      debugPrint('Error saving history: $e');
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final text = _textCtrl.text.trim();
    if (_inputMode == 0 && text.isEmpty) {
      setState(() => _error = 'Please enter a business report or URL.');
      return;
    }
    if (_inputMode == 1 && _selectedFile == null) {
      setState(() => _error = 'Please select a PDF document first.');
      return;
    }
    setState(() { _loading = true; _result = null; _error = null; });

    try {
      String webhookUrl = '';
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          webhookUrl = doc.data()?['webhookUrl'] ?? '';
        }
      }

      if (_inputMode == 0) {
        // Text mode
        final res = await http.post(
          Uri.parse('$_kApiBase/api/v1/test/analyze'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'source': 'mobile_app',
            'data_type': 'text/plain',
            'content': text,
            'webhook_url': webhookUrl, // Sending webhook locally
          }),
        ).timeout(const Duration(seconds: 90));

        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          setState(() => _result = decoded);
          await _saveHistoryToFirebase(text, decoded);
        } else {
          final err = jsonDecode(res.body);
          setState(() => _error = err['detail'] ?? 'Server error ${res.statusCode}');
        }
      } else {
        // PDF mode (Multipart Upload)
        var uri = Uri.parse('$_kApiBase/api/v1/test/upload');
        var request = http.MultipartRequest('POST', uri);
        
        request.files.add(http.MultipartFile.fromBytes(
          'file', 
          _selectedFile!.bytes!, 
          filename: _selectedFile!.name,
          contentType: MediaType('application', 'pdf'),
        ));
        
        if (text.isNotEmpty) {
          request.fields['text'] = text;
        }
        if (webhookUrl.isNotEmpty) {
          request.fields['webhook_url'] = webhookUrl;
        }

        var response = await request.send().timeout(const Duration(seconds: 90));
        var responseString = await response.stream.bytesToString();

        if (response.statusCode == 200) {
          final decoded = jsonDecode(responseString);
          setState(() => _result = decoded);
          await _saveHistoryToFirebase(_selectedFileName ?? 'Uploaded PDF', decoded);
        } else {
          final err = jsonDecode(responseString);
          setState(() => _error = err['detail'] ?? 'Server error ${response.statusCode}');
        }
      }
    } catch (e) {
      setState(() => _error = 'Could not connect to backend: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Top bar ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                color: AppColors.card,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Row(children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryEnd]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset('assets/logo.png', fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Operations',
                        style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text('AI Business Agent',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: AppColors.textMuted)),
                  ]),
                  const Spacer(),
                  _statusChip('ONLINE', AppColors.success, AppColors.successLight),
                ]),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Input mode toggle ────────────────────────────────────
                  _SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Input Type',
                            style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSub)),
                        const SizedBox(height: 10),
                        Row(children: [
                          _ModeChip(
                            label: '📝  Text / URL',
                            selected: _inputMode == 0,
                            onTap: () => setState(() { _inputMode = 0; _selectedFileName = null; }),
                          ),
                          const SizedBox(width: 10),
                          _ModeChip(
                            label: '📄  PDF Document',
                            selected: _inputMode == 1,
                            onTap: () => setState(() => _inputMode = 1),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        const Divider(height: 1, color: AppColors.border),
                        const SizedBox(height: 16),

                        // ── Text input or PDF picker ──────────────────────
                        if (_inputMode == 0)
                          TextField(
                            controller: _textCtrl,
                            maxLines: 5,
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                                height: 1.6),
                            decoration: InputDecoration(
                              hintText:
                                  'Paste a business report, article URL, or incident description…',
                              hintStyle: GoogleFonts.inter(
                                  fontSize: 13, color: AppColors.textMuted),
                              filled: true,
                              fillColor: AppColors.cardAlt,
                              contentPadding: const EdgeInsets.all(14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: AppColors.border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide:
                                    const BorderSide(color: AppColors.border),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                    color: AppColors.primary, width: 1.5),
                              ),
                            ),
                          )
                        else
                          _pdfPicker(),

                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          _errorBadge(_error!),
                        ],
                        const SizedBox(height: 14),
                        _RunButton(loading: _loading, onTap: _loading ? null : _run),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Agent steps while loading ─────────────────────────
                  if (_loading) ...[
                    _SectionCard(
                      child: Column(children: [
                        _StepRow(label: 'IE-Agent — Insight Extraction',
                            icon: Icons.search_rounded, pulse: _pulse),
                        _divider(),
                        _StepRow(label: 'DA-Agent — Decision Making',
                            icon: Icons.psychology_rounded, pulse: _pulse),
                        _divider(),
                        _StepRow(label: 'ES-Agent — Execution Sim',
                            icon: Icons.bolt_rounded, pulse: _pulse),
                      ]),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ── Results ───────────────────────────────────────────
                  if (_result != null) ...[
                    _InsightCard(r: _result!),
                    const SizedBox(height: 10),
                    _ImpactCard(r: _result!),
                    const SizedBox(height: 10),
                    _ActionCard(r: _result!),
                    const SizedBox(height: 10),
                    _OutcomesCard(r: _result!),
                    const SizedBox(height: 16),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pdfPicker() {
    return GestureDetector(
      onTap: () async {
        FilePickerResult? result = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          withData: true, // Needed for web bytes
        );

        if (result != null) {
          setState(() {
            _selectedFile = result.files.first;
            _selectedFileName = _selectedFile!.name;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _selectedFileName != null
              ? AppColors.primaryLight
              : AppColors.cardAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _selectedFileName != null
                ? AppColors.primary.withOpacity(0.35)
                : AppColors.border,
          ),
        ),
        child: _selectedFileName != null
            ? Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded,
                      color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_selectedFileName!,
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary),
                          overflow: TextOverflow.ellipsis),
                      Text('Tap to change file',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _selectedFileName = null),
                  child: const Icon(Icons.close_rounded,
                      size: 18, color: AppColors.textMuted),
                ),
              ])
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),
                    Icon(Icons.upload_file_rounded,
                        size: 38, color: AppColors.textMuted),
                    const SizedBox(height: 10),
                    Text('Tap to select PDF',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSub)),
                    const SizedBox(height: 4),
                    Text('Business reports, financial docs, etc.',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: AppColors.textMuted)),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
      ),
    );
  }
}

// ── Shared UI pieces ─────────────────────────────────────────────────────────

Widget _statusChip(String label, Color fg, Color bg) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
      ]),
    );

Widget _divider() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 10),
    child: Divider(height: 1, color: AppColors.border));

Widget _errorBadge(String msg) => Container(
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

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3))
          ],
        ),
        child: child,
      );
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ModeChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryLight : AppColors.cardAlt,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Text(label,
              style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.primary : AppColors.textSub)),
        ),
      );
}

class _RunButton extends StatelessWidget {
  final bool loading;
  final VoidCallback? onTap;
  const _RunButton({required this.loading, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 48,
          decoration: BoxDecoration(
            gradient: onTap == null
                ? const LinearGradient(
                    colors: [Color(0xFFAEB3F0), Color(0xFFC4AEFA)])
                : const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryEnd]),
            borderRadius: BorderRadius.circular(12),
            boxShadow: onTap != null
                ? [
                    BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 14,
                        offset: const Offset(0, 5))
                  ]
                : [],
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text('⚡  Run Agentic Flow',
                    style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
          ),
        ),
      );
}

class _StepRow extends StatelessWidget {
  final String label;
  final IconData icon;
  final AnimationController pulse;
  const _StepRow({required this.label, required this.icon, required this.pulse});

  @override
  Widget build(BuildContext context) => Row(children: [
        AnimatedBuilder(
          animation: pulse,
          builder: (_, __) => Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06 + pulse.value * 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withOpacity(0.2 + pulse.value * 0.3),
              ),
            ),
            child: Icon(icon, size: 15, color: AppColors.primary),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSub,
                    fontWeight: FontWeight.w500))),
        SizedBox(
          width: 14, height: 14,
          child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: AppColors.primary.withOpacity(0.5)),
        ),
      ]);
}

// ── Result cards ──────────────────────────────────────────────────────────────

class _ResultCard extends StatelessWidget {
  final String title;
  final Color accent;
  final Color accentBg;
  final Widget content;
  const _ResultCard({
    required this.title,
    required this.accent,
    required this.accentBg,
    required this.content,
  });

  @override
  Widget build(BuildContext context) => Container(
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: accentBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(title,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accent,
                    letterSpacing: 0.2)),
          ),
          const SizedBox(height: 12),
          content,
        ]),
      );
}

class _InsightCard extends StatelessWidget {
  final Map<String, dynamic> r;
  const _InsightCard({required this.r});

  @override
  Widget build(BuildContext context) {
    final i = r['insight'] as Map<String, dynamic>?;
    return _ResultCard(
      title: '🧠  Insight',
      accent: AppColors.primary,
      accentBg: AppColors.primaryLight,
      content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(i?['anomaly'] ?? 'N/A',
            style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.textPrimary, height: 1.55)),
        if (i?['primary_cause'] != null) ...[
          const SizedBox(height: 8),
          Text('Cause: ${i!['primary_cause']}',
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.textMuted, height: 1.4)),
        ],
      ]),
    );
  }
}

class _ImpactCard extends StatelessWidget {
  final Map<String, dynamic> r;
  const _ImpactCard({required this.r});

  @override
  Widget build(BuildContext context) {
    final imp = r['impact'] as Map<String, dynamic>?;
    final sev = imp?['severity'] as String?;
    Color sevColor = AppColors.success;
    Color sevBg    = AppColors.successLight;
    if (sev == 'CRITICAL') { sevColor = AppColors.danger;  sevBg = AppColors.dangerLight; }
    else if (sev == 'HIGH')   { sevColor = const Color(0xFFF97316); sevBg = const Color(0xFFFFF7ED); }
    else if (sev == 'MEDIUM') { sevColor = AppColors.warning; sevBg = AppColors.warningLight; }

    return _ResultCard(
      title: '💥  Impact',
      accent: const Color(0xFFF97316),
      accentBg: const Color(0xFFFFF7ED),
      content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (sev != null)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: sevBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: sevColor.withOpacity(0.3)),
            ),
            child: Text('Severity: $sev',
                style: GoogleFonts.inter(
                    fontSize: 11, fontWeight: FontWeight.w700, color: sevColor)),
          ),
        Text(imp?['strategic_implication'] ?? 'N/A',
            style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.textPrimary, height: 1.55)),
        if (imp?['financial_risk_estimate'] != null) ...[
          const SizedBox(height: 8),
          Text(imp!['financial_risk_estimate'],
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.textMuted)),
        ],
      ]),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final Map<String, dynamic> r;
  const _ActionCard({required this.r});

  @override
  Widget build(BuildContext context) {
    final a = r['recommended_action'] as Map<String, dynamic>?;
    return _ResultCard(
      title: '🎯  Action',
      accent: AppColors.success,
      accentBg: AppColors.successLight,
      content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(a?['action_title'] ?? a?['action_type'] ?? 'N/A',
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 6),
        Text(a?['decision_reasoning'] ?? 'N/A',
            style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSub,
                height: 1.5,
                fontStyle: FontStyle.italic)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.cardAlt,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
          ),
          child: Text('TYPE: ${a?['action_type'] ?? 'N/A'}',
              style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                  letterSpacing: 0.5)),
        ),
      ]),
    );
  }
}

class _OutcomesCard extends StatelessWidget {
  final Map<String, dynamic> r;
  const _OutcomesCard({required this.r});

  @override
  Widget build(BuildContext context) {
    final a = r['recommended_action'] as Map<String, dynamic>?;
    final outcomes = (a?['projected_outcomes'] as List<dynamic>?) ?? [];
    if (outcomes.isEmpty) return const SizedBox.shrink();

    return _ResultCard(
      title: '🔮  AI Simulation Forecast',
      accent: AppColors.primaryEnd,
      accentBg: AppColors.primaryLight,
      content: Column(
        children: outcomes.map((o) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(children: [
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(o['metric'] ?? '',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSub)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text(o['before_state'] ?? '',
                        style: GoogleFonts.inter(
                            fontSize: 12, color: AppColors.textMuted)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.arrow_forward_rounded,
                          size: 13, color: AppColors.textMuted),
                    ),
                    Text(o['after_state'] ?? '',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ]),
                ]),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }
}
