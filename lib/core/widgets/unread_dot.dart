import 'package:flutter/material.dart';

import '../../supabase_config.dart';
import '../services/chat_read_service.dart';
import '../theme/app_theme.dart';

// A small red dot that appears next to a chat entry point once the other
// side (driver <-> passenger) has sent a message since this account last
// opened that thread. Renders nothing while unread status is still loading
// or once there is nothing new, so it is safe to drop in anywhere.
class UnreadDot extends StatefulWidget {
  const UnreadDot({
    super.key,
    this.bookingId,
    this.serviceRequestId,
    required this.mySenderType,
  });

  final String? bookingId;
  final String? serviceRequestId;
  final String mySenderType; // 'user' or 'driver'

  @override
  State<UnreadDot> createState() => _UnreadDotState();
}

class _UnreadDotState extends State<UnreadDot> {
  Stream<List<Map<String, dynamic>>>? _stream;
  DateTime? _lastRead;

  String get _column => widget.bookingId != null ? 'booking_id' : 'service_request_id';
  String get _threadId => widget.bookingId ?? widget.serviceRequestId ?? '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final lastRead = await ChatReadService().lastReadAt(
      bookingId: widget.bookingId,
      serviceRequestId: widget.serviceRequestId,
    );
    if (!mounted) return;
    setState(() {
      _lastRead = lastRead;
      _stream = supabase
          .from('activity_messages')
          .stream(primaryKey: ['id'])
          .eq(_column, _threadId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final stream = _stream;
    if (stream == null) return const SizedBox.shrink();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final rows = snapshot.data ?? const [];
        final unread = rows.any((row) {
          if (row['sender_type'] == widget.mySenderType) return false;
          final at = DateTime.tryParse(row['created_at']?.toString() ?? '');
          if (at == null) return false;
          return _lastRead == null || at.isAfter(_lastRead!);
        });
        if (!unread) return const SizedBox.shrink();
        return Container(
          width: 9,
          height: 9,
          decoration: const BoxDecoration(
            color: AppColors.danger,
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
