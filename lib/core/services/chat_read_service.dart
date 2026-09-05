import '../../supabase_config.dart';

// Tracks, per signed-in account and per chat thread (a booking's or a car
// service request's activity_messages), when that account last opened the
// thread. Backs the small unread-message dot shown next to chat entry points
// (Trip Tracking's driver card, the driver's "Message passenger" button,
// Activity rows) so a new message is noticeable without opening every chat.
class ChatReadService {
  static final ChatReadService _instance = ChatReadService._internal();
  factory ChatReadService() => _instance;
  ChatReadService._internal();

  String? get _userId => supabase.auth.currentUser?.id;

  Future<DateTime?> lastReadAt({
    String? bookingId,
    String? serviceRequestId,
  }) async {
    final userId = _userId;
    if (userId == null) return null;
    try {
      final builder =
          supabase.from('activity_reads').select('last_read_at').eq('user_id', userId);
      final row = bookingId != null
          ? await builder.eq('booking_id', bookingId).maybeSingle()
          : await builder.eq('service_request_id', serviceRequestId!).maybeSingle();
      if (row == null) return null;
      return DateTime.tryParse(row['last_read_at']?.toString() ?? '');
    } catch (e) {
      print('ChatReadService.lastReadAt error: $e');
      return null;
    }
  }

  // Called when a thread is opened (ActivityChatScreen) so its unread dot
  // clears for this account.
  Future<void> markRead({String? bookingId, String? serviceRequestId}) async {
    final userId = _userId;
    if (userId == null) return;
    try {
      await supabase.from('activity_reads').upsert(
        {
          'user_id': userId,
          'booking_id': bookingId,
          'service_request_id': serviceRequestId,
          'last_read_at': DateTime.now().toIso8601String(),
        },
        onConflict: bookingId != null ? 'user_id,booking_id' : 'user_id,service_request_id',
      );
    } catch (e) {
      print('ChatReadService.markRead error: $e');
    }
  }
}
