import 'package:flutter/material.dart';
import '../services/api_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  static const accent = Color(0xFFFF6B35);
  static const bg = Color(0xFF0A0E21);
  static const surface = Color(0xFF1D1E33);

  bool _loading = true;
  bool _rides = true, _payments = true, _promos = false, _system = true;
  bool _fcm = true, _sms = false, _email = false;
  bool _quiet = false;
  TimeOfDay _qStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _qEnd = const TimeOfDay(hour: 8, minute: 0);

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final d = await ApiService.getNotificationPreferences();
      if (d != null) setState(() {
        _rides = d['rideUpdatesEnabled'] ?? true;
        _payments = d['paymentNotificationsEnabled'] ?? true;
        _promos = d['promotionalEnabled'] ?? false;
        _system = d['systemAlertsEnabled'] ?? true;
        _fcm = d['fcmEnabled'] ?? true;
        _sms = d['smsEnabled'] ?? false;
        _email = d['emailEnabled'] ?? false;
        _quiet = d['quietHoursEnabled'] ?? false;
        if (d['quietHoursStart'] != null) { final p = d['quietHoursStart'].split(':'); _qStart = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])); }
        if (d['quietHoursEnd'] != null) { final p = d['quietHoursEnd'].split(':'); _qEnd = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])); }
      });
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _save(Map<String, dynamic> u) async { try { await ApiService.updateNotificationPreferences(u); } catch (_) {} }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(backgroundColor: surface, title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w700))),
      body: _loading ? const Center(child: CircularProgressIndicator(color: accent))
          : SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _section('Notification Types'),
              _toggle('Ride Updates', _rides, (v) { setState(() => _rides = v); _save({'rideUpdatesEnabled': v}); }),
              _toggle('Payment Alerts', _payments, (v) { setState(() => _payments = v); _save({'paymentNotificationsEnabled': v}); }),
              _toggle('Promotions', _promos, (v) { setState(() => _promos = v); _save({'promotionalEnabled': v}); }),
              _toggle('System Alerts', _system, (v) { setState(() => _system = v); _save({'systemAlertsEnabled': v}); }),
              const SizedBox(height: 20),
              _section('Channels'),
              _toggle('Push (FCM)', _fcm, (v) { setState(() => _fcm = v); _save({'fcmEnabled': v}); }),
              _toggle('SMS', _sms, (v) { setState(() => _sms = v); _save({'smsEnabled': v}); }),
              _toggle('Email', _email, (v) { setState(() => _email = v); _save({'emailEnabled': v}); }),
              const SizedBox(height: 20),
              _section('Quiet Hours'),
              _toggle('Enable', _quiet, (v) { setState(() => _quiet = v); _save({'quietHoursEnabled': v}); }),
              if (_quiet) Padding(padding: const EdgeInsets.only(top: 12), child: Row(children: [
                Expanded(child: _timePick('Start', _qStart, (t) { setState(() => _qStart = t); _save({'quietHoursStart': '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}'}); })),
                const SizedBox(width: 12),
                Expanded(child: _timePick('End', _qEnd, (t) { setState(() => _qEnd = t); _save({'quietHoursEnd': '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}'}); })),
              ])),
            ])),
    );
  }

  Widget _section(String t) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)));
  Widget _toggle(String t, bool v, ValueChanged<bool> c) => Container(
    margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12)),
    child: Row(children: [Expanded(child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 14))), Switch.adaptive(value: v, onChanged: c, activeColor: accent)]));
  Widget _timePick(String l, TimeOfDay t, ValueChanged<TimeOfDay> c) => GestureDetector(
    onTap: () async { final p = await showTimePicker(context: context, initialTime: t); if (p != null) c(p); },
    child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [Text(l, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)), const SizedBox(height: 4),
        Text(t.format(context), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700))])));
}
