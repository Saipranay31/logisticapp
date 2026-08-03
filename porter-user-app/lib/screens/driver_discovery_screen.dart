import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/ride_provider.dart';
import '../services/api_service.dart';

class DriverDiscoveryScreen extends StatefulWidget {
  final String vehicleType;
  final double pickupLatitude;
  final double pickupLongitude;
  final String pickupAddress;
  final String dropAddress;

  const DriverDiscoveryScreen({
    super.key,
    required this.vehicleType,
    required this.pickupLatitude,
    required this.pickupLongitude,
    required this.pickupAddress,
    required this.dropAddress,
  });

  @override
  State<DriverDiscoveryScreen> createState() => _DriverDiscoveryScreenState();
}

class _DriverDiscoveryScreenState extends State<DriverDiscoveryScreen> {
  static const primary = Color(0xFF6C63FF);
  static const bg = Color(0xFF0A0E21);
  static const surface = Color(0xFF1D1E33);

  late GoogleMapController _mapController;
  final Set<Marker> _markers = {};
  List<Map<String, dynamic>> _drivers = [];
  bool _isLoading = true;
  String _sortBy = 'rating'; // rating, distance, eta
  String? _selectedDriverId;

  @override
  void initState() {
    super.initState();
    _loadNearbyDrivers();
  }

  Future<void> _loadNearbyDrivers() async {
    try {
      setState(() => _isLoading = true);

      // Fetch nearby drivers from backend
      final response = await ApiService.getNearbyDrivers(
        latitude: widget.pickupLatitude,
        longitude: widget.pickupLongitude,
        vehicleType: widget.vehicleType,
        radius: 5.0,
      );

      if (mounted) {
        setState(() {
          _drivers = response is List
              ? List<Map<String, dynamic>>.from(response)
              : [];
          _isLoading = false;
          _updateMapMarkers();
        });
      }
    } catch (e) {
      print('❌ Failed to load drivers: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load drivers: $e'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _updateMapMarkers() {
    _markers.clear();

    // Pickup location marker
    _markers.add(
      Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(widget.pickupLatitude, widget.pickupLongitude),
        infoWindow: const InfoWindow(title: '📍 Your Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    );

    // Driver markers
    for (final driver in _drivers) {
      final isSelected = driver['id'] == _selectedDriverId;
      _markers.add(
        Marker(
          markerId: MarkerId(driver['id']),
          position: LatLng(driver['latitude'] ?? 0, driver['longitude'] ?? 0),
          infoWindow: InfoWindow(
            title: driver['name'] ?? 'Driver',
            snippet: '⭐ ${driver['rating'] ?? 'N/A'}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isSelected ? BitmapDescriptor.hueBlue : BitmapDescriptor.hueOrange,
          ),
        ),
      );
    }

    setState(() {});
  }

  void _selectDriver(Map<String, dynamic> driver) {
    setState(() => _selectedDriverId = driver['id']);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ ${driver['name']} selected'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _proceedWithBooking() async {
    if (_selectedDriverId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a driver'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Pass selected driver ID to booking
    Navigator.pushReplacementNamed(context, '/booking', arguments: {
      'pickupAddress': widget.pickupAddress,
      'dropAddress': widget.dropAddress,
      'vehicleType': widget.vehicleType,
      'pickupLatitude': widget.pickupLatitude,
      'pickupLongitude': widget.pickupLongitude,
      'preferredDriverId': _selectedDriverId,
    });
  }

  @override
  Widget build(BuildContext context) {
    final sortedDrivers = _getSortedDrivers();

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text(
          'Available Drivers',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primary))
          : _drivers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.directions_car_filled, color: Colors.white.withOpacity(0.2), size: 64),
                      const SizedBox(height: 16),
                      Text(
                        'No drivers available',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadNearbyDrivers,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Map
                    Expanded(
                      flex: 2,
                      child: GoogleMap(
                        onMapCreated: (controller) => _mapController = controller,
                        initialCameraPosition: CameraPosition(
                          target: LatLng(widget.pickupLatitude, widget.pickupLongitude),
                          zoom: 14.5,
                        ),
                        markers: _markers,
                        myLocationButtonEnabled: true,
                        zoomControlsEnabled: true,
                        style: _darkMapStyle(),
                      ),
                    ),
                    // Sort options
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: surface, border: Border(bottom: BorderSide(color: Colors.white12))),
                      child: Row(
                        children: [
                          const Text('Sort by:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: ['rating', 'distance', 'eta'].map((sort) {
                                  final isSelected = _sortBy == sort;
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: FilterChip(
                                      label: Text(
                                        sort.toUpperCase(),
                                        style: TextStyle(
                                          color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                          fontSize: 12,
                                        ),
                                      ),
                                      backgroundColor: isSelected ? primary : Colors.white12,
                                      onSelected: (selected) => setState(() => _sortBy = sort),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Driver list
                    Expanded(
                      flex: 2,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: sortedDrivers.length,
                        itemBuilder: (context, index) {
                          final driver = sortedDrivers[index];
                          final isSelected = driver['id'] == _selectedDriverId;

                          return GestureDetector(
                            onTap: () => _selectDriver(driver),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isSelected ? primary.withOpacity(0.2) : surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? primary : Colors.white12,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: primary.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.person, color: primary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          driver['name'] ?? 'Driver',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            const Icon(Icons.star, color: Colors.amber, size: 14),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${driver['rating']?.toStringAsFixed(1) ?? 'N/A'}',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.6),
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              '${driver['totalRides'] ?? 0} rides',
                                              style: TextStyle(
                                                color: Colors.white.withOpacity(0.6),
                                                fontSize: 12,
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
                                        '${(driver['distance'] ?? 0).toStringAsFixed(1)} km',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.7),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${(driver['eta'] ?? 0).toStringAsFixed(0)} min',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (isSelected)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Icon(Icons.check_circle, color: primary, size: 24),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Proceed button
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: surface, border: Border(top: BorderSide(color: Colors.white12))),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_selectedDriverId != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: primary),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: primary, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Driver selected: ${_drivers.firstWhere((d) => d['id'] == _selectedDriverId)['name'] ?? 'Driver'}',
                                        style: const TextStyle(color: primary, fontWeight: FontWeight.w600, fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: _proceedWithBooking,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text(
                                'Continue to Booking',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  List<Map<String, dynamic>> _getSortedDrivers() {
    final sorted = List<Map<String, dynamic>>.from(_drivers);
    switch (_sortBy) {
      case 'rating':
        sorted.sort((a, b) => (b['rating'] ?? 0).compareTo(a['rating'] ?? 0));
        break;
      case 'distance':
        sorted.sort((a, b) => (a['distance'] ?? double.infinity).compareTo(b['distance'] ?? double.infinity));
        break;
      case 'eta':
        sorted.sort((a, b) => (a['eta'] ?? double.infinity).compareTo(b['eta'] ?? double.infinity));
        break;
    }
    return sorted;
  }

  String _darkMapStyle() => '''
    [
      {"elementType": "geometry", "stylers": [{"color": "#242f3e"}]},
      {"elementType": "labels.text.stroke", "stylers": [{"color": "#242f3e"}]},
      {"elementType": "labels.text.fill", "stylers": [{"color": "#746855"}]},
      {"featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [{"color": "#d59563"}]},
      {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#38414e"}]},
      {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#9ca5b3"}]},
      {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#17263c"}]}
    ]
  ''';
}
