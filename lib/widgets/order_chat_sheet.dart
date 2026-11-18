import 'package:flutter/material.dart';
import '../models/delivery_order.dart';
import '../models/order_message.dart';
import '../services/chat_read_tracker.dart';
import '../services/supabase_service.dart';
import 'responsive_shell.dart';

class OrderChatSheet extends StatefulWidget {
  final DeliveryOrder order;
  final bool isRunner;
  final OrderCounterpartInfo? counterpart;

  const OrderChatSheet({
    super.key,
    required this.order,
    required this.isRunner,
    this.counterpart,
  });

  static Future<void> show(
    BuildContext context, {
    required DeliveryOrder order,
    required bool isRunner,
    OrderCounterpartInfo? counterpart,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OrderChatSheet(
        order: order,
        isRunner: isRunner,
        counterpart: counterpart,
      ),
    );
  }

  @override
  State<OrderChatSheet> createState() => _OrderChatSheetState();
}

class _OrderChatSheetState extends State<OrderChatSheet> {
  static const Color primaryMaroon = Color(0xFF7F0000);
  static const Color goldAccent = Color(0xFFD4AF37);

  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late Stream<List<OrderMessage>> _messagesStream;
  OrderCounterpartInfo? _counterpart;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _counterpart = widget.counterpart;
    _messagesStream = SupabaseService().streamOrderMessages(widget.order.id);
    if (_counterpart == null) {
      _loadCounterpart();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ChatReadTracker.instance.markRead(
        widget.order.id,
        isRunner: widget.isRunner,
      );
    });
  }

  Future<void> _loadCounterpart() async {
    final info = await SupabaseService().fetchOrderCounterpart(widget.order.id);
    if (info != null && mounted) {
      setState(() => _counterpart = info);
    }
  }

  void _showIdPreviewDialog() {
    final info = _counterpart;
    if (info == null) return;
    final roleLabel = widget.isRunner ? 'Customer' : 'Runner';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.verified_user, color: primaryMaroon, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                info.displayName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              info.studentId.isNotEmpty
                  ? '$roleLabel  •  ID: ${info.studentId}'
                  : roleLabel,
              style: const TextStyle(fontSize: 12.5, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            if (info.idPhotoUrl != null && info.idPhotoUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  info.idPhotoUrl!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Padding(
                    padding: EdgeInsets.all(20),
                    child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.badge_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 6),
                    Text('No ID photo available.', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _retryStream() {
    setState(() {
      _messagesStream = SupabaseService().streamOrderMessages(widget.order.id);
    });
  }

  List<String> get _quickChips => widget.isRunner
      ? [
          "👋 Hello! Heading to the stall now.",
          "🍲 I'm purchasing your items.",
          "⚠️ Item out of stock, substitute?",
          "🛵 En route to your drop-off!",
          "📍 Arrived at drop-off lobby!",
        ]
      : [
          "👋 Hi runner, thanks for claiming!",
          "🙏 Please ask for utensils & sauce.",
          "📍 I'm waiting near the entrance.",
          "💵 Paying with exact cash.",
          "📱 Paying via GCash.",
        ];

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? prefilledText]) async {
    final text = (prefilledText ?? _textController.text).trim();
    if (text.isEmpty || _isSending) return;

    if (prefilledText == null) {
      _textController.clear();
    }

    setState(() => _isSending = true);

    try {
      final service = SupabaseService();
      final isOnlineOrder =
          !widget.order.id.startsWith('ORD-') && service.isAuthenticated;

      if (isOnlineOrder) {
        final currentUid = service.currentUser?.id;
        final isOrderCustomer =
            currentUid != null && widget.order.customerId == currentUid;
        final isOrderRunner =
            currentUid != null && widget.order.runnerId == currentUid;

        if (widget.isRunner && !isOrderRunner) {
          throw Exception(
            isOrderCustomer
                ? 'Your browser session switched to the Customer account in another tab. Use a separate browser or Incognito window to chat as both Customer and Runner.'
                : 'Your active login session does not match the assigned Runner for this order. Please refresh or sign back in.',
          );
        }
        if (!widget.isRunner && !isOrderCustomer) {
          throw Exception(
            isOrderRunner
                ? 'Your browser session switched to the Runner account in another tab. Use a separate browser or Incognito window to chat as both Customer and Runner.'
                : 'Your active login session does not match the Customer for this order. Please refresh or sign back in.',
          );
        }
      }

      final role = widget.isRunner ? 'runner' : 'customer';
      final currentUid = service.currentUser?.id;
      final cachedMatches =
          service.cachedProfile != null && service.cachedProfile!.id == currentUid;
      final metaName = service.currentUser?.userMetadata?['full_name']?.toString().trim();
      final senderName = cachedMatches && service.cachedProfile!.fullName.isNotEmpty
          ? service.cachedProfile!.fullName
          : (metaName != null && metaName.isNotEmpty
              ? metaName
              : (widget.isRunner ? 'Runner' : 'Customer'));

      await service.sendOrderMessage(
        orderId: widget.order.id,
        message: text,
        senderRole: role,
        senderName: senderName,
      );
      _scrollToBottom();
    } catch (e) {
      if (prefilledText == null && _textController.text.isEmpty) {
        _textController.text = text;
        _textController.selection = TextSelection.fromPosition(
          TextPosition(offset: text.length),
        );
      }
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Could not send message: $msg'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isKeyboardOpen = media.viewInsets.bottom > 0;
    final otherRoleLabel = widget.isRunner ? 'Customer' : 'Runner';
    final shortOrderId = widget.order.id.length > 8
        ? widget.order.id.substring(0, 8)
        : widget.order.id;

    return Container(
      height: media.size.height * (isKeyboardOpen ? 0.88 : 0.78),
      decoration: BoxDecoration(
        color: DDartTheme.card(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag Handle
          const SizedBox(height: 10),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: DDartTheme.divider(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: DDartTheme.border(context))),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _counterpart != null ? _showIdPreviewDialog : null,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryMaroon,
                      border: Border.all(
                        color: primaryMaroon.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    child: ClipOval(
                      child: _counterpart?.idPhotoUrl != null &&
                              _counterpart!.idPhotoUrl!.isNotEmpty
                          ? Image.network(
                              _counterpart!.idPhotoUrl!,
                              fit: BoxFit.cover,
                              alignment: const Alignment(-0.55, -0.35),
                              errorBuilder: (_, _, _) => Icon(
                                widget.isRunner ? Icons.person : Icons.directions_run,
                                color: Colors.white,
                                size: 22,
                              ),
                            )
                          : Icon(
                              widget.isRunner ? Icons.person : Icons.directions_run,
                              color: Colors.white,
                              size: 22,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _counterpart?.displayName ?? 'Chat with $otherRoleLabel',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E1E1E),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: primaryMaroon.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '#$shortOrderId',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: primaryMaroon,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${otherRoleLabel.toUpperCase()}  •  ${widget.order.status.toUpperCase()}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close chat',
                  icon: const Icon(Icons.close, color: Colors.black54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Delivery summary route banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade50,
            child: Row(
              children: [
                const Icon(Icons.storefront, size: 15, color: primaryMaroon),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    widget.order.pickupLocation,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Icon(Icons.arrow_forward, size: 13, color: Colors.black38),
                ),
                const Icon(Icons.location_on, size: 15, color: goldAccent),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    widget.order.dropoffLocation,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Messages List Stream
          Expanded(
            child: StreamBuilder<List<OrderMessage>>(
              stream: _messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_off_outlined,
                            size: 44,
                            color: Colors.red.shade300,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Could not load chat messages',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _retryStream,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: primaryMaroon),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ChatReadTracker.instance.markRead(
                      widget.order.id,
                      isRunner: widget.isRunner,
                      upTo: messages.last.createdAt,
                    );
                  });
                }

                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No messages yet',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            widget.isRunner
                                ? 'Send an update to the customer about their errand.'
                                : 'Coordinate with your runner or send instructions.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                _scrollToBottom();

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = widget.isRunner
                        ? msg.isRunner
                        : msg.isCustomer;

                    return _buildMessageBubble(msg, isMe);
                  },
                );
              },
            ),
          ),

          // Quick Preset Chips
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _quickChips.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final chip = _quickChips[i];
                return ActionChip(
                  label: Text(
                    chip,
                    style: TextStyle(fontSize: 11.5, color: DDartTheme.accentText(context)),
                  ),
                  backgroundColor: DDartTheme.maroonTint(context),
                  side: BorderSide(color: DDartTheme.accentText(context).withValues(alpha: 0.25)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  onPressed: () => _sendMessage(chip),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Text Input Bar
          Container(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 8,
              bottom: media.viewInsets.bottom + 10,
            ),
            decoration: BoxDecoration(
              color: DDartTheme.card(context),
              border: Border(top: BorderSide(color: DDartTheme.border(context))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: DDartTheme.cardSubtle(context),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: DDartTheme.border(context)),
                    ),
                    child: TextField(
                      controller: _textController,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(fontSize: 13.5),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 20,
                  backgroundColor: primaryMaroon,
                  child: IconButton(
                    icon: _isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: _isSending ? null : () => _sendMessage(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(OrderMessage msg, bool isMe) {
    final isDark = DDartTheme.isDark(context);
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              Text(
                msg.senderName.isNotEmpty
                    ? msg.senderName
                    : (msg.isRunner ? 'Runner' : 'Customer'),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: DDartTheme.accentText(context),
                ),
              ),
              const SizedBox(height: 3),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? primaryMaroon
                    : (isDark ? const Color(0xFF2B2B32) : const Color(0xFFF1F3F5)),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  bottomLeft: Radius.circular(isMe ? 14 : 2),
                  bottomRight: Radius.circular(isMe ? 2 : 14),
                ),
              ),
              child: Text(
                msg.message,
                style: TextStyle(
                  fontSize: 13.5,
                  color: isMe ? Colors.white : DDartTheme.textPrimary(context),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              msg.formattedTime(),
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
