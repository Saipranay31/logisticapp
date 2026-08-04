import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ride_provider.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

class DriverChatScreen extends StatefulWidget {
  const DriverChatScreen({super.key});
  @override
  State<DriverChatScreen> createState() => _DriverChatScreenState();
}

class _DriverChatScreenState extends State<DriverChatScreen> {
  // ─── Theme tokens ──────────────────────────────────────────────────────────
  static const _bg           = Color(0xFFF5F5F7);
  static const _white        = Color(0xFFFFFFFF);
  static const _primary      = Color(0xFF1A1A2E);
  static const _accent       = Color(0xFFFF6B35);
  static const _textPrimary  = Color(0xFF1A1A1A);
  static const _textSecondary= Color(0xFF757575);
  static const _textHint     = Color(0xFFBBBBBB);
  static const _divider      = Color(0xFFEEEEEE);
  static const _cardShadow   = Color(0x10000000);

  // ─── All original state & logic — untouched ───────────────────────────────
  final _msgCtrl   = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  String? _rideId;
  String? _userName;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_rideId == null) {
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
      _rideId    = args['rideId']?.toString();
      _userName  = args['userName'] ?? 'Customer';

      if (_rideId == null) {
        final ride = Provider.of<RideProvider>(context, listen: false).currentRide;
        _rideId   = ride?['id']?.toString();
        _userName = ride?['userName'] ?? 'Customer';
      }

      _loadMessages();
      _subscribeToChatUpdates();
    }
  }

  Future<void> _loadMessages() async {
    if (_rideId == null) return;
    try {
      final msgs = await ApiService.getChatMessages(_rideId!);
      if (mounted) {
        setState(() { _messages = msgs; _isLoading = false; });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeToChatUpdates() {
    if (_rideId == null) return;
    try {
      WebSocketService.subscribeToChatMessages(_rideId!, (data) {
        if (mounted && data is Map<String, dynamic>) {
          final msgContent = data['message']?.toString();
          final senderRole = data['senderRole']?.toString();
          if (senderRole == 'DRIVER') {
            _messages.removeWhere((m) =>
                m['id']?.toString().startsWith('_temp_') == true &&
                m['message'] == msgContent);
          }
          final msgId = data['id']?.toString();
          if (msgId != null && !_messages.any((m) => m['id']?.toString() == msgId)) {
            setState(() => _messages.add(data));
            _scrollToBottom();
          } else if (senderRole == 'DRIVER') {
            setState(() {});
          }
        }
      });
    } catch (e) {
      print('⚠️ Chat WebSocket subscription failed: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _isSending = false;

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _rideId == null || _isSending) return;
    _isSending = true;
    _msgCtrl.clear();

    final tempId  = '_temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = {
      'id': tempId,
      'senderRole': 'DRIVER',
      'message': text,
      'timestamp': DateTime.now().toIso8601String(),
    };
    setState(() => _messages.add(tempMsg));
    _scrollToBottom();

    try {
      await ApiService.sendChatMessage(_rideId!, text, 'DRIVER');
    } catch (e) {
      setState(() => _messages.removeWhere((m) => m['id'] == tempId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e'),
              backgroundColor: Colors.red));
      }
    } finally {
      _isSending = false;
    }
  }

  @override
  void dispose() {
    if (_rideId != null) WebSocketService.unsubscribe('ride/$_rideId/chat');
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar(),
      body: Column(children: [
        Expanded(child: _body()),
        _inputBar(),
      ]),
    );
  }

  // ─── AppBar ────────────────────────────────────────────────────────────────
  PreferredSizeWidget _appBar() {
    final initial = (_userName != null && _userName!.isNotEmpty)
        ? _userName![0].toUpperCase()
        : 'C';
    return AppBar(
      backgroundColor: _white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: _textPrimary, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(children: [
        // Avatar
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _accent.withOpacity(0.10),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(initial,
                style: const TextStyle(
                    color: _accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
          ),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_userName ?? 'Customer',
              style: const TextStyle(
                  color: _textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2)),
          const SizedBox(height: 1),
          Row(children: [
            Container(
              width: 6, height: 6,
              decoration: const BoxDecoration(
                  color: Color(0xFF00C853), shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            const Text('In-ride chat',
                style: TextStyle(
                    color: _textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
          ]),
        ]),
      ]),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _divider),
      ),
    );
  }

  // ─── Body ──────────────────────────────────────────────────────────────────
  Widget _body() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: _accent, strokeWidth: 2.5));
    }
    if (_messages.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.07),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded,
                color: _accent, size: 32),
          ),
          const SizedBox(height: 16),
          const Text('No messages yet',
              style: TextStyle(
                  color: _textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text('Send a message to the customer',
              style: TextStyle(color: _textSecondary, fontSize: 13)),
        ]),
      );
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final prev = i > 0 ? _messages[i - 1] : null;
        return _bubble(_messages[i], prev);
      },
    );
  }

  // ─── Bubble ────────────────────────────────────────────────────────────────
  Widget _bubble(Map<String, dynamic> msg, Map<String, dynamic>? prev) {
    final isMe = msg['senderRole'] == 'DRIVER';
    final prevSame = prev != null && prev['senderRole'] == msg['senderRole'];
    final isTemp = msg['id']?.toString().startsWith('_temp_') == true;

    return Padding(
      padding: EdgeInsets.only(bottom: 4, top: prevSame ? 0 : 10),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Sender label — only when sender changes
          if (!prevSame)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 2, right: 2),
              child: Text(
                isMe ? 'You' : (_userName ?? 'Customer'),
                style: TextStyle(
                    color: isMe ? _accent : _textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3),
              ),
            ),

          Row(
            mainAxisAlignment:
                isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Customer avatar
              if (!isMe && !prevSame) ...[
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      (_userName != null && _userName!.isNotEmpty)
                          ? _userName![0].toUpperCase()
                          : 'C',
                      style: const TextStyle(
                          color: _primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ] else if (!isMe) ...[
                const SizedBox(width: 34),
              ],

              // Bubble
              ConstrainedBox(
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.70),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isMe ? _primary : _white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 4),
                      bottomRight: Radius.circular(isMe ? 4 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isMe
                            ? _primary.withOpacity(0.15)
                            : _cardShadow,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: isMe
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Text(msg['message'] ?? '',
                          style: TextStyle(
                              color: isMe ? _white : _textPrimary,
                              fontSize: 14,
                              height: 1.4)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(msg['timestamp'] ?? msg['createdAt']),
                            style: TextStyle(
                                color: isMe
                                    ? Colors.white.withOpacity(0.45)
                                    : _textHint,
                                fontSize: 10),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            Icon(
                              isTemp
                                  ? Icons.access_time_rounded
                                  : Icons.done_all_rounded,
                              size: 12,
                              color: isTemp
                                  ? Colors.white.withOpacity(0.35)
                                  : _accent,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Driver avatar
              if (isMe && !prevSame) ...[
                const SizedBox(width: 6),
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: _accent, size: 15),
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

  // ─── Input bar ─────────────────────────────────────────────────────────────
  Widget _inputBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 10, 12, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: _white,
        border: const Border(top: BorderSide(color: _divider, width: 1)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, -3)),
        ],
      ),
      child: Row(children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              controller: _msgCtrl,
              style: const TextStyle(color: _textPrimary, fontSize: 14),
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: _textHint, fontSize: 13),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _sendMessage,
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: _primary.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: const Icon(Icons.send_rounded,
                color: Colors.white, size: 19),
          ),
        ),
      ]),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  String _formatTime(dynamic ts) {
    try {
      final dt = ts is String ? DateTime.parse(ts) : DateTime.now();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}