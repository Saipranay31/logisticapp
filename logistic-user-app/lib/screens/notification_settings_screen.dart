import 'package:flutter/material.dart';
import '../services/api_service.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});
  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  static const primary = Color(0xFF6C63FF);
  static const bg = Color(0xFF0A0E21);
  static const surface = Color(0xFF1D1E33);

  bool _loading = true;
  bool _rideUpdates = true;
  bool _payments = true;
  bool _promotions = false;
  bool _system = true;
  bool _fcm = true;
  bool _sms = false;
  bool _email = false;
  bool _quietHours = false;
  TimeOfDay _quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd = const TimeOfDay(hour: 8, minute: 0);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ApiService.getNotificationPreferences();
      if (d != null) {
        setState(() {
          _rideUpdates = d['rideUpdatesEnabled'] ?? true;
          _payments = d['paymentNotificationsEnabled'] ?? true;
          _promotions = d['promotionalEnabled'] ?? false;
          _system = d['systemAlertsEnabled'] ?? true;
          _fcm = d['fcmEnabled'] ?? true;
          _sms = d['smsEnabled'] ?? false;
          _email = d['emailEnabled'] ?? false;
          _quietHours = d['quietHoursEnabled'] ?? false;
          if (d['quietHoursStart'] != null) {
            final p = d['quietHoursStart'].split(':');
            _quietStart = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
          }
          if (d['quietHoursEnd'] != null) {
            final p = d['quietHoursEnd'].split(':');
            _quietEnd = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
          }
        });
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _save(Map<String, dynamic> update) async {
    try {
      await ApiService.updateNotificationPreferences(update);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(backgroundColor: surface, title: const Text('Notification Settings', style: TextStyle(fontWeight: FontWeight.w700))),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _sectionTitle('Notification Types'),
                _toggle('Ride Updates', 'Pickup, delivery & status updates', _rideUpdates, (v) {
                  setState(() => _rideUpdates = v);
                  _save({'rideUpdatesEnabled': v});
                }),
                _toggle('Payment Alerts', 'Payment confirmations & receipts', _payments, (v) {
                  setState(() => _payments = v);
                  _save({'paymentNotificationsEnabled': v});
                }),
                _toggle('Promotions', 'Deals, offers & discounts', _promotions, (v) {
                  setState(() => _promotions = v);
                  _save({'promotionalEnabled': v});
                }),
                _toggle('System Alerts', 'App updates & security alerts', _system, (v) {
                  setState(() => _system = v);
                  _save({'systemAlertsEnabled': v});
                }),

                const SizedBox(height: 24),
                _sectionTitle('Delivery Channels'),
                _toggle('Push Notifications', 'Receive via FCM push', _fcm, (v) {
                  setState(() => _fcm = v);
                  _save({'fcmEnabled': v});
                }),
                _toggle('SMS', 'Receive via text message', _sms, (v) {
                  setState(() => _sms = v);
                  _save({'smsEnabled': v});
                }),
                _toggle('Email', 'Receive via email', _email, (v) {
                  setState(() => _email = v);
                  _save({'emailEnabled': v});
                }),

                const SizedBox(height: 24),
                _sectionTitle('Quiet Hours'),
                _toggle('Enable Quiet Hours', 'No notifications during set hours', _quietHours, (v) {
                  setState(() => _quietHours = v);
                  _save({'quietHoursEnabled': v});
                }),
                if (_quietHours) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _timeButton('Start', _quietStart, (t) {
                      setState(() => _quietStart = t);
                      _save({'quietHoursStart': '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'});
                    })),
                    const SizedBox(width: 12),
                    Expanded(child: _timeButton('End', _quietEnd, (t) {
                      setState(() => _quietEnd = t);
                      _save({'quietHoursEnd': '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'});
                    })),
                  ]),
                ],
              ]),
            ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
  );

  Widget _toggle(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
        ])),
        Switch.adaptive(value: value, onChanged: onChanged, activeColor: primary),
      ]),
    );
  }

  Widget _timeButton(String label, TimeOfDay time, ValueChanged<TimeOfDay> onPick) {
    return GestureDetector(
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: time);
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
          const SizedBox(height: 4),
          Text(time.format(context), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
