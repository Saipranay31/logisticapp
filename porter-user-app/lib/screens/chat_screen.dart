import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  // ── Colors (same system) ───────────────────────────────────
  static const Color _black = Color(0xFF0A0A0A);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _surface = Color(0xFFF7F7F7);
  static const Color _divider = Color(0xFFEEEEEE);
  static const Color _hint = Color(0xFF9E9E9E);
  static const Color _primaryText = Color(0xFF1A1A1A);
  static const Color _green = Color(0xFF00C853);

  // ── State (UNCHANGED logic) ────────────────────────────────
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _rideId;
  String? _driverName;
  String? _userId;

  late AnimationController _inputAnim;
  late Animation<double> _inputFade;

  @override
  void initState() {
    super.initState();
    _inputAnim = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300),
    );
    _inputFade = CurvedAnimation(parent: _inputAnim, curve: Curves.easeOut);
    _inputAnim.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_rideId == null) {
      final args = ModalRoute.of(context)?.settings.arguments
          as Map<String, dynamic>? ?? {};
      _rideId = args['rideId']?.toString();
      _driverName = args['driverName'] ?? 'Driver';
      _userId = Provider.of<AuthProvider>(context, listen: false).userId;
      _loadMessages();
      _subscribeToChatUpdates();
    }
  }

  // ── Logic (UNCHANGED) ──────────────────────────────────────
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
          if (senderRole == 'USER') {
            _messages.removeWhere((m) =>
                m['id']?.toString().startsWith('_temp_') == true &&
                m['message'] == msgContent);
          }
          final msgId = data['id']?.toString();
          if (msgId != null &&
              !_messages.any((m) => m['id']?.toString() == msgId)) {
            setState(() => _messages.add(data));
            _scrollToBottom();
          } else if (senderRole == 'USER') {
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

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _rideId == null || _isSending) return;
    _isSending = true;
    _msgCtrl.clear();
    HapticFeedback.lightImpact();

    final tempId = '_temp_${DateTime.now().millisecondsSinceEpoch}';
    setState(() => _messages.add({
      'id': tempId,
      'senderId': _userId,
      'senderRole': 'USER',
      'message': text,
      'timestamp': DateTime.now().toIso8601String(),
    }));
    _scrollToBottom();

    try {
      await ApiService.sendChatMessage(_rideId!, text, 'USER');
    } catch (e) {
      setState(() => _messages.removeWhere((m) => m['id'] == tempId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to send: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
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
    _inputAnim.dispose();
    super.dispose();
  }

  String _formatTime(dynamic ts) {
    try {
      final dt = ts is String ? DateTime.parse(ts) : DateTime.now();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }

  // ── UI ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _surface,
        body: Column(
          children: [
            _buildTopBar(),
            Expanded(child: _buildMessageArea()),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      color: _white,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 12, left: 8, right: 16,
      ),
      decoration: BoxDecoration(
        color: _white,
        border: Border(bottom: BorderSide(color: _divider, width: 1)),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _surface, borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: _black, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          // Driver avatar
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: _black, shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                (_driverName ?? 'D').isNotEmpty
                    ? (_driverName!)[0].toUpperCase()
                    : 'D',
                style: const TextStyle(
                  color: _white, fontSize: 17, fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Driver info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _driverName ?? 'Driver',
                  style: const TextStyle(
                    color: _primaryText, fontSize: 15,
                    fontWeight: FontWeight.w800, letterSpacing: -0.3,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: _green, shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'In-ride chat',
                      style: TextStyle(color: _hint, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Call hint button
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _divider),
            ),
            child: const Icon(Icons.phone_rounded, color: _black, size: 17),
          ),
        ],
      ),
    );
  }

  // ── Message area ───────────────────────────────────────────
  Widget _buildMessageArea() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _black, strokeWidth: 2.5),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: _white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16, offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded, color: _hint, size: 30,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No messages yet',
              style: TextStyle(
                color: _primaryText, fontSize: 16, fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Send a message to your driver',
              style: TextStyle(color: _hint, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollCtrl,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      itemCount: _messages.length,
      itemBuilder: (_, i) {
        final showDateSep = i == 0 ||
            _isDifferentDay(_messages[i - 1]['timestamp'], _messages[i]['timestamp']);
        return Column(
          children: [
            if (showDateSep) _buildDateSeparator(_messages[i]['timestamp']),
            _buildMessageBubble(_messages[i]),
          ],
        );
      },
    );
  }

  // ── Date separator ─────────────────────────────────────────
  Widget _buildDateSeparator(dynamic ts) {
    String label = 'Today';
    try {
      final dt = ts is String ? DateTime.parse(ts) : DateTime.now();
      const months = ['Jan','Feb','Mar','Apr','May','Jun',
                      'Jul','Aug','Sep','Oct','Nov','Dec'];
      label = '${dt.day} ${months[dt.month - 1]}';
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Container(height: 1, color: _divider)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: const TextStyle(
                color: _hint, fontSize: 11, fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(child: Container(height: 1, color: _divider)),
        ],
      ),
    );
  }

  bool _isDifferentDay(dynamic ts1, dynamic ts2) {
    try {
      final d1 = DateTime.parse(ts1.toString());
      final d2 = DateTime.parse(ts2.toString());
      return d1.day != d2.day || d1.month != d2.month;
    } catch (_) { return false; }
  }

  // ── Message bubble ─────────────────────────────────────────
  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final isMe = msg['senderRole'] == 'USER';
    final isTemp = msg['id']?.toString().startsWith('_temp_') == true;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? _black : _white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: isMe
                      ? const Radius.circular(18)
                      : const Radius.circular(4),
                  bottomRight: isMe
                      ? const Radius.circular(4)
                      : const Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isMe ? 0.12 : 0.05),
                    blurRadius: 8, offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg['message'] ?? '',
                style: TextStyle(
                  color: isMe ? _white : _primaryText,
                  fontSize: 14, height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(msg['timestamp'] ?? msg['createdAt']),
                  style: const TextStyle(color: _hint, fontSize: 10),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    isTemp
                        ? Icons.access_time_rounded
                        : Icons.done_all_rounded,
                    size: 12,
                    color: isTemp ? _hint : _green,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Input bar ──────────────────────────────────────────────
  Widget _buildInputBar() {
    return FadeTransition(
      opacity: _inputFade,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          16, 10, 12, MediaQuery.of(context).padding.bottom + 10,
        ),
        decoration: BoxDecoration(
          color: _white,
          border: Border(top: BorderSide(color: _divider, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12, offset: const Offset(0, -3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Text input
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _divider, width: 1),
                ),
                child: TextField(
                  controller: _msgCtrl,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  style: const TextStyle(
                    color: _primaryText, fontSize: 14, height: 1.4,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Message driver…',
                    hintStyle: TextStyle(color: _hint, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Send button
            GestureDetector(
              onTap: _sendMessage,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: _black,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _black.withOpacity(0.2),
                      blurRadius: 8, offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: _isSending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          color: _white, strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.arrow_upward_rounded,
                        color: _white, size: 20,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}