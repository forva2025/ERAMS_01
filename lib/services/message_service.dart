import '../models/chat_message.dart';
import '../models/conversation.dart';
import 'supabase_service.dart';

class MessageService {
  Stream<List<ChatMessage>> streamMessages(String incidentId) {
    return supabaseClient
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('incident_id', incidentId)
        .order('created_at', ascending: true)
        .map((data) =>
            data.map(ChatMessage.fromJson).toList());
  }

  Future<void> sendMessage(String incidentId, String body) async {
    await supabaseClient.from('messages').insert({
      'incident_id': incidentId,
      'sender_id': supabaseClient.auth.currentUser!.id,
      'body': body.trim(),
    });
  }

  // Chat-list: one row per incident the current user has a conversation in,
  // ordered by most-recent message. The counterpart name/role is resolved
  // server-side based on the caller's role (driver→patient, patient→driver).
  Future<List<Conversation>> listConversations() async {
    final rows = await supabaseClient.rpc('list_conversations') as List;
    return rows
        .map((r) => Conversation.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  // Marks all messages in an incident (sent by others) as seen by current user.
  Future<void> markSeen(String incidentId) async {
    try {
      await supabaseClient.rpc(
        'mark_messages_seen',
        params: {'p_incident_id': incidentId},
      );
    } catch (_) {
      // Non-fatal: ticks are cosmetic, never block the UI.
    }
  }
}
