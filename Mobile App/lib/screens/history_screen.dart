import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final user = FirebaseAuth.instance.currentUser;

  String _asDisplayString(dynamic value, {String fallback = 'N/A'}) {
    if (value == null) return fallback;
    if (value is String) return value.isEmpty ? fallback : value;
    if (value is Map) {
      final map = value;
      for (final key in [
        'anomaly',
        'action_title',
        'action_type',
        'strategic_implication',
        'primary_cause',
        'severity',
      ]) {
        final text = map[key]?.toString();
        if (text != null && text.isNotEmpty) return text;
      }
    }
    final text = value.toString();
    return text.isEmpty ? fallback : text;
  }

  String _severityLabel(dynamic value) {
    return _asDisplayString(value, fallback: 'LOW').toUpperCase();
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
              Text('Run History',
                  style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
            ]),
          ),
          // ── List ──────────────────────────────────────────────────────
          Expanded(
            child: user == null 
              ? const Center(child: Text("Please log in to view history"))
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(user!.uid)
                      .collection('history')
                      .orderBy('timestamp', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _emptyState();
                    }

                    final docs = snapshot.data!.docs;
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final doc = docs[i].data() as Map<String, dynamic>;
                        final timestamp = doc['timestamp'] as Timestamp?;
                        final dateStr = timestamp != null 
                            ? timestamp.toDate().toLocal().toString().substring(0, 16)
                            : 'Just now';
                        
                        final impact = doc['impact'];
                        final severity = doc['severity'] ??
                            (impact is Map ? impact['severity'] : null);

                        return _SessionTile(session: {
                          'id': docs[i].id.substring(0, 8).toUpperCase(),
                          'title': _asDisplayString(
                            doc['input'],
                            fallback: 'Analyzed Document',
                          ),
                          'insight': _asDisplayString(doc['insight']),
                          'severity': _severityLabel(severity),
                          'action': _asDisplayString(doc['action']),
                          'date': dateStr,
                        });
                      },
                    );
                  },
                ),
          ),
        ]),
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.history_rounded, size: 52, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text('No sessions yet',
              style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSub)),
          const SizedBox(height: 4),
          Text('Run your first analysis on the Operations tab.',
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.textMuted)),
        ]),
      );
}

class _SessionTile extends StatefulWidget {
  final Map<String, dynamic> session;
  const _SessionTile({required this.session});

  @override
  State<_SessionTile> createState() => _SessionTileState();
}

class _SessionTileState extends State<_SessionTile> {
  bool _expanded = false;

  Color _sevColor(String? s) {
    switch (s) {
      case 'CRITICAL': return AppColors.danger;
      case 'HIGH':     return const Color(0xFFF97316);
      case 'MEDIUM':   return AppColors.warning;
      default:         return AppColors.success;
    }
  }

  Color _sevBg(String? s) {
    switch (s) {
      case 'CRITICAL': return AppColors.dangerLight;
      case 'HIGH':     return const Color(0xFFFFF7ED);
      case 'MEDIUM':   return AppColors.warningLight;
      default:         return AppColors.successLight;
    }
  }

  Widget _buildTitle(String title) {
    final trimmed = title.trim();
    final lower = trimmed.toLowerCase();
    final isUrl = lower.startsWith('http://') || lower.startsWith('https://') || lower.startsWith('www.');
    
    if (isUrl) {
      return Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF), // Gorgeous light blue background
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFDBEAFE)), // Premium light-blue border
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.open_in_new_rounded,
              size: 13,
              color: Color(0xFF3B82F6), // Premium soft blue icon
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                trimmed,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2563EB), // Vibrant blue hyperlink color
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      );
    }
    
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final sev = s['severity'] as String?;
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: _expanded ? AppColors.primary.withOpacity(0.3) : AppColors.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              // Icon
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bolt_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildTitle(s['title'] ?? ''),
                  const SizedBox(height: 2),
                  Text(s['date'] ?? '',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.textMuted)),
                ]),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _sevBg(sev),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _sevColor(sev).withOpacity(0.3)),
                ),
                child: Text(sev ?? 'N/A',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _sevColor(sev))),
              ),
              const SizedBox(width: 6),
              Icon(
                _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                size: 18, color: AppColors.textMuted,
              ),
            ]),
          ),

          // Expanded detail
          if (_expanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 12),
                _detail('🧠 Insight', s['insight'] ?? 'N/A'),
                const SizedBox(height: 8),
                _detail('🎯 Action Executed', s['action'] ?? 'N/A'),
                const SizedBox(height: 8),
                Row(children: [
                  Text('Session ID: ',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: AppColors.textMuted)),
                  Text(s['id'] ?? '',
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSub,
                          fontFeatures: [const FontFeature.tabularFigures()])),
                ]),
              ]),
            ),
        ]),
      ),
    );
  }

  Widget _detail(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted)),
          const SizedBox(height: 3),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 12, color: AppColors.textSub, height: 1.45)),
        ],
      );
}
