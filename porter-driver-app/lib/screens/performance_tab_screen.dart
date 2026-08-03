import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PerformanceTabScreen extends StatefulWidget {
  const PerformanceTabScreen({super.key});

  @override
  State<PerformanceTabScreen> createState() => _PerformanceTabScreenState();
}

class _PerformanceTabScreenState extends State<PerformanceTabScreen> {
  static const accent = Color(0xFFFF6B35);
  static const surface = Color(0xFF1D1E33);

  Map<String, dynamic> _ratings = {};
  Map<String, dynamic> _profile = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await ApiService.getDriverProfile();
      final String? driverId = profile.id;

      print('🔍 PERFORMANCE: Fetching ratings for driver: $driverId');

      if (driverId != null && driverId.isNotEmpty) {
        final r = await ApiService.getDriverRatings(driverId);
        print('✅ PERFORMANCE: Ratings loaded: $r');
        if (mounted) {
          setState(() {
            _ratings = r is Map<String, dynamic> ? r : {};
            _profile = {
              'totalRides': profile.totalRides,
              'rating': profile.rating,
            };
            _loading = false;
          });
        }
      } else {
        print('⚠️ PERFORMANCE: No driver ID found');
        if (mounted) {
          setState(() {
            _ratings = {};
            _profile = {
              'totalRides': profile.totalRides,
              'rating': profile.rating,
            };
            _loading = false;
          });
        }
      }
    } catch (e) {
      print('❌ PERFORMANCE: Error loading ratings: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: accent));
    }

    final avgRating = _ratings['averageRating'] ?? _profile['rating'] ?? 0.0;
    final totalRatings = _ratings['totalRatings'] ?? 0;
    final totalTrips = _ratings['totalTrips'] ?? _profile['totalRides'] ?? 0;
    final acceptanceRate = _ratings['acceptanceRate'] ?? 0;
    final cancellationRate = _ratings['cancellationRate'] ?? 0;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        color: accent,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Performance',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),

              // Rating Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accent.withValues(alpha: 0.15),
                      accent.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${avgRating is num ? avgRating.toStringAsFixed(1) : avgRating}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: List.generate(5, (i) {
                            final stars = avgRating is num
                                ? avgRating.toDouble()
                                : 0.0;
                            if (i < stars.floor()) {
                              return const Icon(Icons.star,
                                  color: Colors.amber, size: 18);
                            }
                            if (i < stars.ceil() && stars % 1 > 0) {
                              return const Icon(Icons.star_half,
                                  color: Colors.amber, size: 18);
                            }
                            return Icon(Icons.star,
                                color: Colors.white.withValues(alpha: 0.2),
                                size: 18);
                          }),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Based on $totalRatings ratings',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Stats rows
              _statRow('Total Trips', '$totalTrips',
                  Icons.local_shipping_rounded),
              const SizedBox(height: 10),
              _statRow('Total Ratings', '$totalRatings', Icons.star_rounded),
              const SizedBox(height: 10),
              _statRow(
                'Acceptance Rate',
                '${acceptanceRate > 0 ? acceptanceRate.toStringAsFixed(1) : 'N/A'}%',
                Icons.check_circle_rounded,
              ),
              const SizedBox(height: 10),
              _statRow(
                'Cancellation Rate',
                '${cancellationRate > 0 ? cancellationRate.toStringAsFixed(1) : 'N/A'}%',
                Icons.cancel_rounded,
              ),
              const SizedBox(height: 10),
              _statRow(
                'Average Rating',
                '${avgRating is num ? avgRating.toStringAsFixed(1) : avgRating}',
                Icons.trending_up_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statRow(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accent, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: accent,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ]),
    );
  }
}