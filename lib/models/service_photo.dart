// Model class for a row of the Supabase 'service_photos' table (Module 3).
//
// Before / after / in-progress photos of the car, taken by the staff and shown
// to the owner. This is the trust piece: the owner isn't there when the car is
// collected, so a photographed record of its condition protects both sides.
enum ServicePhotoPhase { pickup, work, ret }

ServicePhotoPhase servicePhotoPhaseFromName(String? name) {
  switch (name) {
    case 'return':
      return ServicePhotoPhase.ret;
    case 'work':
      return ServicePhotoPhase.work;
    default:
      return ServicePhotoPhase.pickup;
  }
}

String servicePhotoPhaseToName(ServicePhotoPhase phase) {
  switch (phase) {
    case ServicePhotoPhase.ret:
      return 'return';
    case ServicePhotoPhase.work:
      return 'work';
    case ServicePhotoPhase.pickup:
      return 'pickup';
  }
}

String servicePhotoPhaseLabel(ServicePhotoPhase phase) {
  switch (phase) {
    case ServicePhotoPhase.pickup:
      return 'At pick-up';
    case ServicePhotoPhase.work:
      return 'During service';
    case ServicePhotoPhase.ret:
      return 'On return';
  }
}

class ServicePhoto {
  final String id;
  final String serviceRequestId;
  final ServicePhotoPhase phase;
  final String imageUrl;
  final String? caption;
  final DateTime createdAt;

  ServicePhoto({
    required this.id,
    required this.serviceRequestId,
    required this.phase,
    required this.imageUrl,
    this.caption,
    required this.createdAt,
  });

  factory ServicePhoto.fromJson(Map<String, dynamic> json) {
    return ServicePhoto(
      id: json['id'].toString(),
      serviceRequestId: json['service_request_id'].toString(),
      phase: servicePhotoPhaseFromName(json['phase']?.toString()),
      imageUrl: (json['image_url'] ?? '') as String,
      caption: json['caption'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}
