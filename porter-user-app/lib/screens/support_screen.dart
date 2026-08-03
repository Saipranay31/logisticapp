import 'package:flutter/material.dart';
import '../services/api_service.dart';

// ═══════════════════════════════════════════════════════════
//  DESIGN TOKENS — mirrors home_screen _Theme exactly
// ═══════════════════════════════════════════════════════════
class _T {
  static const bg            = Color(0xFFF5F5F7);
  static const white         = Color(0xFFFFFFFF);
  static const primary       = Color(0xFF1A1A2E);
  static const accent        = Color(0xFF6C63FF);
  static const green         = Color(0xFF00C853);
  static const red           = Color(0xFFFF3B30);
  static const amber         = Color(0xFFFF9500);
  static const textPrimary   = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
  static const textHint      = Color(0xFFBBBBBB);
  static const cardShadow    = Color(0x14000000);
  static const divider       = Color(0xFFEEEEEE);
  static const r8  = 8.0;
  static const r12 = 12.0;
  static const r16 = 16.0;
  static const r20 = 20.0;
  static const r24 = 24.0;
}

// ═══════════════════════════════════════════════════════════
//  SUPPORT SCREEN
// ═══════════════════════════════════════════════════════════
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _tickets    = [];
  bool          _loading    = true;
  String        _filter     = 'ALL'; // ALL | OPEN | RESOLVED

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _loadTickets();
  }

  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  Future<void> _loadTickets() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getSupportTickets();
      if (mounted) setState(() => _tickets = res is List ? res : []);
    } catch (_) {}
    if (mounted) {
      setState(() => _loading = false);
      _animCtrl.forward(from: 0);
    }
  }

  List<dynamic> get _filtered {
    if (_filter == 'ALL') return _tickets;
    if (_filter == 'OPEN') {
      return _tickets.where((t) =>
          t['status'] != 'RESOLVED' && t['status'] != 'CLOSED').toList();
    }
    return _tickets.where((t) =>
        t['status'] == 'RESOLVED' || t['status'] == 'CLOSED').toList();
  }

  // ── Status helpers ────────────────────────────────────────
  Color _statusColor(String s) {
    if (s == 'RESOLVED' || s == 'CLOSED') return _T.green;
    if (s == 'IN_PROGRESS') return _T.accent;
    return _T.amber;
  }

  String _statusLabel(String s) => switch (s) {
    'OPEN'        => 'Open',
    'IN_PROGRESS' => 'In Progress',
    'RESOLVED'    => 'Resolved',
    'CLOSED'      => 'Closed',
    _             => s,
  };

  // ── Category helpers ──────────────────────────────────────
  IconData _categoryIcon(String? c) => switch (c) {
    'PAYMENT'    => Icons.payment_rounded,
    'DRIVER'     => Icons.person_rounded,
    'RIDE_ISSUE' => Icons.local_shipping_rounded,
    _            => Icons.build_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [_buildSliverAppBar()],
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _T.accent, strokeWidth: 2))
            : FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: RefreshIndicator(
                    onRefresh: _loadTickets,
                    color: _T.accent,
                    child: CustomScrollView(
                      slivers: [
                        // ── Filter chips ──
                        SliverToBoxAdapter(child: _buildFilterRow()),

                        // ── Tickets or empty ──
                        if (_filtered.isEmpty)
                          SliverFillRemaining(child: _buildEmptyState())
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (_, i) => _TicketCard(
                                  ticket: _filtered[i],
                                  statusColor: _statusColor(_filtered[i]['status'] ?? 'OPEN'),
                                  statusLabel: _statusLabel(_filtered[i]['status'] ?? 'OPEN'),
                                  categoryIcon: _categoryIcon(_filtered[i]['category']),
                                  onTap: () => _openTicket(_filtered[i]),
                                ),
                                childCount: _filtered.length,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateTicket,
        backgroundColor: _T.primary,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
        label: const Text('New Ticket',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
      ),
    );
  }

  // ── Sliver AppBar ─────────────────────────────────────────
  Widget _buildSliverAppBar() {
  return SliverAppBar(
    backgroundColor: _T.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    pinned: true,
    // ── FIX 1: increased so stats row never overlaps title ──
    expandedHeight: 160,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_rounded, color: _T.primary),
      onPressed: () => Navigator.pop(context),
    ),
    title: const Text(
      'Help & Support',
      style: TextStyle(
        color: _T.textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
    ),
    // ── FIX 2: stats row sits BELOW the title, not behind it ──
    flexibleSpace: FlexibleSpaceBar(
      background: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: [
                _StatChip(
                  label: 'Total',
                  value: '${_tickets.length}',
                  color: _T.accent,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: 'Open',
                  value: '${_tickets.where((t) => t['status'] == 'OPEN').length}',
                  color: _T.amber,
                ),
                const SizedBox(width: 8),
                _StatChip(
                  label: 'Resolved',
                  value: '${_tickets.where((t) => t['status'] == 'RESOLVED' || t['status'] == 'CLOSED').length}',
                  color: _T.green,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: _T.divider),
    ),
  );
}


// ── Filter row ────────────────────────────────────────────
  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: ['ALL', 'OPEN', 'RESOLVED'].map((f) {
          final active = _filter == f;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? _T.primary : _T.white,
                  borderRadius: BorderRadius.circular(_T.r20),
                  boxShadow: [
                    BoxShadow(color: _T.cardShadow, blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Text(
                  f == 'ALL' ? 'All' : f == 'OPEN' ? 'Open' : 'Resolved',
                  style: TextStyle(
                    color: active ? Colors.white : _T.textSecondary,
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            color: _T.accent.withOpacity(0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.support_agent_rounded, color: _T.accent, size: 34),
        ),
        const SizedBox(height: 16),
        const Text('No tickets yet',
            style: TextStyle(color: _T.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Tap + New Ticket to get help',
            style: TextStyle(color: _T.textSecondary, fontSize: 13)),
      ]),
    );
  }

  // ── Create ticket sheet ───────────────────────────────────
  void _showCreateTicket() {
    final subjectCtrl = TextEditingController();
    final descCtrl    = TextEditingController();
    String category   = 'TECHNICAL';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _T.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(_T.r24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setBS) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Drag handle
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: _T.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),

            // Title
            const Text('Create Support Ticket',
                style: TextStyle(color: _T.textPrimary, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('We typically respond within 2 hours',
                style: TextStyle(color: _T.textSecondary, fontSize: 12)),
            const SizedBox(height: 20),

            // Subject
            _SheetField(ctrl: subjectCtrl, hint: 'Subject', maxLines: 1),
            const SizedBox(height: 10),
            _SheetField(ctrl: descCtrl, hint: 'Describe your issue in detail...', maxLines: 4),
            const SizedBox(height: 16),

            // Category label
            const Text('Category',
                style: TextStyle(color: _T.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            const SizedBox(height: 10),

            // Category chips
            Wrap(
              spacing: 8, runSpacing: 8,
              children: ['RIDE_ISSUE', 'PAYMENT', 'DRIVER', 'TECHNICAL'].map((c) {
                final sel = category == c;
                final icon = switch (c) {
                  'PAYMENT'    => Icons.payment_rounded,
                  'DRIVER'     => Icons.person_rounded,
                  'RIDE_ISSUE' => Icons.local_shipping_rounded,
                  _            => Icons.build_rounded,
                };
                return GestureDetector(
                  onTap: () => setBS(() => category = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: sel ? _T.primary : _T.bg,
                      borderRadius: BorderRadius.circular(_T.r12),
                      border: Border.all(
                        color: sel ? _T.primary : _T.divider,
                        width: 1.5,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, size: 13, color: sel ? Colors.white : _T.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        c.replaceAll('_', ' '),
                        style: TextStyle(
                          color: sel ? Colors.white : _T.textSecondary,
                          fontSize: 12,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ]),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Submit
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  if (subjectCtrl.text.trim().isEmpty) return;
                  Navigator.pop(ctx);
                  try {
                    await ApiService.createSupportTicket(
                      subject:     subjectCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      category:    category,
                    );
                    _loadTickets();
                  } catch (_) {}
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _T.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_T.r16)),
                ),
                child: const Text('Submit Ticket',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  void _openTicket(Map<String, dynamic> ticket) {
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => _TicketDetailScreen(ticket: ticket)));
  }
}

// ═══════════════════════════════════════════════════════════
//  STAT CHIP — used in app bar
// ═══════════════════════════════════════════════════════════
class _StatChip extends StatelessWidget {
  final String label, value;
  final Color  color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(_T.r8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(value,
            style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w800)),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(color: color.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  TICKET CARD
// ═══════════════════════════════════════════════════════════
class _TicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final Color    statusColor;
  final String   statusLabel;
  final IconData categoryIcon;
  final VoidCallback onTap;

  const _TicketCard({
    required this.ticket,
    required this.statusColor,
    required this.statusLabel,
    required this.categoryIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _T.white,
          borderRadius: BorderRadius.circular(_T.r16),
          boxShadow: const [
            BoxShadow(color: _T.cardShadow, blurRadius: 12, offset: Offset(0, 3)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Top row: status + ticket number ──
          Row(children: [
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 5, height: 5,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(statusLabel,
                    style: TextStyle(
                        color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
              ]),
            ),
            const SizedBox(width: 8),

            // Category badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _T.accent.withOpacity(0.06),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(categoryIcon, size: 10, color: _T.accent),
                const SizedBox(width: 4),
                Text(
                  (ticket['category'] ?? '').toString().replaceAll('_', ' '),
                  style: const TextStyle(color: _T.accent, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ]),
            ),

            const Spacer(),
            Text(
              ticket['ticketNumber']?.toString() ?? '',
              style: const TextStyle(color: _T.textHint, fontSize: 11, fontWeight: FontWeight.w500),
            ),
          ]),

          const SizedBox(height: 12),

          // ── Subject ──
          Text(
            ticket['subject']?.toString() ?? '',
            style: const TextStyle(
                color: _T.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 4),

          // ── Description preview ──
          Text(
            ticket['description']?.toString() ?? '',
            style: const TextStyle(color: _T.textSecondary, fontSize: 13, height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 12),
          const Divider(color: _T.divider, height: 1),
          const SizedBox(height: 10),

          // ── Footer: chevron ──
          Row(children: [
            const Icon(Icons.chat_bubble_outline_rounded, size: 13, color: _T.textHint),
            const SizedBox(width: 5),
            Text(
              'Tap to view conversation',
              style: const TextStyle(color: _T.textHint, fontSize: 11),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded, size: 16, color: _T.textHint),
          ]),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  SHEET FIELD — reusable text input for bottom sheet
// ═══════════════════════════════════════════════════════════
class _SheetField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final int maxLines;
  const _SheetField({required this.ctrl, required this.hint, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _T.bg,
        borderRadius: BorderRadius.circular(_T.r12),
        border: Border.all(color: _T.divider),
      ),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(color: _T.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _T.textHint),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  TICKET DETAIL SCREEN
// ═══════════════════════════════════════════════════════════
class _TicketDetailScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;
  const _TicketDetailScreen({required this.ticket});
  @override
  State<_TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<_TicketDetailScreen> {
  final _msgCtrl     = TextEditingController();
  final _scrollCtrl  = ScrollController();
  List<dynamic> _messages = [];
  bool _loading  = true;
  bool _sending  = false;

  @override
  void initState() { super.initState(); _loadMessages(); }

  @override
  void dispose() { _msgCtrl.dispose(); _scrollCtrl.dispose(); super.dispose(); }

  Future<void> _loadMessages() async {
    try {
      final res = await ApiService.getTicketMessages(widget.ticket['id'].toString());
      if (mounted) setState(() { _messages = res is List ? res : []; _loading = false; });
      _scrollToBottom();
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _msgCtrl.clear();
    try {
      await ApiService.addTicketMessage(widget.ticket['id'], text);
      await _loadMessages();
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final status   = widget.ticket['status'] ?? 'OPEN';
    final resolved = status == 'RESOLVED' || status == 'CLOSED';

    return Scaffold(
      backgroundColor: _T.bg,
      appBar: AppBar(
        backgroundColor: _T.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _T.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            widget.ticket['ticketNumber']?.toString() ?? 'Ticket',
            style: const TextStyle(
                color: _T.textPrimary, fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 1),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: (resolved ? _T.green : _T.amber).withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status,
              style: TextStyle(
                  color: resolved ? _T.green : _T.amber,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5),
            ),
          ),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _T.divider),
        ),
      ),
      body: Column(children: [

        // ── Ticket info card ──
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _T.white,
            borderRadius: BorderRadius.circular(_T.r16),
            boxShadow: const [
              BoxShadow(color: _T.cardShadow, blurRadius: 10, offset: Offset(0, 3)),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _T.accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(_T.r8),
                ),
                child: const Icon(Icons.support_agent_rounded,
                    color: _T.accent, size: 16),
              ),
              const SizedBox(width: 10),
              const Text('Your Issue',
                  style: TextStyle(
                      color: _T.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
            ]),
            const SizedBox(height: 10),
            Text(
              widget.ticket['subject']?.toString() ?? '',
              style: const TextStyle(
                  color: _T.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15),
            ),
            if ((widget.ticket['description']?.toString() ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                widget.ticket['description']?.toString() ?? '',
                style: const TextStyle(color: _T.textSecondary, fontSize: 13, height: 1.4),
              ),
            ],
          ]),
        ),

        // ── Messages ──
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _T.accent, strokeWidth: 2))
              : _messages.isEmpty
                  ? Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            color: _T.textHint, size: 36),
                        const SizedBox(height: 10),
                        const Text('No messages yet',
                            style: TextStyle(color: _T.textSecondary, fontSize: 13)),
                        const Text('Start the conversation below',
                            style: TextStyle(color: _T.textHint, fontSize: 12)),
                      ]),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _MessageBubble(msg: _messages[i]),
                    ),
        ),

        // ── Input bar ──
        Container(
          padding: EdgeInsets.fromLTRB(
              16, 10, 16, MediaQuery.of(context).padding.bottom + 10),
          decoration: const BoxDecoration(
            color: _T.white,
            border: Border(top: BorderSide(color: _T.divider)),
          ),
          child: Row(children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: _T.bg,
                  borderRadius: BorderRadius.circular(_T.r12),
                  border: Border.all(color: _T.divider),
                ),
                child: TextField(
                  controller: _msgCtrl,
                  style: const TextStyle(color: _T.textPrimary, fontSize: 14),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: _T.textHint),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _send,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: _T.primary,
                  borderRadius: BorderRadius.circular(_T.r12),
                  boxShadow: [
                    BoxShadow(
                        color: _T.primary.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: _sending
                    ? const Center(
                        child: SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
//  MESSAGE BUBBLE
// ═══════════════════════════════════════════════════════════
class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg['senderType'] == 'USER';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            // Support avatar
            Container(
              width: 28, height: 28,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _T.accent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.support_agent_rounded,
                  color: _T.accent, size: 14),
            ),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? _T.primary : _T.white,
                borderRadius: BorderRadius.only(
                  topLeft:     const Radius.circular(16),
                  topRight:    const Radius.circular(16),
                  bottomLeft:  Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: const [
                  BoxShadow(color: _T.cardShadow, blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              child: Text(
                msg['message']?.toString() ?? '',
                style: TextStyle(
                  color: isUser ? Colors.white : _T.textPrimary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }
}