import 'package:flutter/material.dart';
import '../services/api_service.dart';

// ══════════════════════════════════════════════════════════════════════════════
// SHARED PALETTE
// ══════════════════════════════════════════════════════════════════════════════
class _P {
  static const Color bg      = Color(0xFFF7F8FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF1A1A2E);
  static const Color accent  = Color(0xFF0066FF);
  static const Color border  = Color(0xFFE8ECF0);
  static const Color textPri = Color(0xFF0D0D0D);
  static const Color textSec = Color(0xFF8A94A6);
  static const Color green   = Color(0xFF00C48C);
  static const Color amber   = Color(0xFFFFC72C);
  static const Color red     = Color(0xFFFF3B30);
  static const Color orange  = Color(0xFFFF8C42);
}

// ══════════════════════════════════════════════════════════════════════════════
// KYC MANAGEMENT SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class KycManagementScreen extends StatefulWidget {
  const KycManagementScreen({super.key});
  @override
  State<KycManagementScreen> createState() => _KycManagementScreenState();
}

class _KycManagementScreenState extends State<KycManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _pendingDocuments  = [];
  List<dynamic> _allPendingDrivers = [];
  bool _loading = true;
  int  _pendingCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final pendingData = await ApiService.getPendingKyc(page: 0);
      final drivers     = await ApiService.getAllPendingDrivers();
      final count       = await ApiService.getPendingKycCount();
      setState(() {
        _pendingDocuments  = pendingData['content'] ?? [];
        _allPendingDrivers = drivers;
        _pendingCount      = count;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.bg,
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _P.accent, strokeWidth: 2))
          : TabBarView(
              controller: _tabController,
              children: [_buildPendingTab(), _buildDriversTab()],
            ),
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _P.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      title: const Text(
        'KYC Management',
        style: TextStyle(color: _P.textPri, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(49),
        child: Column(
          children: [
            const Divider(height: 1, color: _P.border),
            TabBar(
              controller: _tabController,
              labelColor: _P.accent,
              unselectedLabelColor: _P.textSec,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              indicatorColor: _P.accent,
              indicatorWeight: 2,
              dividerColor: Colors.transparent,
              tabs: [
                Tab(
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.hourglass_bottom_rounded, size: 15),
                    const SizedBox(width: 6),
                    Text('Pending ($_pendingCount)'),
                  ]),
                ),
                const Tab(
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.people_alt_rounded, size: 15),
                    SizedBox(width: 6),
                    Text('Drivers'),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Pending Tab ───────────────────────────────────────────────────────────
  Widget _buildPendingTab() {
    if (_pendingDocuments.isEmpty) {
      return _emptyState(Icons.check_circle_outline_rounded, _P.green, 'All KYC Verified!', 'No pending documents right now');
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: _P.accent,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _pendingDocuments.length,
        itemBuilder: (_, i) => _documentCard(_pendingDocuments[i] as Map<String, dynamic>),
      ),
    );
  }

  Widget _documentCard(Map<String, dynamic> doc) {
    final name = doc['driverName'] ?? 'Driver';
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DocumentViewScreen(documentId: doc['id'], onApprovalChanged: _load)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _P.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _P.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(children: [
                _avatar(null, name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(name, style: const TextStyle(color: _P.textPri, fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: -0.2)),
                    const SizedBox(height: 2),
                    Text(doc['driverPhone'] ?? '', style: const TextStyle(color: _P.textSec, fontSize: 12)),
                  ]),
                ),
                _chip('PENDING', _P.orange, _P.orange.withOpacity(0.10)),
              ]),
            ),

            // Document thumbnail
            if ((doc['documentUrl'] ?? '').toString().isNotEmpty)
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ImageViewerScreen(
                    imageUrl: ApiService.getImageUrl(doc['documentUrl']),
                    title: doc['documentType'] ?? 'Document',
                  ),
                )),
                child: Container(
                  height: 130,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _P.border),
                    color: _P.bg,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      ApiService.getImageUrl(doc['documentUrl']),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imgPlaceholder('Tap to view'),
                      loadingBuilder: _imgLoader,
                    ),
                  ),
                ),
              ),

            // Footer row
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              child: Row(children: [
                Icon(Icons.description_outlined, size: 13, color: _P.accent),
                const SizedBox(width: 5),
                Text(doc['documentType'] ?? 'Unknown', style: const TextStyle(color: _P.textSec, fontSize: 12)),
                const SizedBox(width: 14),
                Icon(Icons.calendar_today_outlined, size: 13, color: _P.textSec),
                const SizedBox(width: 5),
                Text(_formatDate(doc['uploadedAt']), style: const TextStyle(color: _P.textSec, fontSize: 12)),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded, color: _P.textSec, size: 16),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // ── Drivers Tab ───────────────────────────────────────────────────────────
  Widget _buildDriversTab() {
    if (_allPendingDrivers.isEmpty) {
      return _emptyState(Icons.verified_outlined, _P.green, 'All Drivers Verified!', 'No pending KYC for drivers');
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: _P.accent,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _allPendingDrivers.length,
        itemBuilder: (_, i) => _driverCard(_allPendingDrivers[i] as Map<String, dynamic>),
      ),
    );
  }

  Widget _driverCard(Map<String, dynamic> doc) {
    final name         = doc['driverName'] ?? 'Driver';
    final phone        = doc['driverPhone'] ?? '';
    final totalDocs    = (doc['totalDocuments'] ?? 0) as num;
    final approvedDocs = (doc['approvedDocuments'] ?? 0) as num;
    final pct          = totalDocs > 0 ? approvedDocs / totalDocs : 0.0;
    final done         = approvedDocs == totalDocs;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => DriverKycDetailsScreen(
          driverId: doc['driverProfileId'],
          driverName: name,
          driverPhone: phone,
          onUpdated: _load,
        ),
      )),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _P.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _P.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          Row(children: [
            _avatar(null, name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(color: _P.textPri, fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: -0.2)),
                const SizedBox(height: 2),
                Text(phone, style: const TextStyle(color: _P.textSec, fontSize: 12)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('$approvedDocs/$totalDocs',
                  style: TextStyle(color: done ? _P.green : _P.accent, fontWeight: FontWeight.w800, fontSize: 15)),
              const Text('approved', style: TextStyle(color: _P.textSec, fontSize: 10)),
            ]),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: _P.textSec, size: 16),
          ]),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: pct.toDouble(),
              minHeight: 6,
              backgroundColor: _P.border,
              valueColor: AlwaysStoppedAnimation<Color>(done ? _P.green : _P.accent),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _emptyState(IconData icon, Color color, String title, String sub) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(color: color.withOpacity(0.08), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(color: _P.textPri, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(sub, style: const TextStyle(color: _P.textSec, fontSize: 13)),
      ]),
    );
  }

  String _formatDate(dynamic d) {
    if (d == null) return 'N/A';
    try { final dt = DateTime.parse(d.toString()); return '${dt.day}/${dt.month}/${dt.year}'; }
    catch (_) { return 'N/A'; }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DOCUMENT VIEW SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class DocumentViewScreen extends StatefulWidget {
  final String documentId;
  final VoidCallback onApprovalChanged;
  const DocumentViewScreen({super.key, required this.documentId, required this.onApprovalChanged});
  @override
  State<DocumentViewScreen> createState() => _DocumentViewScreenState();
}

class _DocumentViewScreenState extends State<DocumentViewScreen> {
  Map<String, dynamic>? _document;
  bool _loading = true;
  bool _submitting = false;
  final _notesCtrl = TextEditingController();

  @override
  void initState() { super.initState(); _fetchDocument(); }
  @override
  void dispose() { _notesCtrl.dispose(); super.dispose(); }

  Future<void> _fetchDocument() async {
    setState(() => _loading = true);
    try {
      final doc = await ApiService.getDocumentDetails(widget.documentId);
      setState(() => _document = doc);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _P.red));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _P.bg,
      appBar: AppBar(
        backgroundColor: _P.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: _P.border)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _P.primary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Document Details',
            style: TextStyle(color: _P.textPri, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _P.accent, strokeWidth: 2))
          : _document == null
              ? Center(child: Text('Document not found', style: const TextStyle(color: _P.textSec)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  child: _buildContent(),
                ),
    );
  }

  Widget _buildContent() {
    final d      = _document!;
    final status = d['status'] ?? 'PENDING';
    final isPending = status == 'PENDING';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Driver info
      if (d['driverName'] != null) ...[
        _sectionLabel('Driver Information'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _P.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _P.border),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
          ),
          child: Row(children: [
            _avatar(null, d['driverName'] ?? 'D'),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d['driverName'] ?? '', style: const TextStyle(color: _P.textPri, fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 3),
              Text(d['driverPhone'] ?? '', style: const TextStyle(color: _P.textSec, fontSize: 13)),
            ]),
          ]),
        ),
        const SizedBox(height: 20),
      ],

      // Meta row
      Row(children: [
        Expanded(child: _metaCard('Document Type', d['documentType'] ?? 'Unknown', Icons.description_outlined, _P.accent)),
        const SizedBox(width: 12),
        Expanded(child: _metaCard('Upload Date', _formatDate(d['uploadedAt']), Icons.calendar_today_outlined, _P.textSec)),
      ]),
      const SizedBox(height: 12),

      // Status
      _metaCard('Status', status, _statusIcon(status), _statusColor(status)),
      const SizedBox(height: 20),

      // Document image
      _sectionLabel('Document Image'),
      const SizedBox(height: 10),
      GestureDetector(
        onTap: () {
          if (d['documentUrl'] != null) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => ImageViewerScreen(
              imageUrl: ApiService.getImageUrl(d['documentUrl']),
              title: d['documentType'] ?? 'Document',
            )));
          }
        },
        child: Container(
          height: 280,
          decoration: BoxDecoration(
            color: _P.bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _P.border),
          ),
          child: d['documentUrl'] != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    ApiService.getImageUrl(d['documentUrl']),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imgPlaceholder('Failed to load image'),
                    loadingBuilder: _imgLoader,
                  ),
                )
              : _imgPlaceholder('No image provided'),
        ),
      ),
      const SizedBox(height: 6),
      Center(child: Text('Tap to view full size', style: const TextStyle(color: _P.textSec, fontSize: 11))),
      const SizedBox(height: 20),

      // Rejection reason
      if (status == 'REJECTED' && d['rejectionReason'] != null) ...[
        _infoBox('Rejection Reason', d['rejectionReason'], _P.red),
        const SizedBox(height: 20),
      ],

      // Approval notes
      if (status == 'APPROVED' && d['adminNotes'] != null) ...[
        _infoBox('Approval Notes', d['adminNotes'], _P.green),
        const SizedBox(height: 20),
      ],

      // Action area (PENDING only)
      if (isPending) ...[
        _sectionLabel('Admin Notes / Rejection Reason'),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: _P.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _P.border),
          ),
          child: TextField(
            controller: _notesCtrl,
            maxLines: 3,
            style: const TextStyle(color: _P.textPri, fontSize: 14),
            decoration: const InputDecoration(
              hintText: 'Enter approval notes or rejection reason…',
              hintStyle: TextStyle(color: _P.textSec, fontSize: 14),
              filled: true,
              fillColor: Colors.white,
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(14),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: _actionBtn('Reject', _P.red, _submitting ? null : _rejectDocument)),
          const SizedBox(width: 12),
          Expanded(child: _actionBtn('Approve', _P.green, _submitting ? null : _approveDocument, filled: true)),
        ]),
      ],

      const SizedBox(height: 32),
    ]);
  }

  Widget _metaCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _P.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _P.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Row(children: [
        Container(
          width: 32, height: 32,
          decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 15),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(color: _P.textSec, fontSize: 10, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }

  Widget _infoBox(String title, String body, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(height: 6),
        Text(body, style: const TextStyle(color: _P.textPri, fontSize: 13, height: 1.4)),
      ]),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback? onTap, {bool filled = false}) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: filled ? color : color.withOpacity(0.10),
          foregroundColor: filled ? Colors.white : color,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: filled ? color : color.withOpacity(0.30)),
          ),
        ),
        child: _submitting
            ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: filled ? Colors.white : color, strokeWidth: 2))
            : Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text, style: const TextStyle(color: _P.textPri, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.2));
  }

  Future<void> _approveDocument() async {
    setState(() => _submitting = true);
    try {
      await ApiService.approveDocument(widget.documentId,
          adminNotes: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : 'Approved');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document Approved'), backgroundColor: _P.green));
        widget.onApprovalChanged();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _P.red));
    }
    setState(() => _submitting = false);
  }

  Future<void> _rejectDocument() async {
    setState(() => _submitting = true);
    try {
      await ApiService.rejectDocument(widget.documentId,
          rejectionReason: _notesCtrl.text.isNotEmpty ? _notesCtrl.text : 'Document rejected by admin');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document Rejected'), backgroundColor: _P.red));
        widget.onApprovalChanged();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _P.red));
    }
    setState(() => _submitting = false);
  }

  Color  _statusColor(String? s) => switch (s) { 'APPROVED' => _P.green, 'REJECTED' => _P.red, _ => _P.orange };
  IconData _statusIcon(String? s) => switch (s) { 'APPROVED' => Icons.check_circle_outline_rounded, 'REJECTED' => Icons.cancel_outlined, _ => Icons.hourglass_bottom_rounded };
  String _formatDate(dynamic d) {
    if (d == null) return 'N/A';
    try { final dt = DateTime.parse(d.toString()); return '${dt.day}/${dt.month}/${dt.year}'; } catch (_) { return 'N/A'; }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// DRIVER KYC DETAILS SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class DriverKycDetailsScreen extends StatefulWidget {
  final String driverId;
  final String driverName;
  final String driverPhone;
  final VoidCallback onUpdated;
  const DriverKycDetailsScreen({super.key, required this.driverId, required this.driverName, required this.driverPhone, required this.onUpdated});
  @override
  State<DriverKycDetailsScreen> createState() => _DriverKycDetailsScreenState();
}

