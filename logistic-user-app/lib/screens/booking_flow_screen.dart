import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'dart:math' as Math;
import '../providers/ride_provider.dart';
import '../services/api_service.dart';
import 'map_picker_screen.dart';
import '../widgets/navigation.dart';
class BookingFlowScreen extends StatefulWidget {
  const BookingFlowScreen({super.key});

  @override
  State<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends State<BookingFlowScreen>
    with TickerProviderStateMixin {
  // ── Brand Colors ──────────────────────────────────────────────────────────
  static const Color _black = Color(0xFF0A0A0A);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _surface = Color(0xFFF7F7F7);
  static const Color _accent = Color(0xFF1A1A2E);
  static const Color _green = Color(0xFF00C853);
  static const Color _red = Color(0xFFFF3B30);
  static const Color _card = Color(0xFFFFFFFF);
  static const Color _divider = Color(0xFFEEEEEE);
  static const Color _hint = Color(0xFF9E9E9E);
  static const Color _primaryText = Color(0xFF1A1A1A);
  static const Color _secondaryText = Color(0xFF757575);

  // ── State (unchanged from original) ───────────────────────────────────────
  double? _pickupLat, _pickupLng;
  double? _dropLat, _dropLng;
  String _pickupAddress = '';
  String _dropAddress = '';
  String _vehicleType = 'BIKE';
  bool _isLoading = false;
  double? _distance;
  double? _fare;
  List<Map<String, dynamic>> _nearbyDrivers = [];
  bool _showingDrivers = false;
  
  double _baseFare = 50.0;
  double _perKmRate = 12.0;
  double _perMinRate = 2.0;
  Map<String, double> _vehicleMultipliers = {
    'BIKE': 1.0, 'AUTO': 1.5, 'MINI_TRUCK': 2.5, 'TRUCK': 4.0,
  };

  // ── Animation controllers ─────────────────────────────────────────────────
  late AnimationController _sheetController;
  late Animation<Offset> _sheetAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _sheetController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 480),
    );
    _sheetAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _sheetController, curve: Curves.easeOutCubic));

    _fadeController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 350),
    );
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _sheetController.forward();
    _fadeController.forward();

    _initializePickup();
    _loadFareConfiguration();
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  // ── Original logic (UNCHANGED) ─────────────────────────────────────────────
  Future<void> _loadFareConfiguration() async {
    try {
      final config = await ApiService.getFareConfig();
      setState(() {
        _baseFare = (config['baseFare'] as num?)?.toDouble() ?? 50.0;
        _perKmRate = (config['perKmRate'] as num?)?.toDouble() ?? 12.0;
        _perMinRate = (config['perMinRate'] as num?)?.toDouble() ?? 2.0;
        if (config['vehicleMultipliers'] is Map) {
          final m = config['vehicleMultipliers'] as Map;
          _vehicleMultipliers = {
            'BIKE': (m['BIKE'] as num?)?.toDouble() ?? 1.0,
            'AUTO': (m['AUTO'] as num?)?.toDouble() ?? 1.5,
            'MINI_TRUCK': (m['MINI_TRUCK'] as num?)?.toDouble() ?? 2.5,
            'TRUCK': (m['TRUCK'] as num?)?.toDouble() ?? 4.0,
          };
        }
      });
      print('✅ Fare configuration loaded: base=₹$_baseFare, km=₹$_perKmRate, min=₹$_perMinRate');
    } catch (e) {
      print('⚠️ Failed to load fare configuration, using defaults: $e');
    }
  }

  Future<void> _initializePickup() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      );
      setState(() {
        _pickupLat = pos.latitude;
        _pickupLng = pos.longitude;
      });
    } catch (e) {
      setState(() {
        _pickupLat = 17.3952;
        _pickupLng = 78.6095;
      });
    }
  }

  Future<void> _selectPickup() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          title: 'Select Pickup Location',
          initialLat: _pickupLat ?? 17.3952,
          initialLng: _pickupLng ?? 78.6095,
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _pickupLat = result['latitude'];
        _pickupLng = result['longitude'];
        _pickupAddress = result['address'] ?? 'Pickup Location';
        _distance = null;
        _fare = null;
      });
      print('✅ Pickup selected: $_pickupAddress');
    }
  }

  Future<void> _selectDrop() async {
    if (_pickupLat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select pickup location first')),
      );
      return;
    }
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          title: 'Select Drop Location',
          initialLat: _dropLat ?? (_pickupLat! + 0.025),
          initialLng: _dropLng ?? (_pickupLng! + 0.025),
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _dropLat = result['latitude'];
        _dropLng = result['longitude'];
        _dropAddress = result['address'] ?? 'Drop Location';
      });
      _calculateFare();
      print('✅ Drop selected: $_dropAddress');
    }
  }

  void _calculateFare() {
    if (_pickupLat == null || _dropLat == null) return;
    const R = 6371;
    final dLat = _toRadians(_dropLat! - _pickupLat!);
    final dLng = _toRadians(_dropLng! - _pickupLng!);
    final a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(_toRadians(_pickupLat!)) *
            Math.cos(_toRadians(_dropLat!)) *
            Math.sin(dLng / 2) *
            Math.sin(dLng / 2);
    final c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    final distance = R * c;
    final vehicleMultiplier = _vehicleMultipliers[_vehicleType] ?? 1.0;
    final baseFareAmount = _baseFare * vehicleMultiplier;
    final distanceCharge = distance * _perKmRate * vehicleMultiplier;
    final durationMin = (distance / 25 * 60).toInt();
    final durationCharge = durationMin * _perMinRate * vehicleMultiplier;
    final total = baseFareAmount + distanceCharge + durationCharge;
    setState(() {
      _distance = distance;
      _fare = total;
    });
    print('✅ Estimated fare: ${distance.toStringAsFixed(2)}km = ₹${total.toStringAsFixed(0)}');
  }

  double _toRadians(double degrees) => degrees * 3.141592653589793 / 180;

  Future<void> _bookRide() async {
    if (_pickupLat == null || _dropLat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select both pickup and drop locations')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final ride = Provider.of<RideProvider>(context, listen: false);
      final ok = await ride.createRide(
        _pickupAddress, _dropAddress, _vehicleType,
        pickupLatitude: _pickupLat!, pickupLongitude: _pickupLng!,
        dropLatitude: _dropLat!, dropLongitude: _dropLng!,
      );
      if (ok && mounted) {
        print('✅ Ride created successfully, navigating to tracking screen');
        Navigator.pushReplacementNamed(context, '/tracking', arguments: {
          'rideId': ride.currentRide?['id'],
          'pickupLat': _pickupLat!, 'pickupLng': _pickupLng!,
          'dropLat': _dropLat!, 'dropLng': _dropLng!,
          'pickupAddress': _pickupAddress, 'dropAddress': _dropAddress,
          'vehicleType': _vehicleType,
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ride.error ?? 'Failed to book ride')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchNearbyDrivers() async {
    try {
      final drivers = await ApiService.getNearbyDrivers(
        latitude: _pickupLat!, longitude: _pickupLng!,
        vehicleType: _vehicleType, radius: 10.0,
      );
      setState(() { _nearbyDrivers = drivers; _showingDrivers = true; });
      print('✅ Found ${drivers.length} nearby drivers');
      if (drivers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⏳ No drivers available now. Waiting for a driver...')),
        );
      }
    } catch (e) {
      print('❌ Error fetching drivers: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  String _getFareForVehicle(String type) {
    if (_distance == null || _pickupLat == null || _dropLat == null) {
      final mult = _vehicleMultipliers[type] ?? 1.0;
      return '₹${(_baseFare * mult).toStringAsFixed(0)}+';
    }
    final mult = _vehicleMultipliers[type] ?? 1.0;
    final base = _baseFare * mult;
    final dist = _distance! * _perKmRate * mult;
    final dur = (_distance! / 25 * 60).toInt() * _perMinRate * mult;
    return '₹${(base + dist + dur).toStringAsFixed(0)}';
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
   return Scaffold(
  backgroundColor: _surface,
  body: _showingDrivers ? _buildDriversList() : _buildBookingForm(),
  
);
  }

  Widget _buildBookingForm() {
    return Column(
      children: [
        // ── Top bar ──────────────────────────────────────────────────────────
        _buildTopBar(),

        Expanded(
          child: SlideTransition(
            position: _sheetAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    _buildLocationCard(),
                    const SizedBox(height: 20),
                    _buildVehicleSection(),
                    if (_distance != null && _fare != null) ...[
                      const SizedBox(height: 16),
                      _buildFareBanner(),
                    ],
                    const SizedBox(height: 24),
                    _buildBookButton(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      color: _white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12,
        left: 16,
        right: 8,
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context,'/home'),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: _black, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Book a Ride',
              style: TextStyle(
                color: _primaryText,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
          // Safety badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.verified_user_rounded, color: _green, size: 13),
                SizedBox(width: 4),
                Text('Safe', style: TextStyle(color: _green, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Pickup row ──────────────────────────────────────────────────────
          _buildLocationRow(
            icon: Icons.circle,
            iconColor: _green,
            iconSize: 12,
            label: 'Pickup',
            address: _pickupAddress.isNotEmpty ? _pickupAddress : 'Add pickup location',
            isEmpty: _pickupAddress.isEmpty,
            onTap: _selectPickup,
          ),
          // Dotted divider
          Padding(
            padding: const EdgeInsets.only(left: 52),
            child: _buildDottedLine(),
          ),
          // ── Drop row ────────────────────────────────────────────────────────
          _buildLocationRow(
            icon: Icons.location_on_rounded,
            iconColor: _red,
            iconSize: 20,
            label: 'Drop',
            address: _dropAddress.isNotEmpty ? _dropAddress : 'Add drop location',
            isEmpty: _dropAddress.isEmpty,
            onTap: _selectDrop,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required double iconSize,
    required String label,
    required String address,
    required bool isEmpty,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      splashColor: Colors.black.withOpacity(0.03),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Icon(icon, color: iconColor, size: iconSize),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: _hint,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    address,
                    style: TextStyle(
                      color: isEmpty ? _hint : _primaryText,
                      fontSize: 14,
                      fontWeight: isEmpty ? FontWeight.w400 : FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(
              isEmpty ? Icons.add_circle_outline_rounded : Icons.chevron_right_rounded,
              color: isEmpty ? _accent : _hint,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDottedLine() {
    return SizedBox(
      height: 16,
      child: CustomPaint(painter: _DottedLinePainter()),
    );
  }

  Widget _buildVehicleSection() {
    final vehicles = [
      {'type': 'BIKE', 'emoji': '🏍️', 'label': 'Bike', 'eta': '2 min'},
      {'type': 'AUTO', 'emoji': '🛺', 'label': 'Auto', 'eta': '4 min'},
      {'type': 'MINI_TRUCK', 'emoji': '🚛', 'label': 'Mini Truck', 'eta': '8 min'},
      {'type': 'TRUCK', 'emoji': '🚚', 'label': 'Truck', 'eta': '12 min'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Choose a ride',
              style: TextStyle(
                color: _primaryText,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
          ...vehicles.map((v) {
            final type = v['type']!;
            final isSelected = _vehicleType == type;
            return _buildVehicleRow(
              type: type,
              emoji: v['emoji']!,
              label: v['label']!,
              eta: v['eta']!,
              fare: _getFareForVehicle(type),
              isSelected: isSelected,
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildVehicleRow({
    required String type,
    required String emoji,
    required String label,
    required String eta,
    required String fare,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        setState(() => _vehicleType = type);
        _calculateFare();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? _black : _white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _black : _divider,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: _black.withOpacity(0.15), blurRadius: 12, offset: const Offset(0, 4))]
              : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? _white : _primaryText,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 11, color: isSelected ? Colors.white54 : _hint),
                      const SizedBox(width: 3),
                      Text(
                        eta,
                        style: TextStyle(
                          color: isSelected ? Colors.white54 : _hint,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  fare,
                  style: TextStyle(
                    color: isSelected ? _white : _primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (isSelected)
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Selected',
                      style: TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFareBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _black,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estimated Fare',
                  style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  '₹${_fare!.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: _white, fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 48, color: Colors.white12),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Distance',
                  style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_distance!.toStringAsFixed(1)} km',
                  style: const TextStyle(
                    color: _white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookButton() {
    final bothSelected = _pickupLat != null && _dropLat != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _bookRide,
          style: ElevatedButton.styleFrom(
            backgroundColor: bothSelected ? _black : Colors.grey.shade300,
            foregroundColor: _white,
            elevation: bothSelected ? 4 : 0,
            shadowColor: _black.withOpacity(0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(color: _white, strokeWidth: 2.5),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      bothSelected ? 'Confirm Booking' : 'Select Locations',
                      style: TextStyle(
                        color: bothSelected ? _white : Colors.grey.shade600,
                        fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2,
                      ),
                    ),
                    if (bothSelected) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18, color: _white),
                    ],
                  ],
                ),
        ),
      ),
    );
  }

  // ── Drivers List ───────────────────────────────────────────────────────────
  Widget _buildDriversList() {
    return Column(
      children: [
        Container(
          color: _white,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            bottom: 12, left: 16, right: 8,
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _showingDrivers = false),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _surface, borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, color: _black, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Nearby Drivers',
                  style: TextStyle(
                    color: _primaryText, fontSize: 20,
                    fontWeight: FontWeight.w800, letterSpacing: -0.5,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_nearbyDrivers.length} found',
                  style: const TextStyle(
                    color: Colors.blue, fontSize: 12, fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        Expanded(
          child: _nearbyDrivers.isEmpty
              ? _buildNoDrivers()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: _nearbyDrivers.length,
                  itemBuilder: (context, index) {
                    final driver = _nearbyDrivers[index];
                    return _buildDriverCard(driver, index);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildNoDrivers() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: _surface, shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_search_rounded, size: 36, color: _hint),
          ),
          const SizedBox(height: 16),
          const Text(
            'Finding your driver…',
            style: TextStyle(color: _primaryText, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          const Text(
            'Please wait a moment',
            style: TextStyle(color: _hint, fontSize: 14),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: 28, height: 28,
            child: CircularProgressIndicator(
              color: _black, strokeWidth: 2.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCard(Map<String, dynamic> driver, int index) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 200 + index * 60),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10, offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: _surface, shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_rounded, size: 26, color: _black),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver['name'] ?? 'Driver',
                  style: const TextStyle(
                    color: _primaryText, fontSize: 15, fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, size: 13, color: Colors.amber),
                    const SizedBox(width: 3),
                    Text(
                      '${driver['rating'] ?? 5.0}  ·  ${driver['totalRides'] ?? 0} rides',
                      style: const TextStyle(color: _hint, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${driver['distance']?.toStringAsFixed(1)} km',
                  style: const TextStyle(
                    color: _green, fontSize: 13, fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                driver['vehicleNumber'] ?? 'N/A',
                style: const TextStyle(color: _hint, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Custom Painters ────────────────────────────────────────────────────────────
class _DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCCCCCC)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const dashH = 4.0;
    const gap = 3.0;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(0, y + dashH), paint);
      y += dashH + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}