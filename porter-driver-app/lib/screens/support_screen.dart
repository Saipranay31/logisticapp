import 'package:flutter/material.dart';
import '../services/api_service.dart';

// ─── Design Tokens (matches home screen palette) ──────────────────────────────
class _T {
  static const bg            = Color(0xFFF5F5F7);
  static const white         = Color(0xFFFFFFFF);
  static const primary       = Color(0xFF1A1A2E);
  static const accent        = Color(0xFFFF6B35);
  static const green         = Color(0xFF00C853);
  static const textPrimary   = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF757575);
  static const textHint      = Color(0xFFBBBBBB);
  static const cardShadow    = Color(0x10000000);
  static const divider       = Color(0xFFEEEEEE);
  static const surface       = Color(0xFFFFFFFF);
}

// ══════════════════════════════════════════════════════════════════════════════
//  SUPPORT SCREEN — Ticket List
// ══════════════════════════════════════════════════════════════════════════════
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen>
    with SingleTickerProviderStateMixin {
  List<dynamic> _tickets = [];
  bool _loading = true;

  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.03), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getSupportTickets();
      setState(() => _tickets = res);
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _T.bg,
      appBar: _appBar(),
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: _T.accent, strokeWidth: 2.5))
              : _tickets.isEmpty
                  ? _emptyState()
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: _T.accent,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        children: [
                          _sectionHeader(),
                          const SizedBox(height: 12),
                          ..._tickets.map((t) => _ticketCard(t)),
                        ],
                      ),
                    ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreate,
        backgroundColor: _T.primary,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
        label: const Text('New Ticket',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.2)),
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    return AppBar(
      backgroundColor: _T.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: _T.textPrimary, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text('Help & Support',
          style: TextStyle(
              color: _T.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3)),
      centerTitle: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _T.divider),
      ),
    );
  }

  Widget _sectionHeader() {
    return Row(
      children: [
        const Text('MY TICKETS',
            style: TextStyle(
                color: _T.textSecondary,
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700)),
        const Spacer(),
        Text('${_tickets.length} total',
            style: const TextStyle(
                color: _T.textHint, fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _ticketCard(Map<String, dynamic> t) {
    final status = (t['status'] ?? 'OPEN').toString().toUpperCase();
    final isResolved = status == 'RESOLVED' || status == 'CLOSED';
    final statusColor = isResolved ? _T.green : _T.accent;
    final statusBg = statusColor.withOpacity(0.09);

    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => _TicketDetailScreen(ticket: t))).then((_) => _load()),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _T.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: _T.cardShadow, blurRadius: 12, offset: Offset(0, 3))
          ],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Icon badge
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isResolved
                  ? Icons.check_circle_outline_rounded
                  : Icons.support_agent_rounded,
              color: statusColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(t['subject'] ?? 'Support Request',
                          style: const TextStyle(
                              color: _T.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(status,
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6)),
                    ),
                  ]),
                  const SizedBox(height: 5),
                  Text(t['description'] ?? '',
                      style: const TextStyle(
                          color: _T.textSecondary,
                          fontSize: 12,
                          height: 1.4),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.confirmation_number_outlined,
                        size: 11, color: _T.textHint),
                    const SizedBox(width: 4),
                    Text(t['ticketNumber'] ?? '',
                        style: const TextStyle(
                            color: _T.textHint,
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded,
                        size: 16, color: _T.textHint),
                  ]),
                ]),
          ),
        ]),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: _T.accent.withOpacity(0.07),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.headset_mic_outlined,
              size: 36, color: _T.accent),
        ),
        const SizedBox(height: 18),
        const Text('No tickets yet',
            style: TextStyle(
                color: _T.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Raise a ticket and our team\nwill get back to you shortly',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: _T.textSecondary, fontSize: 13, height: 1.5)),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _showCreate,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
            decoration: BoxDecoration(
              color: _T.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('Raise a Ticket',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
          ),
        ),
      ]),
    );
  }

  // ─── Create Ticket Bottom Sheet ──────────────────────────────────────────
  void _showCreate() {
    final subCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _T.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _T.textHint.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _T.accent.withOpacity(0.09),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.support_agent_rounded,
                  color: _T.accent, size: 18),
            ),
            const SizedBox(width: 12),
            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('New Support Ticket',
                  style: TextStyle(
                      color: _T.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              Text('We respond within 24 hours',
                  style: TextStyle(color: _T.textSecondary, fontSize: 11)),
            ]),
          ]),
          const SizedBox(height: 20),
          _field(subCtrl, 'Subject', Icons.title_rounded),
          const SizedBox(height: 12),
          _field(descCtrl, 'Describe your issue in detail...',
              Icons.description_outlined,
              maxLines: 4),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () async {
                if (subCtrl.text.isEmpty) return;
                Navigator.pop(ctx);
                await ApiService.createSupportTicket(
                    subject: subCtrl.text,
                    description: descCtrl.text,
                    category: 'DRIVER');
                _load();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _T.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Submit Ticket',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon,
      {int maxLines = 1}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      style: const TextStyle(
          color: _T.textPrimary, fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _T.textHint, fontSize: 13),
        prefixIcon: maxLines == 1
            ? Icon(icon, color: _T.textHint, size: 18)
            : null,
        filled: true,
        fillColor: _T.bg,
        contentPadding: EdgeInsets.symmetric(
            horizontal: maxLines > 1 ? 16 : 0, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: _T.accent, width: 1.5)),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TICKET DETAIL — Chat Thread
