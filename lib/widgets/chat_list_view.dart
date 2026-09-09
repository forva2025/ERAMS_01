import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme/app_colors.dart';
import '../models/conversation.dart';
import '../services/supabase_service.dart';
import '../state/message_provider.dart';
import 'chat_sheet.dart';
import 'error_state.dart';

/// Opens the conversation-history list as a full-height bottom sheet.
/// Used by screens that don't have a dedicated Chats tab (e.g. patient home).
void showChatListSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(
                children: [
                  const Icon(Icons.forum_outlined,
                      size: 20, color: AppColors.primary),
                  const SizedBox(width: 10),
                  const Text('Chats',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 17)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ChatListView(scrollController: scrollController),
            ),
          ],
        ),
      ),
    ),
  );
}

/// A WhatsApp/Telegram-style conversation list.
/// Each row is one incident the current user is chatting in, showing the
/// counterpart's name, the last message, its time, and an unread badge.
/// Tapping a row opens the incident chat sheet.
class ChatListView extends ConsumerStatefulWidget {
  final ScrollController? scrollController;
  const ChatListView({super.key, this.scrollController});

  @override
  ConsumerState<ChatListView> createState() => _ChatListViewState();
}

class _ChatListViewState extends ConsumerState<ChatListView> {
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    // Refresh the list live whenever any message row changes.
    _channel = supabaseClient
        .channel('chatlist:messages')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (_) {
            if (mounted) ref.invalidate(conversationsProvider);
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _openChat(String incidentId) async {
    showChatSheet(context, incidentId);
    // When the chat closes, seen state has changed — refresh the list.
    ref.invalidate(conversationsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(conversationsProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => ErrorRetryView(
        error: e,
        icon: Icons.forum_outlined,
        onRetry: () => ref.invalidate(conversationsProvider),
      ),
      data: (conversations) {
        if (conversations.isEmpty) return const _EmptyChats();
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(conversationsProvider),
          child: ListView.separated(
            controller: widget.scrollController,
            itemCount: conversations.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 76),
            itemBuilder: (_, i) => _ConversationTile(
              conversation: conversations[i],
              onTap: () => _openChat(conversations[i].incidentId),
            ),
          ),
        );
      },
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;

  const _ConversationTile({required this.conversation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final hasUnread = c.unread > 0;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: _roleColor(c.otherRole).withValues(alpha: 0.15),
        child: Text(
          _initials(c.otherName),
          style: TextStyle(
            color: _roleColor(c.otherRole),
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              c.otherName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 15.5),
            ),
          ),
          if (c.lastAt != null)
            Text(
              _formatWhen(c.lastAt!),
              style: TextStyle(
                fontSize: 11.5,
                color: hasUnread ? AppColors.primary : AppColors.textHint,
                fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(
          children: [
            if (c.otherRole.isNotEmpty) ...[
              _RolePill(role: c.otherRole),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                c.lastBody.isEmpty ? 'No messages yet' : c.lastBody,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: hasUnread
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontWeight:
                      hasUnread ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (hasUnread) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                constraints:
                    const BoxConstraints(minWidth: 22, minHeight: 22),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  c.unread > 99 ? '99+' : '${c.unread}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Color _roleColor(String role) => switch (role) {
        'driver' => const Color(0xFF2E7D32),
        'dispatcher' => const Color(0xFF1565C0),
        'patient' => const Color(0xFFC62828),
        'hospital' => const Color(0xFF00796B),
        _ => Colors.blueGrey,
      };

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  static String _formatWhen(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(dt.year, dt.month, dt.day);
    final diffDays = today.difference(that).inDays;
    if (diffDays == 0) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    if (diffDays == 1) return 'Yesterday';
    if (diffDays < 7) {
      const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return names[dt.weekday - 1];
    }
    return '${dt.day}/${dt.month}/${dt.year % 100}';
  }
}

class _RolePill extends StatelessWidget {
  final String role;
  const _RolePill({required this.role});

  @override
  Widget build(BuildContext context) {
    final label = switch (role) {
      'driver' => 'Driver',
      'dispatcher' => 'Dispatcher',
      'patient' => 'Patient',
      'hospital' => 'Hospital',
      _ => role,
    };
    final color = _ConversationTile._roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

class _EmptyChats extends StatelessWidget {
  const _EmptyChats();

  @override
  Widget build(BuildContext context) {
    return ListView(
      // ListView so RefreshIndicator/pull works even when empty.
      children: const [
        SizedBox(height: 120),
        Icon(Icons.forum_outlined, size: 56, color: AppColors.textHint),
        SizedBox(height: 14),
        Center(
          child: Text('No conversations yet',
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 15)),
        ),
        SizedBox(height: 4),
        Center(
          child: Text('Chats appear here once a trip has a message',
              style: TextStyle(color: AppColors.textHint, fontSize: 12)),
        ),
      ],
    );
  }
}
