import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../services/geocoding_service.dart';
import '../services/places_service.dart';

class MapPickerScreen extends StatefulWidget {
  final String title;
  final double? initialLat;
  final double? initialLng;

  const MapPickerScreen({
    super.key,
    required this.title,
    this.initialLat,
    this.initialLng,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen>
    with SingleTickerProviderStateMixin {
  // ── Colors ─────────────────────────────────────────────────────────────────
  static const Color _black = Color(0xFF0A0A0A);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _surface = Color(0xFFF7F7F7);
  static const Color _green = Color(0xFF00C853);
  static const Color _primaryText = Color(0xFF1A1A1A);
  static const Color _hint = Color(0xFF9E9E9E);
  static const Color _divider = Color(0xFFEEEEEE);

  // ── Map style (Uber-style light/standard) ─────────────────────────────────
  // Using the default Google Maps style (light) — no custom JSON needed.
  // Set map type to normal for clean Uber-style appearance.

  late GoogleMapController _mapController;
  LatLng? _selectedLocation;
  final Set<Marker> _markers = {};
  bool _mapLoaded = false;
  bool _gettingLocation = false;
  String _selectedAddress = 'Tap on map to select';
  bool _geocodingAddress = false;

  // ── Search ─────────────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final List<PlacePrediction> _predictions = [];
  bool _showPredictions = false;
  bool _searching = false;
  late String _sessionToken;
  bool _selectingFromSearch = false;
  bool _searchActive = false;

  // ── Bottom sheet animation ─────────────────────────────────────────────────
  late AnimationController _sheetController;
  late Animation<Offset> _sheetAnim;

  @override
  void initState() {
    super.initState();
    _selectedLocation = LatLng(
      widget.initialLat ?? 28.6139,
      widget.initialLng ?? 77.2090,
    );
    _updateMarker();
    _sessionToken = const Uuid().v4();
    print('🎟️ Generated Places session token: $_sessionToken');

    _sheetController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420),
    );
    _sheetAnim = Tween<Offset>(
      begin: const Offset(0, 0.1), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _sheetController, curve: Curves.easeOutCubic));
    _sheetController.forward();

    _searchFocus.addListener(() {
      setState(() => _searchActive = _searchFocus.hasFocus);
    });
  }