// ══════════════════════════════════════════════════════════════════════════════
class _TicketDetailScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;
  const _TicketDetailScreen({required this.ticket});

  @override
  State<_TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<_TicketDetailScreen> {
  final _mc = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<dynamic> _msgs = [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _mc.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await ApiService.getTicketMessages(
          widget.ticket['id'].toString());
      if (mounted) {
        setState(() {
          _msgs = r;
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _mc.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _mc.clear();
    try {
      await ApiService.addTicketMessage(widget.ticket['id'], text);
      await _load();
    } catch (_) {}
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final status = (widget.ticket['status'] ?? 'OPEN').toString().toUpperCase();
    final isResolved = status == 'RESOLVED' || status == 'CLOSED';

    return Scaffold(
      backgroundColor: _T.bg,
      appBar: _appBar(status, isResolved),
      body: Column(children: [
        // Ticket subject banner
        _subjectBanner(),
        // Messages
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(
                      color: _T.accent, strokeWidth: 2.5))
              : _msgs.isEmpty
                  ? _emptyChat()
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: _msgs.length,
                      itemBuilder: (_, i) {
                        final prev = i > 0 ? _msgs[i - 1] : null;
                        return _bubbleItem(_msgs[i], prev);
                      },
                    ),
        ),
        // Input bar
        if (!isResolved) _inputBar(),
        if (isResolved) _resolvedBar(),
      ]),
    );
  }

  PreferredSizeWidget _appBar(String status, bool isResolved) {
    return AppBar(
      backgroundColor: _T.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: _T.textPrimary, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.ticket['ticketNumber'] ?? 'Ticket',
            style: const TextStyle(
                color: _T.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2)),
        const SizedBox(height: 1),
        Row(children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isResolved ? _T.green : _T.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(status,
              style: TextStyle(
                  color: isResolved ? _T.green : _T.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5)),
        ]),
      ]),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _T.divider),
      ),
    );
  }

  Widget _subjectBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: _T.white,
      child: Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: _T.accent.withOpacity(0.09),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.confirmation_number_outlined,
              color: _T.accent, size: 15),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(widget.ticket['subject'] ?? '',
              style: const TextStyle(
                  color: _T.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }

  Widget _bubbleItem(Map<String, dynamic> m, Map<String, dynamic>? prev) {
    // ── BUG FIX ─────────────────────────────────────────────────────────────
    // Driver is the USER → align RIGHT (our bubble)
    // Admin/Support       → align LEFT  (their bubble)
    // Previously both could appear on same side due to ambiguous senderType.
    // Now we check for 'USER' | 'DRIVER' as "sent by me", everything else is
    // "support team" → left aligned.
    final senderType = (m['senderType'] ?? '').toString().toUpperCase();
    final isMe = senderType == 'USER' || senderType == 'DRIVER';
    // ────────────────────────────────────────────────────────────────────────

    final sameAsPrev = prev != null &&
        (prev['senderType'] ?? '').toString().toUpperCase() == senderType;

    return Padding(
      padding: EdgeInsets.only(
          bottom: 4,
          top: sameAsPrev ? 0 : 10),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Sender label (only show when sender changes)
          if (!sameAsPrev)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 2, right: 2),
              child: Text(
                isMe ? 'You' : 'Support Team',
                style: TextStyle(
                    color: isMe ? _T.accent : _T.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3),
              ),
            ),
          // Bubble
          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              // Support avatar (left side only)
              if (!isMe && !sameAsPrev) ...[
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: _T.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.support_agent_rounded,
                      size: 15, color: Colors.white),
                ),
                const SizedBox(width: 6),
              ] else if (!isMe) ...[
                const SizedBox(width: 34),
              ],

              // Message bubble
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? _T.primary : _T.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isMe
                            ? _T.primary.withOpacity(0.18)
                            : _T.cardShadow,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(m['message'] ?? '',
                      style: TextStyle(
                          color: isMe ? Colors.white : _T.textPrimary,
                          fontSize: 14,
                          height: 1.45)),
                ),
              ),

              // Driver avatar (right side only)
              if (isMe && !sameAsPrev) ...[
                const SizedBox(width: 6),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _T.accent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded,
                      size: 15, color: _T.accent),
                ),
              ] else if (isMe) ...[
                const SizedBox(width: 34),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyChat() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: _T.accent.withOpacity(0.07),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.chat_bubble_outline_rounded,
              size: 28, color: _T.accent),
        ),
        const SizedBox(height: 14),
        const Text('No messages yet',
            style: TextStyle(
                color: _T.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        const Text('Send a message to get started',
            style: TextStyle(color: _T.textSecondary, fontSize: 13)),
      ]),
    );
  }

  Widget _inputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 10, 12, MediaQuery.of(context).viewInsets.bottom + 12),
      decoration: BoxDecoration(
        color: _T.white,
        border: const Border(top: BorderSide(color: _T.divider, width: 1)),
      ),
      child: Row(children: [
        // Text input
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _T.bg,
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              controller: _mc,
              style: const TextStyle(
                  color: _T.textPrimary, fontSize: 14),
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: _T.textHint, fontSize: 13),
                filled: false,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Send button
        GestureDetector(
          onTap: _send,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _sending ? _T.textHint : _T.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _T.primary.withOpacity(0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: _sending
                ? const Padding(
                    padding: EdgeInsets.all(11),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded,
                    color: Colors.white, size: 19),
          ),
        ),
      ]),
    );
  }

  Widget _resolvedBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
      color: _T.green.withOpacity(0.08),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded, color: _T.green, size: 16),
          SizedBox(width: 8),
          Text('This ticket has been resolved',
              style: TextStyle(
                  color: _T.green,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}