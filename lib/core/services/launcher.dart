import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

// Thin wrappers around url_launcher for the two "leave the app" actions the
// car-service flow needs: phone the other party, and open turn-by-turn
// navigation to a coordinate in whatever maps app the device has.
class Launcher {
  Launcher._();

  // Dial a phone number (opens the dialer, does not place the call).
  static Future<bool> call(String rawNumber) async {
    final number = rawNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (number.isEmpty) return false;
    final uri = Uri(scheme: 'tel', path: number);
    return _launch(uri);
  }

  // Open navigation to a point. `geo:` is understood by Google Maps / Waze on
  // Android; iOS falls back to an Apple/Google Maps https URL.
  static Future<bool> navigateTo(LatLng point, {String? label}) async {
    final lat = point.latitude;
    final lng = point.longitude;
    final q = label == null || label.isEmpty
        ? '$lat,$lng'
        : '$lat,$lng(${Uri.encodeComponent(label)})';

    final geo = Uri.parse('geo:$lat,$lng?q=$q');
    if (await canLaunchUrl(geo)) return _launch(geo);

    final web = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    return _launch(web);
  }

  static Future<bool> _launch(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      // ignore: avoid_print
      print('Launcher error for $uri: $e');
      return false;
    }
  }
}
