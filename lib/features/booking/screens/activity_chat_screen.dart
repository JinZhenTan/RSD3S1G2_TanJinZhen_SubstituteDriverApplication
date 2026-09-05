import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;

import '../../../supabase_config.dart';
import '../../../core/services/chat_read_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/tr.dart';
import '../../../models/activity_message.dart';

// Activity Chat. In-trip messaging backed by the Supabase `activity_messages`
// table and delivered live with Supabase Realtime. Used from both sides:
// the passenger's screens pass mySenderType 'user', the driver's screens pass
// 'driver', so each side sees its own messages on the right.
//
// Messages are text or pictures. A picture comes from the camera (image_picker)
// or from an image file on the device (file_picker opens the system Files
// app). Either way the bytes are uploaded to the Supabase Storage 'chat-images'
// bucket, then sent as a row with type = 'image' and image_url = the object's
// public URL.
enum _AttachSource { camera, files }

class ActivityChatScreen extends StatefulWidget {
  const ActivityChatScreen({
    super.key,
    this.bookingId,
    this.serviceRequestId,
    required this.title,
    this.driverName = 'Driver',
    this.mySenderType = 'user',
    this.readOnly = false,
  });

  final String? bookingId;
  final String? serviceRequestId;
  final String title;
  final String driverName;
  final String mySenderType; // 'user' or 'driver'
  // True once the trip/service job this thread belongs to is history (see
  // bookingIsHistory) - the composer is replaced with a "read only" notice so
  // a finished trip can't collect new messages.
  final bool readOnly;

  @override
  State<ActivityChatScreen> createState() => _ActivityChatScreenState();
}

class _ActivityChatScreenState extends State<ActivityChatScreen> {
  static const String _bucket = 'chat-images';

  final _db = supabase;
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _picker = ImagePicker();

  Stream<List<ActivityMessage>>? _stream;
  bool _sending = false;
  bool _uploading = false;

  String get _threadColumn =>
      widget.bookingId != null ? 'booking_id' : 'service_request_id';
  String get _threadId => widget.bookingId ?? widget.serviceRequestId ?? '';

  @override
  void initState() {
    super.initState();
    _stream = _db
        .from('activity_messages')
        .stream(primaryKey: ['id'])
        .eq(_threadColumn, _threadId)
        .order('created_at')
        .map((rows) => rows.map(ActivityMessage.fromJson).toList());
    // Clears this thread's unread dot for this account.
    ChatReadService().markRead(
      bookingId: widget.bookingId,
      serviceRequestId: widget.serviceRequestId,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final uid = _db.auth.currentUser?.id;
    if (text.isEmpty || uid == null) return;

    setState(() => _sending = true);
    _controller.clear();

    try {
      await _db.from('activity_messages').insert({
        _threadColumn: _threadId,
        'sender_id': uid,
        'sender_type': widget.mySenderType,
        'type': 'text',
        'message': text,
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message failed to send')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // Ask camera or device files, pick one image, upload it, then send the row.
  Future<void> _attachImage() async {
    final source = await showModalBottomSheet<_AttachSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Tr('Take a photo'),
              onTap: () => Navigator.pop(context, _AttachSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.folder_open_outlined),
              title: const Tr('Upload from device'),
              subtitle: const Tr('Choose an image file from your device'),
              onTap: () => Navigator.pop(context, _AttachSource.files),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;

    Uint8List? bytes;
    String name;
    try {
      if (source == _AttachSource.camera) {
        final picked = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1600,
          imageQuality: 80,
        );
        if (picked == null) return;
        bytes = await picked.readAsBytes();
        name = picked.name;
      } else {
        // Opens the system Files app, filtered to image types.
        final file = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: const [
            'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'bmp',
          ],
        );
        if (file == null) return;
        bytes = await file.readAsBytes();
        name = file.name;
      }
    } catch (e) {
      _toast(
        'Could not open the '
        '${source == _AttachSource.camera ? 'camera' : 'file picker'}',
      );
      return;
    }

    if (bytes.isEmpty) {
      _toast('Could not read that file');
      return;
    }
    if (bytes.lengthInBytes > 15 * 1024 * 1024) {
      _toast('That image is too large (max 15 MB)');
      return;
    }

    setState(() => _uploading = true);
    try {
      final ext = _extensionOf(name);
      final contentType = _mimeFor(ext);
      final objectPath =
          '$_threadId/${DateTime.now().millisecondsSinceEpoch}_$uid.$ext';

      await _db.storage.from(_bucket).uploadBinary(
            objectPath,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );
      final publicUrl = _db.storage.from(_bucket).getPublicUrl(objectPath);

      await _db.from('activity_messages').insert({
        _threadColumn: _threadId,
        'sender_id': uid,
        'sender_type': widget.mySenderType,
        'type': 'image',
        'message': '',
        'image_url': publicUrl,
      });
    } catch (e) {
      _toast('Picture failed to send');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _extensionOf(String name) {
    final dot = name.lastIndexOf('.');
    if (dot == -1 || dot == name.length - 1) return 'jpg';
    final ext = name.substring(dot + 1).toLowerCase();
    return ext == 'jpeg' ? 'jpg' : ext;
  }

  String _mimeFor(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'heic':
        return 'image/heic';
      case 'bmp':
        return 'image/bmp';
      default:
        return 'image/jpeg';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.driverName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            Text(
              widget.title,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppColors.heroSubtext,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ActivityMessage>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Tr(
                      'No messages yet. Say hi to ${widget.driverName}.',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scroll.hasClients) {
                    _scroll.jumpTo(_scroll.position.maxScrollExtent);
                  }
                });
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, i) => _Bubble(
                    message: messages[i],
                    mySenderType: widget.mySenderType,
                  ),
                );
              },
            ),
          ),
          if (_uploading)
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Tr(
                    'Sending picture…',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          if (widget.readOnly)
            const _ReadOnlyNotice()
          else
            _Composer(
              controller: _controller,
              sending: _sending,
              uploading: _uploading,
              onSend: _send,
              onAttach: _attachImage,
            ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mySenderType});

