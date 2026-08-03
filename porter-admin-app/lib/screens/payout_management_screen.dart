import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PayoutManagementScreen extends StatelessWidget {
  const PayoutManagementScreen({super.key});

  static const Color _bg      = Color(0xFFF7F8FA);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _primary = Color(0xFF1A1A2E);
  static const Color _border  = Color(0xFFE8ECF0);
  static const Color _textPri = Color(0xFF0D0D0D);
  static const Color _textSec = Color(0xFF8A94A6);
  static const Color _green   = Color(0xFF00C48C);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
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
          'Payouts & Payments',
          style: TextStyle(color: _textPri, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(color: _green.withOpacity(0.10), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.account_balance_wallet_rounded, color: _green, size: 16),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Payment Retry Management',
                  style: TextStyle(color: _textPri, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.2),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter a payment ID to retry a failed payment or view its retry history.',
                    style: TextStyle(color: _textSec, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  const _PaymentRetryWidget(),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _PaymentRetryWidget extends StatefulWidget {
  const _PaymentRetryWidget();
  @override
  State<_PaymentRetryWidget> createState() => _PaymentRetryWidgetState();
}

class _PaymentRetryWidgetState extends State<_PaymentRetryWidget> {
  static const Color _bg      = Color(0xFFF7F8FA);
  static const Color _border  = Color(0xFFE8ECF0);
  static const Color _textPri = Color(0xFF0D0D0D);
  static const Color _textSec = Color(0xFF8A94A6);
  static const Color _accent  = Color(0xFF0066FF);
  static const Color _green   = Color(0xFF00C48C);
  static const Color _orange  = Color(0xFFFF8C42);
  static const Color _red     = Color(0xFFFF3B30);

  final _paymentIdCtrl = TextEditingController();
  String _result  = '';
  bool   _isError = false;

  @override
  void dispose() { _paymentIdCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Payment ID', style: TextStyle(color: _textPri, fontSize: 12.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
          child: TextField(
            controller: _paymentIdCtrl,
            style: const TextStyle(color: _textPri, fontSize: 13.5),
            decoration: const InputDecoration(
              hintText: 'e.g. pay_3Xk9A2mNqL',
              hintStyle: TextStyle(color: _textSec, fontSize: 13.5),
              prefixIcon: Icon(Icons.tag_rounded, color: _textSec, size: 18),
              filled: true,
              fillColor: Colors.white,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (_paymentIdCtrl.text.isEmpty) return;
                    try {
                      await ApiService.retryPayment(_paymentIdCtrl.text);
                      setState(() { _result = 'Retry initiated successfully'; _isError = false; });
                    } catch (e) { setState(() { _result = 'Error: $e'; _isError = true; }); }
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  label: const Text('Retry Payment', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orange, foregroundColor: Colors.white, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 46,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    if (_paymentIdCtrl.text.isEmpty) return;
                    try {
                      final r = await ApiService.getRetryHistory(_paymentIdCtrl.text);
                      final history = r['data'] ?? [];
                      setState(() { _result = 'Retry history: ${history.length} attempts'; _isError = false; });
                    } catch (e) { setState(() { _result = 'Error: $e'; _isError = true; }); }
                  },
                  icon: const Icon(Icons.history_rounded, size: 17),
                  label: const Text('View History', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _accent,
                    side: BorderSide(color: _accent.withOpacity(0.30)),
                    backgroundColor: _accent.withOpacity(0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_result.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (_isError ? _red : _green).withOpacity(0.07),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: (_isError ? _red : _green).withOpacity(0.20)),
            ),
            child: Row(
              children: [
                Icon(_isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                    color: _isError ? _red : _green, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_result,
                      style: TextStyle(color: _isError ? _red : _green, fontSize: 12.5, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}