class _DriverKycDetailsScreenState extends State<DriverKycDetailsScreen> {
  List<dynamic> _documents = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final docs = await ApiService.getDriverKyc(widget.driverId);
      setState(() => _documents = docs);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _P.red));
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final totalDocs    = _documents.length;
    final approvedDocs = _documents.where((d) => d['status'] == 'APPROVED').length;
    final rejectedDocs = _documents.where((d) => d['status'] == 'REJECTED').length;
    final pendingDocs  = _documents.where((d) => d['status'] == 'PENDING').length;
    final pct          = totalDocs > 0 ? approvedDocs / totalDocs : 0.0;
    final done         = approvedDocs == totalDocs && totalDocs > 0;

    return Scaffold(
      backgroundColor: _P.bg,
      appBar: AppBar(
        backgroundColor: _P.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: _P.border)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _P.primary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Driver KYC Documents',
            style: TextStyle(color: _P.textPri, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _P.accent, strokeWidth: 2))
          : RefreshIndicator(
              onRefresh: _load,
              color: _P.accent,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Driver header card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _P.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _P.border),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
                    ),
                    child: Row(children: [
                      _avatar(null, widget.driverName),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(widget.driverName, style: const TextStyle(color: _P.textPri, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.3)),
                          const SizedBox(height: 3),
                          Text(widget.driverPhone, style: const TextStyle(color: _P.textSec, fontSize: 13)),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 20),

                  // Stat boxes
                  Row(children: [
                    _statBox('Total',    '$totalDocs',    _P.accent),
                    const SizedBox(width: 10),
                    _statBox('Approved', '$approvedDocs', _P.green),
                    const SizedBox(width: 10),
                    _statBox('Rejected', '$rejectedDocs', _P.red),
                    const SizedBox(width: 10),
                    _statBox('Pending',  '$pendingDocs',  _P.orange),
                  ]),
                  const SizedBox(height: 16),

                  // Progress bar
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _P.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: _P.border),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        const Text('Overall Progress', style: TextStyle(color: _P.textPri, fontSize: 13, fontWeight: FontWeight.w700)),
                        Text('$approvedDocs/$totalDocs',
                            style: TextStyle(color: done ? _P.green : _P.accent, fontSize: 13, fontWeight: FontWeight.w800)),
                      ]),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor: _P.border,
                          valueColor: AlwaysStoppedAnimation<Color>(done ? _P.green : _P.accent),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 24),

                  // Documents list
                  const Text('Documents', style: TextStyle(color: _P.textPri, fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                  const SizedBox(height: 12),

                  if (_documents.isEmpty)
                    Center(child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text('No documents found', style: const TextStyle(color: _P.textSec)),
                    ))
                  else
                    ..._documents.map((doc) => _documentTile(doc as Map<String, dynamic>)),
                ]),
              ),
            ),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _P.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: _P.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Column(children: [
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(color: _P.textSec, fontSize: 10), textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _documentTile(Map<String, dynamic> doc) {
    final status      = doc['status'] ?? 'UNKNOWN';
    final statusColor = _statusColor(status);
    final statusIcon  = _statusIcon(status);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => DocumentViewScreen(
          documentId: doc['id'],
          onApprovalChanged: () { _load(); widget.onUpdated(); },
        ),
      )),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _P.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: _P.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: statusColor.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(doc['documentType'] ?? 'Unknown', style: const TextStyle(color: _P.textPri, fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 3),
              Row(children: [
                _chip(status, statusColor, statusColor.withOpacity(0.10)),
                const SizedBox(width: 8),
                Text(_formatDate(doc['uploadedAt']), style: const TextStyle(color: _P.textSec, fontSize: 11)),
              ]),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: _P.textSec, size: 16),
        ]),
      ),
    );
  }

  Color    _statusColor(String? s) => switch (s) { 'APPROVED' => _P.green, 'REJECTED' => _P.red, _ => _P.orange };
  IconData _statusIcon(String? s)  => switch (s) { 'APPROVED' => Icons.check_circle_outline_rounded, 'REJECTED' => Icons.cancel_outlined, _ => Icons.hourglass_bottom_rounded };
  String   _formatDate(dynamic d) {
    if (d == null) return 'N/A';
    try { final dt = DateTime.parse(d.toString()); return '${dt.day}/${dt.month}/${dt.year}'; } catch (_) { return 'N/A'; }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// IMAGE VIEWER SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class ImageViewerScreen extends StatefulWidget {
  final String imageUrl;
  final String title;
  const ImageViewerScreen({super.key, required this.imageUrl, required this.title});
  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late TransformationController _transformCtrl;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() { super.initState(); _transformCtrl = TransformationController(); }
  @override
  void dispose() { _transformCtrl.dispose(); super.dispose(); }

  void _handleDoubleTap() {
    if (_transformCtrl.value != Matrix4.identity()) {
      _transformCtrl.value = Matrix4.identity();
    } else {
      final pos = _doubleTapDetails!.localPosition;
      _transformCtrl.value = Matrix4.identity()
        ..translate(-pos.dx * 2, -pos.dy * 2)
        ..scale(3.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: GestureDetector(
        onDoubleTapDown: (d) => _doubleTapDetails = d,
        onDoubleTap: _handleDoubleTap,
        child: InteractiveViewer(
          transformationController: _transformCtrl,
          boundaryMargin: const EdgeInsets.all(80),
          minScale: 0.5,
          maxScale: 4,
          child: Center(
            child: Image.network(
              widget.imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.error_outline_rounded, size: 52, color: Colors.white.withOpacity(0.3)),
                const SizedBox(height: 12),
                Text('Failed to load image', style: TextStyle(color: Colors.white.withOpacity(0.5))),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SHARED WIDGET HELPERS
// ══════════════════════════════════════════════════════════════════════════════

Widget _avatar(String? url, String name) {
  return Container(
    width: 44, height: 44,
    decoration: BoxDecoration(
      color: _P.accent.withOpacity(0.10),
      shape: BoxShape.circle,
      border: Border.all(color: _P.accent.withOpacity(0.20), width: 1.5),
    ),
    child: Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(color: _P.accent, fontSize: 16, fontWeight: FontWeight.w800),
      ),
    ),
  );
}

Widget _chip(String label, Color textColor, Color bgColor) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.w700)),
  );
}

Widget _imgPlaceholder(String text) {
  return Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.image_outlined, size: 48, color: _P.textSec.withOpacity(0.4)),
      const SizedBox(height: 8),
      Text(text, style: const TextStyle(color: _P.textSec, fontSize: 12)),
    ]),
  );
}

Widget _imgLoader(BuildContext ctx, Widget child, ImageChunkEvent? progress) {
  if (progress == null) return child;
  return Center(
    child: CircularProgressIndicator(
      value: progress.expectedTotalBytes != null
          ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
          : null,
      color: _P.accent,
      strokeWidth: 2,
    ),
  );
}