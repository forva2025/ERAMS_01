enum NotificationType {
  jobOffer,
  incidentDispatched,
  tripAccepted,
  tripRejected,
  rejectionFollowup,
  incomingCall,
  driverArrived;

  static NotificationType fromString(String value) => switch (value) {
    'job_offer'           => jobOffer,
    'incident_dispatched' => incidentDispatched,
    'trip_accepted'       => tripAccepted,
    'trip_rejected'       => tripRejected,
    'rejection_followup'  => rejectionFollowup,
    'incoming_call'       => incomingCall,
    'driver_arrived'      => driverArrived,
    _                     => jobOffer,
  };
}

class AppNotification {
  final String id;
  final String userId;
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: NotificationType.fromString(json['type'] as String),
      title: json['title'] as String,
      body: json['body'] as String,
      data: (json['data'] as Map<String, dynamic>?) ?? const {},
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
