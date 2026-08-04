import 'package:flutter/material.dart';
import '../services/api_service.dart';

class EmergencyAlertsScreen extends StatefulWidget {
  const EmergencyAlertsScreen({super.key});
  @override
  State<EmergencyAlertsScreen> createState() => _EmergencyAlertsScreenState();
}

class _EmergencyAlertsScreenState extends State<EmergencyAlertsScreen> {
  static const bg = Color(0xFF0A0E21);
  static const surface = Color(0xFF1D1E33);
  List<dynamic> _alerts = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService.getEmergencyAlerts();
      setState(() => _alerts = r);
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text('Emergency Alerts', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white54), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : _alerts.isEmpty
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.green.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    Text('No active alerts', style: TextStyle(color: Colors.white.withOpacity(0.4))),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _alerts.length,
                    itemBuilder: (_, i) {
                      final a = _alerts[i];
                      final status = a['status'] ?? 'ACTIVE';
                      final isActive = status == 'ACTIVE';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(14),
                          border: isActive ? Border.all(color: Colors.red.withOpacity(0.4)) : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.emergency_rounded, color: isActive ? Colors.red : Colors.grey, size: 20),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: (isActive ? Colors.red : Colors.grey).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(status, style: TextStyle(color: isActive ? Colors.red : Colors.grey, fontSize: 10, fontWeight: FontWeight.w600)),
                              ),
                              const Spacer(),
                              Text(a['alertType'] ?? 'SOS', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
                            ]),
                            const SizedBox(height: 8),
                            Text(a['description'] ?? 'Emergency SOS Alert', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                            if (a['latitude'] != null) ...[
                              const SizedBox(height: 4),
                              Text('Location: ${a['latitude']}, ${a['longitude']}', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11)),
                            ],
                            if (isActive) ...[
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 34,
                                    child: OutlinedButton(
                                      onPressed: () async { await ApiService.acknowledgeAlert(a['id']); _load(); },
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Colors.orange),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: const Text('Acknowledge', style: TextStyle(color: Colors.orange, fontSize: 11)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SizedBox(
                                    height: 34,
                                    child: ElevatedButton(
                                      onPressed: () async { await ApiService.resolveAlert(a['id']); _load(); },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF00E676),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: const Text('Resolve', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 11)),
                                    ),
                                  ),
                                ),
                              ]),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
