class ActivityMessage {
  final String id;
  final String? bookingId;
  final String? serviceRequestId;
  final String senderId;
  final String senderType;
  final String type;
  final String message;
  final String? imageUrl;
  final DateTime createdAt;

  ActivityMessage({
    required this.id,
    this.bookingId,
    this.serviceRequestId,
    required this.senderId,
    required this.senderType,
    this.type = 'text',
    required this.message,
    this.imageUrl,
    required this.createdAt,
  });

  bool get isImage => type == 'image' && (imageUrl?.isNotEmpty ?? false);

  factory ActivityMessage.fromJson(Map<String, dynamic> json) {
    return ActivityMessage(
      id: json['id'].toString(),
      bookingId: json['booking_id']?.toString(),
      serviceRequestId: json['service_request_id']?.toString(),
      senderId: json['sender_id'].toString(),
      senderType: (json['sender_type'] ?? 'driver') as String,
      type: (json['type'] ?? 'text') as String,
      message: (json['message'] ?? '') as String,
      imageUrl: json['image_url']?.toString(),
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  bool get isMine => senderType == 'user';
}
