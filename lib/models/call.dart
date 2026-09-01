enum CallStatus {
  ringing,
  accepted,
  declined,
  ended,
  missed;

  static CallStatus fromString(String value) => switch (value) {
    'ringing'  => ringing,
    'accepted' => accepted,
    'declined' => declined,
    'ended'    => ended,
    'missed'   => missed,
    _          => ringing,
  };
}

class Call {
  final String id;
  final String incidentId;
  final String callerId;
  final String calleeId;
  final String channelName;
  final bool isVideo;
  final CallStatus status;
  final DateTime createdAt;
  final DateTime? answeredAt;
  final DateTime? endedAt;

  const Call({
    required this.id,
    required this.incidentId,
    required this.callerId,
    required this.calleeId,
    required this.channelName,
    required this.isVideo,
    required this.status,
    required this.createdAt,
    this.answeredAt,
    this.endedAt,
  });

  factory Call.fromJson(Map<String, dynamic> json) {
    return Call(
      id: json['id'] as String,
      incidentId: json['incident_id'] as String,
      callerId: json['caller_id'] as String,
      calleeId: json['callee_id'] as String,
      channelName: json['channel_name'] as String,
      isVideo: json['is_video'] as bool? ?? false,
      status: CallStatus.fromString(json['status'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      answeredAt: json['answered_at'] != null
          ? DateTime.parse(json['answered_at'] as String)
          : null,
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
    );
  }
}
