/// One row in the chat-list (conversation history) screen.
/// Produced by the `list_conversations()` Postgres RPC.
class Conversation {
  final String incidentId;
  final String otherName;
  final String otherRole;
  final String lastBody;
  final DateTime? lastAt;
  final int unread;

  const Conversation({
    required this.incidentId,
    required this.otherName,
    required this.otherRole,
    required this.lastBody,
    required this.lastAt,
    required this.unread,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        incidentId: json['incident_id'] as String,
        otherName: (json['other_name'] as String?)?.trim().isNotEmpty == true
            ? json['other_name'] as String
            : 'Unknown',
        otherRole: json['other_role'] as String? ?? '',
        lastBody: json['last_body'] as String? ?? '',
        lastAt: json['last_at'] != null
            ? DateTime.parse(json['last_at'] as String).toLocal()
            : null,
        unread: (json['unread'] as num?)?.toInt() ?? 0,
      );
}
