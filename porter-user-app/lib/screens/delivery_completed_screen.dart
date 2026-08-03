import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DeliveryCompletedScreen extends StatefulWidget {
  const DeliveryCompletedScreen({super.key});
  @override
  State<DeliveryCompletedScreen> createState() => _DeliveryCompletedScreenState();
}

class _DeliveryCompletedScreenState extends State<DeliveryCompletedScreen> {
  static const primary = Color(0xFF6C63FF);
  static const bg = Color(0xFF0A0E21);
  static const surface = Color(0xFF1D1E33);
  int _rating = 0;
  String _condition = 'Perfect';
  final _reviewCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _reviewCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ride = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(backgroundColor: bg, elevation: 0,
        title: const Text('Delivery Complete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // ✅ Payment confirmed - show success badge
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF00E676), width: 1),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle, color: Color(0xFF00E676), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '✅ Payment Confirmed - ₹${(ride['actualFare'] ?? ride['estimatedFare'] ?? 0).toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Color(0xFF00E676),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // Success icon
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [const Color(0xFF00E676), const Color(0xFF00C853).withOpacity(0.6)]),
              boxShadow: [BoxShadow(color: const Color(0xFF00E676).withOpacity(0.3), blurRadius: 24)],
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 44),
          ),
          const SizedBox(height: 16),
          const Text('Delivery Successful!', style: TextStyle(color: Color(0xFF00E676), fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 24),

          // Summary card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Delivery Summary', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              _summaryRow('Order ID', ride['id']?.toString().substring(0, 8) ?? '—'),
              _summaryRow('Pickup', ride['pickupAddress'] ?? '—'),
              _summaryRow('Drop', ride['dropAddress'] ?? '—'),
              _summaryRow('Distance', '${ride['distance'] ?? '—'} km'),
              _summaryRow('Amount', '₹${(ride['actualFare'] ?? ride['estimatedFare'] ?? 0).toStringAsFixed(0)}'),
              _summaryRow('Driver', ride['driverName'] ?? '—'),
            ]),
          ),
          const SizedBox(height: 20),

          // ✅ Rating section - always show (payment already confirmed)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              const Text('Rate Your Driver', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) =>
                GestureDetector(
                  onTap: () => setState(() => _rating = i + 1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: i < _rating ? Colors.amber : Colors.white24, size: 40),
                  ),
                ),
              )),
              const SizedBox(height: 12),
              TextField(
                controller: _reviewCtrl,
                maxLength: 200, maxLines: 3,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Write a review (optional)',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  filled: true, fillColor: bg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  counterStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // Item condition
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Item Condition', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _conditionChip('Perfect', '✅'), _conditionChip('Slightly Damaged', '⚠️'),
                _conditionChip('Heavily Damaged', '❌'), _conditionChip('Missing', '🚫'),
              ]),
            ]),
          ),
          const SizedBox(height: 16),

          // Loyalty points
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [primary.withOpacity(0.1), primary.withOpacity(0.05)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: primary.withOpacity(0.2)),
            ),
            child: const Row(children: [
              Text('🎉', style: TextStyle(fontSize: 24)),
              SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('You earned 15 loyalty points!', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                Text('Keep delivering to earn more', style: TextStyle(color: Colors.white38, fontSize: 12)),
              ])),
            ]),
          ),
          const SizedBox(height: 20),

          // Submit Rating - ✅ Always enabled (payment already confirmed)
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : () async {
                if (_rating == 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('⭐ Please rate your driver')));
                  return;
                }
                setState(() => _isSubmitting = true);
                try {
                  if (ride['id'] != null) {
                    await ApiService.rateRide(ride['id'].toString(), _rating, review: _reviewCtrl.text);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Rating submitted successfully!'),
                          backgroundColor: Color(0xFF00E676),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❌ Error submitting rating: ${e.toString()}')),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() => _isSubmitting = false);
                    Future.delayed(const Duration(milliseconds: 500), () {
                      if (mounted) Navigator.pushReplacementNamed(context, '/home');
                    });
                  }
                }
              },
              icon: _isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.star_rounded, size: 20),
              label: Text(
                _isSubmitting ? 'Submitting...'
                : (_rating > 0 ? 'Submit Rating & Go Home' : 'Skip & Go Home'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Report Issue / Dispute
          SizedBox(
            width: double.infinity, height: 44,
            child: OutlinedButton.icon(
              onPressed: () => _showDisputeDialog(ride),
              icon: const Icon(Icons.flag_rounded, size: 18),
              label: const Text('Report an Issue', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E676),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: const Text('Skip & Go Home', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: TextStyle(color: Colors.white54, fontSize: 12)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))],
    ));
  }

  Widget _conditionChip(String label, String emoji) {
    return GestureDetector(
      onTap: () => setState(() => _condition = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _condition == label ? primary : surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _condition == label ? primary : Colors.white24),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(
            color: _condition == label ? Colors.white : Colors.white70,
            fontWeight: _condition == label ? FontWeight.w700 : FontWeight.w500,
          )),
        ]),
      ),
    );
  }

  void _showDisputeDialog(Map<String, dynamic> ride) {
    showDialog(context: context, builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1D1E33),
      title: const Text('Report Issue', style: TextStyle(color: Colors.white)),
      content: const Text('Select the reason for your dispute:', style: TextStyle(color: Colors.white70)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ],
    ));
  }
}
