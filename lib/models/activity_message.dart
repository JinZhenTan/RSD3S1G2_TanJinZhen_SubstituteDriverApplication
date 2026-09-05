// Model class for a row of the Supabase 'activity_messages' table.
// One chat message in a trip thread (booking) or a car service thread.
// Delivered live with Supabase Realtime on the Activity Chat screen.
//
// A message is either text (`type` = 'text', `message` holds the text) or a
// picture (`type` = 'image', `imageUrl` points at a public object in the
// Supabase Storage 'chat-images' bucket; `message` may hold an optional caption).
class ActivityMessage {
  final String id;
  final String? bookingId;
  final String? serviceRequestId;
  final String senderId;
  final String senderType; // 'user' or 'driver'
  final String type; // 'text' or 'image'
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
