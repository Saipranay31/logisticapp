import 'package:flutter/material.dart';
import '../services/api_service.dart';

class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});
  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  static const primary = Color(0xFF6C63FF);
  static const bg = Color(0xFF0A0E21);
  static const surface = Color(0xFF1D1E33);

  List<dynamic> _contacts = [];
  bool _loading = true;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getEmergencyContacts();
      setState(() => _contacts = res);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading contacts: ${e.toString()}')),
        );
      }
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: surface,
        title: const Text('Emergency Contacts', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [IconButton(icon: const Icon(Icons.add_rounded, color: primary), onPressed: _showAddContact)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: primary))
          : _contacts.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.emergency_rounded, size: 64, color: Colors.red.withOpacity(0.15)),
                  const SizedBox(height: 16),
                  Text('No emergency contacts', style: TextStyle(color: Colors.white.withOpacity(0.4))),
                  const SizedBox(height: 8),
                  Text('Add contacts who will be notified during SOS', style: TextStyle(color: Colors.white.withOpacity(0.25), fontSize: 13)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: _showAddContact,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Contact'),
                    style: ElevatedButton.styleFrom(backgroundColor: primary),
                  ),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _contacts.length,
                  itemBuilder: (_, i) {
                    final c = _contacts[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        CircleAvatar(backgroundColor: Colors.red.withOpacity(0.15),
                            child: Text((c['name'] ?? 'C')[0].toUpperCase(), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700))),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(c['name'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                          const SizedBox(height: 2),
                          Text('${c['phone'] ?? ''} · ${c['relationship'] ?? ''}', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
                        ])),
                        IconButton(
                          icon: Icon(Icons.delete_outline_rounded, color: Colors.red.withOpacity(0.6)),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                backgroundColor: surface,
                                title: const Text('Delete Contact?', style: TextStyle(color: Colors.white)),
                                content: const Text('Are you sure? This contact will be removed.', style: TextStyle(color: Colors.white70)),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              try {
                                await ApiService.deleteEmergencyContact(c['id'].toString());
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Contact deleted')));
                                  _load();
                                }
                              } catch (e) {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: ${e.toString()}')));
                              }
                            }
                          },
                        ),
                      ]),
                    );
                  },
                ),
    );
  }

  void _showAddContact() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final relCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Add Emergency Contact', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _field(nameCtrl, 'Full Name'),
            const SizedBox(height: 10),
            _field(phoneCtrl, 'Phone Number', keyboard: TextInputType.phone),
            const SizedBox(height: 10),
            _field(relCtrl, 'Relationship (e.g., Spouse, Parent)'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: _adding ? null : () async {
                  if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('⚠️ Please fill in all fields')));
                    return;
                  }
                  setModalState(() => _adding = true);
                  try {
                    await ApiService.addEmergencyContact(name: nameCtrl.text, phone: phoneCtrl.text, relationship: relCtrl.text);
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Contact added')));
                      _load();
                    }
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('❌ Error: ${e.toString()}')));
                  } finally {
                    setModalState(() => _adding = false);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: _adding
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Add Contact', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, {TextInputType? keyboard}) {
    return TextField(
      controller: ctrl, keyboardType: keyboard,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint, hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
        filled: true, fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
    );
  }
}