  // ── Original logic (UNCHANGED) ─────────────────────────────────────────────
  Future<void> _updateMarker() async {
    _markers.clear();
    if (_selectedLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('selected'),
          position: _selectedLocation!,
          infoWindow: const InfoWindow(title: 'Selected Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );

      setState(() => _geocodingAddress = true);
      try {
        final address = await GeocodingService.getAddressFromCoordinates(
          _selectedLocation!.latitude,
          _selectedLocation!.longitude,
        );
        if (mounted) {
          setState(() {
            _selectedAddress = address;
            _geocodingAddress = false;
          });
        }
      } catch (e) {
        print('Error geocoding: $e');
        if (mounted) setState(() => _geocodingAddress = false);
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _gettingLocation = true);
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      );
      final newLocation = LatLng(position.latitude, position.longitude);
      setState(() {
        _selectedLocation = newLocation;
        _updateMarker();
      });
      if (_mapLoaded) {
        _mapController.animateCamera(CameraUpdate.newLatLng(newLocation));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    } finally {
      setState(() => _gettingLocation = false);
    }
  }

  Future<void> _searchLocations(String query) async {
    if (query.isEmpty) {
      setState(() { _predictions.clear(); _showPredictions = false; });
      return;
    }
    setState(() => _searching = true);
    try {
      print('🔍 Searching locations: "$query"');
      final results = await PlacesService.getPlacePredictions(query, _sessionToken);
      print('✅ Got ${results.length} predictions for "$query"');
      if (mounted) {
        setState(() {
          _predictions.clear();
          _predictions.addAll(results);
          _showPredictions = results.isNotEmpty;
        });
      }
    } catch (e) {
      print('❌ Search error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Search error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _selectPlace(PlacePrediction prediction) async {
    setState(() => _selectingFromSearch = true);
    _searchFocus.unfocus();
    try {
      final details = await PlacesService.getPlaceDetails(prediction.placeId, _sessionToken);
      if (details != null && mounted) {
        final newLocation = LatLng(details['latitude'] as double, details['longitude'] as double);
        setState(() {
          _selectedLocation = newLocation;
          _selectedAddress = details['address'] as String;
          _searchController.clear();
          _showPredictions = false;
          _predictions.clear();
        });
        if (_mapLoaded) {
          _mapController.animateCamera(
            CameraUpdate.newLatLngZoom(newLocation, 16),
          );
        }
        await _updateMarker();
        print('✅ Selected place: ${details['address']}');
      }
    } catch (e) {
      print('❌ Error selecting place: $e');
    } finally {
      if (mounted) setState(() => _selectingFromSearch = false);
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  // ── UI ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _white,
        body: Stack(
          children: [
            // ── Google Map (light / standard style) ───────────────────────────
            SizedBox.expand(
              child: GoogleMap(
                onMapCreated: (controller) {
                  print('✅ GoogleMap created successfully');
                  _mapController = controller;
                  setState(() => _mapLoaded = true);
                  _mapController.animateCamera(
                    CameraUpdate.newLatLngZoom(_selectedLocation!, 15),
                  );
                },
                onCameraMove: (position) {
                  print('📍 Camera moved to: ${position.target}');
                },
                onCameraIdle: () {
                  print('📍 Camera idle');
                },
                initialCameraPosition: CameraPosition(
                  target: _selectedLocation!, zoom: 15,
                ),
                mapType: MapType.normal,
                markers: _markers,
                onTap: (LatLng latLng) async {
                  setState(() => _selectedLocation = latLng);
                  await _updateMarker();
                  _searchFocus.unfocus();
                },
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                buildingsEnabled: true,
                trafficEnabled: false,
                compassEnabled: false,
              ),
            ),

            // ── Top overlay (back + search) ────────────────────────────────────
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Back button + search bar row
                      Row(
                        children: [
                          // Back button
                          _buildCircleButton(
                            icon: Icons.arrow_back_rounded,
                            onTap: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 10),
                          // Search bar
                          Expanded(child: _buildSearchBar()),
                        ],
                      ),
                      // Predictions dropdown
                      if (_showPredictions && _predictions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildPredictionsList(),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // ── My location button ─────────────────────────────────────────────
            Positioned(
              bottom: 160, right: 16,
              child: _buildCircleButton(
                icon: Icons.my_location_rounded,
                onTap: (_gettingLocation || _selectingFromSearch)
                    ? null
                    : _getCurrentLocation,
                loading: _gettingLocation,
                large: true,
              ),
            ),

            // ── Bottom address + confirm sheet ─────────────────────────────────
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: SlideTransition(
                position: _sheetAnim,
                child: _buildBottomSheet(),
              ),
            ),
          ],
        ),
      ),
    );
  }
//search bar in the map picker
  Widget _buildSearchBar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 50,
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_searchActive ? 0.14 : 0.08),
            blurRadius: _searchActive ? 20 : 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      //search bar text color
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        onChanged: _searchLocations,

        style: const TextStyle(
          color: _primaryText, fontSize: 14, fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          filled: true,
          fillColor: _white,
          hintText: 'Search for a location…',
          hintStyle: const TextStyle(color: _hint, fontSize: 14, fontWeight: FontWeight.w400),
          prefixIcon: _searching
              ? const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _hint),
                  ),
                )
              : const Icon(Icons.search_rounded, color: _hint, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, color: _hint, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() { _predictions.clear(); _showPredictions = false; });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildPredictionsList() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20, offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: _predictions.length,
          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF0F0F0)),
          itemBuilder: (context, index) {
            final prediction = _predictions[index];
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _selectPlace(prediction),
                splashColor: _surface,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: _surface, borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.location_on_rounded,
                            color: _black, size: 16),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              prediction.mainText,
                              style: const TextStyle(
                                color: _primaryText, fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              prediction.secondaryText,
                              style: const TextStyle(color: _hint, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBottomSheet() {
    return Container(
      decoration: const BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 30, offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDDDDD),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Selected location pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _divider, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: _black, borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.place_rounded, color: _white, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _geocodingAddress
                          ? Row(
                              children: const [
                                SizedBox(
                                  width: 14, height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2, color: _hint,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Getting address…',
                                  style: TextStyle(color: _hint, fontSize: 13),
                                ),
                              ],
                            )
                          : Text(
                              _selectedAddress,
                              style: const TextStyle(
                                color: _primaryText,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Confirm button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _black,
                    foregroundColor: _white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _selectedLocation != null
                      ? () {
                          Navigator.pop(context, {
                            'latitude': _selectedLocation!.latitude,
                            'longitude': _selectedLocation!.longitude,
                            'address': _selectedAddress,
                          });
                        }
                      : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.check_circle_outline_rounded, size: 18, color: _white),
                      SizedBox(width: 8),
                      Text(
                        'Confirm Location',
                        style: TextStyle(
                          color: _white,
                          fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    VoidCallback? onTap,
    bool loading = false,
    bool large = false,
  }) {
    final size = large ? 52.0 : 44.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: _white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12, offset: const Offset(0, 3),
            ),
          ],
        ),
        child: loading
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: CircularProgressIndicator(strokeWidth: 2, color: _black),
              )
            : Icon(icon, color: _black, size: large ? 22 : 20),
      ),
    );
  }
}