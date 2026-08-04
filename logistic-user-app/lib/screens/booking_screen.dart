import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../providers/ride_provider.dart';
import '../services/api_service.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});
  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  static const primary = Color(0xFF6C63FF);
  static const bg = Color(0xFF0A0E21);
  static const surface = Color(0xFF1D1E33);
  String _paymentMethod = 'UPI';
  String? _promoCode;
  bool _isLoading = false;

  // Fare configuration loaded from backend
  double _baseFare = 50.0;
  double _perKmRate = 12.0;
  double _perMinRate = 2.0;

  @override
  void initState() {
    super.initState();
    _loadFareConfiguration();
  }

  /// Load fare configuration from backend
  Future<void> _loadFareConfiguration() async {
    try {
      final config = await ApiService.getFareConfig();
      if (mounted) {
        setState(() {
          _baseFare = (config['baseFare'] as num?)?.toDouble() ?? 50.0;
          _perKmRate = (config['perKmRate'] as num?)?.toDouble() ?? 12.0;
          _perMinRate = (config['perMinRate'] as num?)?.toDouble() ?? 2.0;
        });
        print('✅ Fare configuration loaded: base=₹$_baseFare, km=₹$_perKmRate, min=₹$_perMinRate');
      }
    } catch (e) {
      print('⚠️ Failed to load fare configuration, using defaults: $e');
    }
  }

  // 🔴 CRITICAL FIX: Helper to calculate distance between two coordinates
  double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusKm = 6371;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
            math.sin(dLng / 2) * math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
    final pickup = args['pickup'] ?? '';
    final drop = args['drop'] ?? '';
    final vehicleType = args['vehicleType'] ?? 'BIKE';

    // 🔴 CRITICAL FIX: Get actual coordinates
    final pickupLat = (args['pickupLatitude'] as num?)?.toDouble() ?? 28.6139;
    final pickupLng = (args['pickupLongitude'] as num?)?.toDouble() ?? 77.2090;
    // For drop, use a default or hardcoded offset for now (would be improved with map selection)
    final dropLat = (args['dropLatitude'] as num?)?.toDouble() ?? (pickupLat + 0.1);
    final dropLng = (args['dropLongitude'] as num?)?.toDouble() ?? (pickupLng + 0.1);

    // 🔴 CRITICAL FIX: Calculate ACTUAL distance
    final distance = _calculateDistance(pickupLat, pickupLng, dropLat, dropLng);
    final estimatedDuration = (distance / 25 * 60).toInt(); // Rough estimate: 25 km/h avg

    // Calculate fare based on ACTUAL distance, not hardcoded 5.2km
    final baseFareAmount = vehicleType == 'BIKE' ? _baseFare : vehicleType == 'AUTO' ? (_baseFare * 1.5) : vehicleType == 'MINI_TRUCK' ? (_baseFare * 2.5) : (_baseFare * 4.0);
    final distanceCharge = distance * _perKmRate;
    final durationCharge = estimatedDuration * _perMinRate;
    final handlingFee = (args['handling'] as List?)?.isNotEmpty == true ? 25.0 : 0.0;
    final subtotal = baseFareAmount + distanceCharge + durationCharge + handlingFee;
    final gst = subtotal * 0.05;
    final discount = _promoCode == 'FIRST50' ? subtotal * 0.5 : 0.0;
    final total = subtotal + gst - discount;

    print('💰 FARE CALCULATION:');
    print('  Pickup: $pickupLat, $pickupLng');
    print('  Drop: $dropLat, $dropLng');
    print('  Distance: ${distance.toStringAsFixed(2)} km');
    print('  Duration: $estimatedDuration min');
    print('  Base: ₹$baseFareAmount | Distance: ₹${distanceCharge.toStringAsFixed(2)} | Time: ₹${durationCharge.toStringAsFixed(2)}');
    print('  Total: ₹${total.toStringAsFixed(2)}');

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg, elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
        title: const Text('Fare Estimate', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Route summary - NOW WITH ACTUAL DISTANCE
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              Row(children: [
                Column(children: [
                  const Icon(Icons.radio_button_checked, size: 14, color: Color(0xFF00E676)),
                  Container(height: 24, width: 1, color: Colors.white12),
                  const Icon(Icons.location_on, size: 14, color: Colors.red),
                ]),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(pickup, style: const TextStyle(color: Colors.white, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 16),
                  Text(drop, style: const TextStyle(color: Colors.white, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                ])),
              ]),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _infoChip(Icons.straighten, '${distance.toStringAsFixed(1)} km'),
                _infoChip(Icons.timer, '~${estimatedDuration} min'),
                _infoChip(Icons.two_wheeler,
                    vehicleType == 'BIKE' ? 'Bike' : vehicleType == 'AUTO' ? 'Auto' : vehicleType == 'MINI_TRUCK' ? 'Mini Truck' : 'Truck'),
              ]),
            ]),
          ),
          const SizedBox(height: 20),

          // Fare breakdown - NOW WITH ACTUAL VALUES
          const Text('Fare Breakdown', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16)),
            child: Column(children: [
              _fareRow('Base Fare', baseFareAmount),
              _fareRow('Distance (${distance.toStringAsFixed(1)}km × ₹${_perKmRate.toStringAsFixed(0)}/km)', distanceCharge),
              _fareRow('Duration ($estimatedDuration min × ₹${_perMinRate.toStringAsFixed(0)}/min)', durationCharge),
              if (handlingFee > 0) _fareRow('Special Handling Fee', handlingFee),
              _fareRow('GST (5%)', gst),
              if (discount > 0) _fareRow('Promo Discount', -discount, color: const Color(0xFF00E676)),
              const Divider(color: Colors.white12, height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Total', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                Text('₹${total.toStringAsFixed(0)}', style: const TextStyle(color: primary, fontSize: 24, fontWeight: FontWeight.w800)),
              ]),
            ]),
          ),
          const SizedBox(height: 20),

          // Promo code
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Expanded(child: TextField(
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter promo code',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _promoCode = v),
              )),
              TextButton(
                onPressed: () => setState(() {}),
                child: const Text('Apply', style: TextStyle(color: primary, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          // Payment method
          const Text('Payment Method', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(children: [
            _paymentChip('UPI', Icons.account_balance),
            const SizedBox(width: 8),
            _paymentChip('Card', Icons.credit_card),
            const SizedBox(width: 8),
            _paymentChip('Cash', Icons.money),
            const SizedBox(width: 8),
            _paymentChip('Wallet', Icons.account_balance_wallet),
          ]),
          const SizedBox(height: 28),

          // Confirm button
          SizedBox(
            width: double.infinity, height: 56,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [primary, Color(0xFF8B83FF)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: primary.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : () async {
                  setState(() => _isLoading = true);
                  final ride = Provider.of<RideProvider>(context, listen: false);
                  final ok = await ride.createRide(
                    pickup, drop, vehicleType,
                    pickupLatitude: pickupLat,
                    pickupLongitude: pickupLng,
                    dropLatitude: dropLat,
                    dropLongitude: dropLng,
                  );
                  setState(() => _isLoading = false);
                  if (ok && mounted) {
                    Navigator.pushReplacementNamed(context, '/tracking');
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(ride.error ?? 'Failed to create ride')));
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                child: _isLoading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('Confirm & Pay ₹${total.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(children: [
      Icon(icon, color: Colors.white38, size: 14),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
    ]);
  }

  Widget _fareRow(String label, double amount, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13)),
        Text('${amount < 0 ? "-" : ""}₹${amount.abs().toStringAsFixed(0)}',
            style: TextStyle(color: color ?? Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _paymentChip(String method, IconData icon) {
    final selected = _paymentMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _paymentMethod = method),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? primary.withOpacity(0.15) : surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? primary : Colors.transparent),
          ),
          child: Column(children: [
            Icon(icon, color: selected ? primary : Colors.white38, size: 20),
            const SizedBox(height: 4),
            Text(method, style: TextStyle(color: selected ? primary : Colors.white54, fontSize: 10)),
          ]),
        ),
      ),
    );
  }
}
