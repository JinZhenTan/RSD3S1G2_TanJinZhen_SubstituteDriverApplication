import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class Launcher {
  Launcher._();

  static Future<bool> call(String rawNumber) async {
    final number = rawNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (number.isEmpty) return false;
    final uri = Uri(scheme: 'tel', path: number);
    return _launch(uri);
  }

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
      print('Launcher error for $uri: $e');
      return false;
    }
  }
}
