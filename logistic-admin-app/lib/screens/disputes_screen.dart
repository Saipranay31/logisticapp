import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DisputesScreen extends StatefulWidget {
  const DisputesScreen({super.key});
  @override
  State<DisputesScreen> createState() => _DisputesScreenState();
}

class _DisputesScreenState extends State<DisputesScreen> {
  // ── Palette ──────────────────────────────────────────────────────────────
  static const Color _bg      = Color(0xFFF7F8FA);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _primary = Color(0xFF1A1A2E);
  static const Color _accent  = Color(0xFF0066FF);
  static const Color _border  = Color(0xFFE8ECF0);
  static const Color _textPri = Color(0xFF0D0D0D);
  static const Color _textSec = Color(0xFF8A94A6);
  static const Color _green   = Color(0xFF00C48C);
  static const Color _red     = Color(0xFFFF3B30);

  List<dynamic> _disputes = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService.getAllDisputes();
      setState(() => _disputes = r);
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // APP BAR
  // ══════════════════════════════════════════════════════════════════════════
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: _border),
      ),
      title: const Text(
        'Disputes',
        style: TextStyle(
          color: _textPri,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: _textSec),
          onPressed: _load,
          tooltip: 'Refresh',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BODY
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _accent, strokeWidth: 2));
    }

    if (_disputes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: _green.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.handshake_outlined, color: _green, size: 28),
            ),
            const SizedBox(height: 12),
            const Text('No disputes',
                style: TextStyle(color: _textPri, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('All clear — nothing to review',
                style: TextStyle(color: _textSec, fontSize: 13)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: _accent,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _disputes.length,
        itemBuilder: (_, i) => _disputeTile(_disputes[i] as Map<String, dynamic>),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DISPUTE TILE
  // ══════════════════════════════════════════════════════════════════════════
  Widget _disputeTile(Map<String, dynamic> d) {
    final status   = d['status'] ?? 'OPEN';
    final resolved = status == 'RESOLVED';
    final statusColor = resolved ? _green : _red;

    final rideRaw = (d['rideId'] ?? '').toString();
    final rideLabel = rideRaw.length > 8 ? '${rideRaw.substring(0, 8)}…' : rideRaw;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: status + ride id
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              if (rideLabel.isNotEmpty) ...[
                const Icon(Icons.route_rounded, color: _textSec, size: 12),
                const SizedBox(width: 4),
                Text(
                  'Ride: $rideLabel',
                  style: const TextStyle(color: _textSec, fontSize: 11),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Reason
          Text(
            d['reason'] ?? '',
            style: const TextStyle(
              color: _textPri,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),

          // Description
          Text(
            d['description'] ?? '',
            style: const TextStyle(color: _textSec, fontSize: 12, height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          if (!resolved) ...[
            const SizedBox(height: 12),
            const Divider(color: _border, height: 1),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton.icon(
                onPressed: () => _resolveDialog(d),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 16),
                label: const Text('Resolve Dispute', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _green,
                  side: BorderSide(color: _green.withOpacity(0.40)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RESOLVE DIALOG
  // ══════════════════════════════════════════════════════════════════════════
  void _resolveDialog(Map<String, dynamic> dispute) {
    final resCtrl    = TextEditingController();
    final refundCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: _green.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_circle_outline_rounded, color: _green, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Resolve Dispute',
                      style: TextStyle(
                        color: _textPri,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Resolution notes
              const Text('Resolution Notes',
                  style: TextStyle(color: _textPri, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: TextField(
                  controller: resCtrl,
                  style: const TextStyle(color: _textPri, fontSize: 14),
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Describe the resolution…',
                    hintStyle: TextStyle(color: _textSec, fontSize: 14),
                    filled: true,
                    fillColor: Colors.white,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(14),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Refund amount
              const Text('Refund Amount (optional)',
                  style: TextStyle(color: _textPri, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: TextField(
                  controller: refundCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: _textPri, fontSize: 14),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.currency_rupee_rounded, color: _textSec, size: 16),
                    hintText: '0.00',
                    hintStyle: TextStyle(color: _textSec, fontSize: 14),
                    filled: true,
                    fillColor: Colors.white,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _textSec,
                          side: const BorderSide(color: _border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final refund = double.tryParse(refundCtrl.text);
                          await ApiService.resolveDispute(
                            dispute['id'].toString(),
                            approve: true,
                            notes: resCtrl.text,
                            refundAmount: refund,
                          );
                          _load();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Resolve', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}