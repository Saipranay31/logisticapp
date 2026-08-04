import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});
  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  // ── Palette ──────────────────────────────────────────────────────────────
  static const Color _bg      = Color(0xFFF7F8FA);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _primary = Color(0xFF1A1A2E);
  static const Color _accent  = Color(0xFF0066FF);
  static const Color _border  = Color(0xFFE8ECF0);
  static const Color _textPri = Color(0xFF0D0D0D);
  static const Color _textSec = Color(0xFF8A94A6);
  static const Color _green   = Color(0xFF00C48C);
  static const Color _orange  = Color(0xFFFF8C42);
  static const Color _red     = Color(0xFFFF3B30);

  List<dynamic> _tickets = [];
  bool _loading = true;
  bool _showOpen = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = _showOpen
          ? await ApiService.getOpenTickets()
          : await ApiService.getAllTickets();
      setState(() => _tickets = r);
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // APP BAR
  // ══════════════════════════════════════════════════════════════════════════
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: _border),
      ),
      title: const Text(
        'Support Tickets',
        style: TextStyle(
          color: _textPri,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        GestureDetector(
          onTap: () { setState(() => _showOpen = !_showOpen); _load(); },
          child: Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _showOpen ? _accent : _bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _showOpen ? _accent : _border),
            ),
            child: Text(
              _showOpen ? 'Show All' : 'Open Only',
              style: TextStyle(
                color: _showOpen ? Colors.white : _accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BODY
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _accent, strokeWidth: 2));
    }

    if (_tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.support_agent_rounded, color: _accent, size: 28),
            ),
            const SizedBox(height: 12),
            const Text('No tickets found',
                style: TextStyle(color: _textPri, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(
              _showOpen ? 'No open tickets at the moment' : 'All clear — nothing to show',
              style: const TextStyle(color: _textSec, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: _accent,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _tickets.length,
        itemBuilder: (_, i) => _ticketTile(_tickets[i] as Map<String, dynamic>),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // TICKET TILE
  // ══════════════════════════════════════════════════════════════════════════
  Widget _ticketTile(Map<String, dynamic> t) {
    final status   = t['status'] ?? 'OPEN';
    final resolved = status == 'RESOLVED' || status == 'CLOSED';
    final statusColor = resolved ? _green : _orange;
    final category = t['category'] ?? '';

    return GestureDetector(
      onTap: () => _openDetail(t),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: status chip + ticket number + category
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  t['ticketNumber'] ?? '',
                  style: const TextStyle(color: _textSec, fontSize: 11),
                ),
                const Spacer(),
                if (category.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      category,
                      style: const TextStyle(color: _accent, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Subject
            Text(
              t['subject'] ?? '',
              style: const TextStyle(
                color: _textPri,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 4),

            // Description preview
            Text(
              t['description'] ?? '',
              style: const TextStyle(color: _textSec, fontSize: 12, height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 10),
            const Divider(color: _border, height: 1),
            const SizedBox(height: 8),

            // Bottom row: chevron
            Row(
              children: [
                const Icon(Icons.chat_bubble_outline_rounded, color: _textSec, size: 13),
                const SizedBox(width: 4),
                const Text('View conversation', style: TextStyle(color: _textSec, fontSize: 11)),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded, color: _textSec, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(Map<String, dynamic> ticket) {
    Navigator.push(context, _fadeRoute(_TicketAdminDetail(ticket: ticket, onRefresh: _load)));
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TICKET DETAIL / CHAT
// ══════════════════════════════════════════════════════════════════════════════

class _TicketAdminDetail extends StatefulWidget {
  final Map<String, dynamic> ticket;
  final VoidCallback onRefresh;
  const _TicketAdminDetail({required this.ticket, required this.onRefresh});
  @override
  State<_TicketAdminDetail> createState() => _TicketAdminDetailState();
}

class _TicketAdminDetailState extends State<_TicketAdminDetail> {
  // ── Palette ──────────────────────────────────────────────────────────────
  static const Color _bg      = Color(0xFFF7F8FA);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _primary = Color(0xFF1A1A2E);
  static const Color _accent  = Color(0xFF0066FF);
  static const Color _border  = Color(0xFFE8ECF0);
  static const Color _textPri = Color(0xFF0D0D0D);
  static const Color _textSec = Color(0xFF8A94A6);
  static const Color _green   = Color(0xFF00C48C);
  static const Color _orange  = Color(0xFFFF8C42);

  final _replyCtrl = TextEditingController();
  List<dynamic> _messages = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() { super.initState(); _loadMessages(); }

  @override
  void dispose() { _replyCtrl.dispose(); super.dispose(); }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    try {
      final r = await ApiService.getTicketMessages(widget.ticket['id'].toString());
      setState(() { _messages = r; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ApiService.replyToTicket(widget.ticket['id'], text);
      _replyCtrl.clear();
      await _loadMessages();
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
  }

  Future<void> _resolve() async {
    await ApiService.resolveTicket(widget.ticket['id']);
    widget.onRefresh();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final status   = widget.ticket['status'] ?? 'OPEN';
    final resolved = status == 'RESOLVED' || status == 'CLOSED';

    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(status, resolved),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildMessages()),
          _buildReplyBar(),
        ],
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(String status, bool resolved) {
    return AppBar(
      backgroundColor: _surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      bottom: const PreferredSize(
        preferredSize: Size.fromHeight(1),
        child: Divider(height: 1, color: _border),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _primary, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.ticket['ticketNumber'] ?? 'Ticket',
            style: const TextStyle(
              color: _textPri,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          Text(status, style: TextStyle(color: resolved ? _green : _orange, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
      actions: [
        if (!resolved)
          GestureDetector(
            onTap: _resolve,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _green.withOpacity(0.10),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _green.withOpacity(0.30)),
              ),
              child: const Text(
                'Resolve',
                style: TextStyle(color: _green, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }

  // ── Ticket info header ────────────────────────────────────────────────────
  Widget _buildHeader() {
    final category = widget.ticket['category'] ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (category.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(category, style: const TextStyle(color: _accent, fontSize: 10, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            widget.ticket['subject'] ?? '',
            style: const TextStyle(
              color: _textPri,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.ticket['description'] ?? '',
            style: const TextStyle(color: _textSec, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ── Message list ──────────────────────────────────────────────────────────
  Widget _buildMessages() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _accent, strokeWidth: 2));
    }
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: _accent.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.forum_outlined, color: _accent, size: 22),
            ),
            const SizedBox(height: 10),
            const Text('No messages yet', style: TextStyle(color: _textSec, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final m       = _messages[i];
        final isAdmin = m['senderType'] == 'ADMIN';
        return _messageBubble(m, isAdmin);
      },
    );
  }

  Widget _messageBubble(Map<String, dynamic> m, bool isAdmin) {
    return Align(
      alignment: isAdmin ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          color: isAdmin ? _accent : _surface,
          borderRadius: BorderRadius.only(
            topLeft:     const Radius.circular(14),
            topRight:    const Radius.circular(14),
            bottomLeft:  Radius.circular(isAdmin ? 14 : 3),
            bottomRight: Radius.circular(isAdmin ? 3 : 14),
          ),
          border: isAdmin ? null : Border.all(color: _border),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAdmin ? 'Admin' : 'User',
              style: TextStyle(
                color: isAdmin ? Colors.white.withOpacity(0.70) : _orange,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              m['message'] ?? '',
              style: TextStyle(
                color: isAdmin ? Colors.white : _textPri,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Reply bar ─────────────────────────────────────────────────────────────
  Widget _buildReplyBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: TextField(
                controller: _replyCtrl,
                style: const TextStyle(color: _textPri, fontSize: 14),
                maxLines: null,
                decoration: const InputDecoration(
                  hintText: 'Write a reply…',
                  hintStyle: TextStyle(color: _textSec, fontSize: 14),
                  filled: true,
                  fillColor: Colors.white,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onSubmitted: (_) => _sendReply(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _sending
              ? const SizedBox(
                  width: 44, height: 44,
                  child: Center(child: CircularProgressIndicator(color: _accent, strokeWidth: 2)),
                )
              : GestureDetector(
                  onTap: _sendReply,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  ),
                ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
PageRoute _fadeRoute(Widget page) {
  return PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (_, anim, __, child) =>
        FadeTransition(opacity: anim, child: child),
  );
}