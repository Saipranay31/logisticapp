import 'package:flutter/material.dart';
import '../services/api_service.dart';

class BatchOperationsScreen extends StatefulWidget {
  const BatchOperationsScreen({super.key});
  @override
  State<BatchOperationsScreen> createState() => _BatchOperationsScreenState();
}

class _BatchOperationsScreenState extends State<BatchOperationsScreen> {
  // ── Palette ───────────────────────────────────────────────────────────────
  static const Color _bg      = Color(0xFFF7F8FA);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _primary = Color(0xFF1A1A2E);
  static const Color _accent  = Color(0xFF0066FF);
  static const Color _border  = Color(0xFFE8ECF0);
  static const Color _textPri = Color(0xFF0D0D0D);
  static const Color _textSec = Color(0xFF8A94A6);
  static const Color _green   = Color(0xFF00C48C);
  static const Color _red     = Color(0xFFFF3B30);

  String _result  = '';
  bool   _isError = false;
  bool   _sending = false;

  final _notifTitleCtrl = TextEditingController();
  final _notifMsgCtrl   = TextEditingController();
  String _audience = 'all_users';

  @override
  void dispose() {
    _notifTitleCtrl.dispose();
    _notifMsgCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendBroadcast() async {
    if (_notifTitleCtrl.text.isEmpty || _notifMsgCtrl.text.isEmpty) return;
    setState(() { _sending = true; _result = ''; });
    try {
      final r    = await ApiService.batchSendNotification(_audience, _notifTitleCtrl.text, _notifMsgCtrl.text);
      final data = r['data'] ?? {};
      setState(() {
        _result  = 'Broadcast sent — ${data['sent']} delivered, ${data['failed']} failed';
        _isError = false;
      });
    } catch (e) {
      setState(() { _result = 'Error: $e'; _isError = true; });
    } finally {
      setState(() => _sending = false);
    }
  }

  Future<void> _export(String type) async {
    try {
      final r = await ApiService.exportData(type);
      setState(() {
        _result  = 'Exported ${r['data']?['count'] ?? 0} ${type}s successfully';
        _isError = false;
      });
    } catch (e) {
      setState(() { _result = 'Error: $e'; _isError = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('Broadcast Notification', Icons.campaign_rounded, _accent),
            const SizedBox(height: 14),
            _broadcastCard(),
            const SizedBox(height: 28),
            _sectionLabel('Export Data', Icons.download_rounded, _green),
            const SizedBox(height: 14),
            _exportCard(),
            if (_result.isNotEmpty) ...[
              const SizedBox(height: 20),
              _resultBanner(),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
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
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _primary, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Batch Operations',
        style: TextStyle(
          color: _textPri,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BROADCAST CARD
  // ══════════════════════════════════════════════════════════════════════════
  Widget _broadcastCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('Audience'),
          const SizedBox(height: 6),
          _styledDropdown(),
          const SizedBox(height: 16),
          _fieldLabel('Notification Title'),
          const SizedBox(height: 6),
          _styledTextField(controller: _notifTitleCtrl, hint: 'e.g. Service Update', maxLines: 1),
          const SizedBox(height: 16),
          _fieldLabel('Message'),
          const SizedBox(height: 6),
          _styledTextField(controller: _notifMsgCtrl, hint: 'Write your broadcast message here…', maxLines: 4),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _sending ? null : _sendBroadcast,
              icon: _sending
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(
                _sending ? 'Sending…' : 'Send Broadcast',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _accent.withOpacity(0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // EXPORT CARD
  // ══════════════════════════════════════════════════════════════════════════
  Widget _exportCard() {
    const exports = [
      (Icons.directions_car_rounded, 'Drivers', 'drivers', Color(0xFF0066FF)),
      (Icons.people_rounded,         'Users',   'users',   Color(0xFF00C48C)),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Download a CSV snapshot of your platform data.',
            style: TextStyle(color: _textSec, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: exports.asMap().entries.map((e) {
              final isLast = e.key == exports.length - 1;
              final item   = e.value;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: isLast ? 0 : 12),
                  child: OutlinedButton(
                    onPressed: () => _export(item.$3),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: item.$4,
                      side: BorderSide(color: item.$4.withOpacity(0.25)),
                      backgroundColor: item.$4.withOpacity(0.05),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Column(
                      children: [
                        Icon(item.$1, size: 22, color: item.$4),
                        const SizedBox(height: 6),
                        Text(
                          item.$2,
                          style: TextStyle(color: item.$4, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text('Export CSV', style: TextStyle(color: item.$4.withOpacity(0.5), fontSize: 10)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // RESULT BANNER
  // ══════════════════════════════════════════════════════════════════════════
  Widget _resultBanner() {
    final color = _isError ? _red : _green;
    final icon  = _isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(_result, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w500))),
          GestureDetector(
            onTap: () => setState(() => _result = ''),
            child: Icon(Icons.close_rounded, color: color.withOpacity(0.5), size: 16),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════════════════
  Widget _sectionLabel(String text, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(color: _textPri, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.2),
        ),
      ],
    );
  }

  Widget _fieldLabel(String text) => Text(
    text,
    style: const TextStyle(color: _textPri, fontSize: 12.5, fontWeight: FontWeight.w600),
  );

  Widget _styledDropdown() {
    return Container(
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _audience,
          isExpanded: true,
          dropdownColor: _surface,
          style: const TextStyle(color: _textPri, fontSize: 13.5),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _textSec),
          items: const [
            DropdownMenuItem(value: 'all_users',   child: Text('All Users')),
            DropdownMenuItem(value: 'all_drivers', child: Text('All Drivers')),
            DropdownMenuItem(value: 'all',         child: Text('Everyone')),
          ],
          onChanged: (v) => setState(() => _audience = v!),
        ),
      ),
    );
  }

  Widget _styledTextField({required TextEditingController controller, required String hint, int maxLines = 1}) {
    return Container(
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: _textPri, fontSize: 13.5),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _textSec, fontSize: 13.5),
          filled: true,
          fillColor: Colors.white,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}