  final ActivityMessage message;
  final String mySenderType;

  @override
  Widget build(BuildContext context) {
    final mine = message.senderType == mySenderType;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(16),
      topRight: const Radius.circular(16),
      bottomLeft: Radius.circular(mine ? 16 : 4),
      bottomRight: Radius.circular(mine ? 4 : 16),
    );

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: mine ? AppColors.blue600 : AppColors.card,
          border: mine ? null : Border.all(color: AppColors.line),
          borderRadius: radius,
        ),
        clipBehavior: Clip.antiAlias,
        child: message.isImage
            ? _ImageContent(message: message, mine: mine, radius: radius)
            : _TextContent(message: message, mine: mine),
      ),
    );
  }
}

class _TextContent extends StatelessWidget {
  const _TextContent({required this.message, required this.mine});

  final ActivityMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.message,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: mine ? Colors.white : AppColors.ink,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            DateFormat('h:mm a').format(message.createdAt),
            style: TextStyle(
              fontSize: 9,
              color: mine ? Colors.white70 : AppColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageContent extends StatelessWidget {
  const _ImageContent({
    required this.message,
    required this.mine,
    required this.radius,
  });

  final ActivityMessage message;
  final bool mine;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final url = message.imageUrl!;
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _ImageViewer(url: url),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const SizedBox(
                  width: 180,
                  height: 180,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) => const SizedBox(
                width: 180,
                height: 120,
                child: Center(
                  child: Icon(Icons.broken_image_outlined,
                      color: AppColors.muted),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
            child: Text(
              DateFormat('h:mm a').format(message.createdAt),
              style: TextStyle(
                fontSize: 9,
                color: mine ? Colors.white70 : AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Tap a picture bubble to see it full screen, pinch to zoom.
class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Image.network(
            url,
            errorBuilder: (context, error, stackTrace) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}

// Shown instead of _Composer once the trip is history - this thread is a
// record of what was said, not somewhere new messages belong.
class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.page,
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 14, color: AppColors.muted),
            const SizedBox(width: 8),
            Tr(
              'This booking has ended - chat is read-only',
              style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.uploading,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController controller;
  final bool sending;
  final bool uploading;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.fromLTRB(4, 4, 6, 4),
          child: Row(
            children: [
              IconButton(
                onPressed: uploading ? null : onAttach,
                icon: const Icon(Icons.add_photo_alternate_outlined,
                    color: AppColors.blue600),
                tooltip: context.tr('Send a picture'),
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: context.tr('Message…'),
                    border: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              IconButton(
                onPressed: sending ? null : onSend,
                icon: const Icon(Icons.send, color: AppColors.blue600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
