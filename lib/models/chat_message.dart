class ChatMessage {
  final String id;
  final String incidentId;
  final String senderId;
  final String senderRole;
  final String senderName;
  final String body;
  final DateTime createdAt;
  final List<String> seenBy;

  const ChatMessage({
    required this.id,
    required this.incidentId,
    required this.senderId,
    required this.senderRole,
    required this.senderName,
    required this.body,
    required this.createdAt,
    this.seenBy = const [],
  });

  bool isMe(String userId) => senderId == userId;

  // True when at least one other user has seen this message.
  bool isSeenByOthers(String myId) =>
      seenBy.any((id) => id != myId);

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        incidentId: json['incident_id'] as String,
        senderId: json['sender_id'] as String,
        senderRole: json['sender_role'] as String? ?? '',
        senderName: json['sender_name'] as String? ?? '',
        body: json['body'] as String,
        createdAt:
            DateTime.parse(json['created_at'] as String).toLocal(),
        seenBy: (json['seen_by'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
      );
}
