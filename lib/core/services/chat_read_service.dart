import '../../supabase_config.dart';

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
