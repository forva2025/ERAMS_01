import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_colors.dart';
import '../models/chat_message.dart';
import '../services/message_service.dart';
import '../services/supabase_service.dart';
import '../state/message_provider.dart';
import 'error_state.dart';

/// Opens the incident chat bottom sheet.
void showChatSheet(BuildContext context, String incidentId) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ChatSheet(incidentId: incidentId),
  );
}

// ── Chat sheet ─────────────────────────────────────────────────────────────────

class ChatSheet extends ConsumerStatefulWidget {
  final String incidentId;
  const ChatSheet({super.key, required this.incidentId});

  @override
  ConsumerState<ChatSheet> createState() => _ChatSheetState();
}

class _ChatSheetState extends ConsumerState<ChatSheet> {
  final _textController = TextEditingController();
  ScrollController? _listController;
  bool _sending = false;
  int _lastLength = 0;
  late final String _myId;

  @override
  void initState() {
    super.initState();
    _myId = supabaseClient.auth.currentUser?.id ?? '';
    // Mark existing messages as seen when chat opens.
    MessageService().markSeen(widget.incidentId);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    final ctrl = _listController;
    if (ctrl == null || !ctrl.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ctrl.hasClients) {
        ctrl.animateTo(
          ctrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    setState(() => _sending = true);
    try {
      await MessageService().sendMessage(widget.incidentId, text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(widget.incidentId));

    // Auto-scroll and mark seen on new messages.
    messagesAsync.whenData((messages) {
      if (messages.length != _lastLength) {
        _lastLength = messages.length;
        ref
            .read(chatSeenProvider.notifier)
            .markSeen(widget.incidentId, messages.length);
        MessageService().markSeen(widget.incidentId);
        _scrollToBottom();
      }
    });

    return DraggableScrollableSheet(
      initialChildSize: 0.70,
      maxChildSize: 0.95,
      minChildSize: 0.40,
      expand: false,
      builder: (ctx, scrollController) {
        _listController = scrollController;

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ── Handle + title ───────────────────────────────────
              _SheetHeader(onClose: () => Navigator.of(context).pop()),
              const Divider(height: 1),

              // ── Message list ─────────────────────────────────────
              Expanded(
                child: ColoredBox(
                  color: const Color(0xFFEAE6DF), // WhatsApp warm grey
                  child: messagesAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => ErrorRetryView(
                      error: e,
                      icon: Icons.chat_bubble_outline,
                      onRetry: () => ref
                          .invalidate(messagesProvider(widget.incidentId)),
                    ),
                    data: (messages) {
                      if (messages.isEmpty) return const _EmptyState();
                      return ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 12),
                        itemCount: messages.length,
                        itemBuilder: (_, i) {
                          final msg = messages[i];
                          final isMe = msg.isMe(_myId);
                          final showName = !isMe &&
                              (i == 0 ||
                                  messages[i - 1].senderId != msg.senderId);
                          return _MessageBubble(
                            message: msg,
                            isMe: isMe,
                            myId: _myId,
                            showName: showName,
                          );
                        },
                      );
                    },
                  ),
                ),
              ),

              // ── Input bar ────────────────────────────────────────
              _InputBar(
                controller: _textController,
                sending: _sending,
                onSend: _send,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _SheetHeader extends StatelessWidget {
  final VoidCallback onClose;
  const _SheetHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 10),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          const Icon(Icons.chat_bubble_outline,
              size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          const Text(
            'Incident Chat',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClose,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.textHint),
          SizedBox(height: 12),
          Text('No messages yet',
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 15)),
          SizedBox(height: 4),
          Text('Start the conversation',
              style: TextStyle(color: AppColors.textHint, fontSize: 12)),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border:
            Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Type a message…',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              onTap: sending ? null : onSend,
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Message bubble ─────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final String myId;
  final bool showName;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.myId,
    required this.showName,
  });

  // WhatsApp dark green for my own (sent) messages.
  static const _sentBg = Color(0xFF005C4B);

  // Received messages are tinted by the sender's role so a patient's
  // messages look visually distinct from a driver's, dispatcher's, etc.
  static Color _receivedBg(String role) => switch (role) {
        'driver'     => const Color(0xFFDCEBFF), // soft blue
        'patient'    => const Color(0xFFFFE3E0), // soft coral
        'dispatcher' => const Color(0xFFEDE1FF), // soft purple
        'hospital'   => const Color(0xFFD8F5EF), // soft teal
        _            => const Color(0xFFFFFFFF),
      };

  @override
  Widget build(BuildContext context) {
    // Row + Flexible is the canonical chat-bubble layout:
    //  • mainAxisAlignment pins the bubble to the correct side.
    //  • Flexible lets the bubble shrink-wrap short text yet wrap long text,
    //    capped at maxWidth so it never spans the whole screen.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Sender name (received messages only, first in a run).
                  if (!isMe && showName)
                    Padding(
                      padding: const EdgeInsets.only(left: 12, bottom: 2),
                      child: Text(
                        _senderLabel(message),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),

                  // Bubble.
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isMe
                          ? _sentBg
                          : _receivedBg(message.senderRole),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Message text.
                        Text(
                          message.body,
                          style: TextStyle(
                            color: isMe
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontSize: 14.5,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 3),
                        // Timestamp + tick (tick only on sent messages).
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              _formatTime(message.createdAt),
                              style: TextStyle(
                                fontSize: 10,
                                color: isMe
                                    ? Colors.white.withValues(alpha: 0.65)
                                    : AppColors.textHint,
                              ),
                            ),
                            if (isMe) ...[
                              const SizedBox(width: 3),
                              _ReadTick(
                                  isRead: message.isSeenByOthers(myId)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _senderLabel(ChatMessage msg) {
    final name = msg.senderName.isNotEmpty ? msg.senderName : 'Unknown';
    final tag = switch (msg.senderRole) {
      'driver'     => 'Driver',
      'dispatcher' => 'Dispatcher',
      'patient'    => 'Patient',
      'hospital'   => 'Hospital',
      _            => '',
    };
    return tag.isNotEmpty ? '$name ($tag)' : name;
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ── Read-receipt tick ──────────────────────────────────────────────────────────

class _ReadTick extends StatelessWidget {
  final bool isRead;
  const _ReadTick({required this.isRead});

  @override
  Widget build(BuildContext context) {
    if (isRead) {
      // Double blue — at least one other participant has opened the chat.
      return const Icon(Icons.done_all_rounded,
          size: 15, color: Color(0xFF53BDEB));
    }
    // Single white/grey — sent to server, nobody else has seen it yet.
    return const Icon(Icons.check_rounded, size: 15, color: Colors.white54);
  }
}

// ── Chat icon with unread badge ────────────────────────────────────────────────

/// Chat icon with a small red badge showing [unread] count (0 = no badge).
Widget chatIconWithBadge(int unread) {
  return Stack(
    clipBehavior: Clip.none,
    children: [
      Icon(
        unread > 0 ? Icons.chat_bubble : Icons.chat_bubble_outline,
        size: 20,
        color: unread > 0 ? AppColors.primary : AppColors.textSecondary,
      ),
      if (unread > 0)
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
            ),
            constraints:
                const BoxConstraints(minWidth: 14, minHeight: 14),
            child: Text(
              unread > 9 ? '9+' : '$unread',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 7,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
    ],
  );
}
