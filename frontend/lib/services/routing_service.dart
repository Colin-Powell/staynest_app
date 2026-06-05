import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// Lightweight routing helper using the public OSRM demo server.
/// Returns a list of LatLng points for the route between origin and destination.
/// Note: public OSRM server has rate limits — use your own routing provider in production.
Future<List<LatLng>> fetchRouteOsrm(LatLng origin, LatLng destination) async {
  final lon1 = origin.longitude;
  final lat1 = origin.latitude;
  final lon2 = destination.longitude;
  final lat2 = destination.latitude;

  final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/$lon1,$lat1;$lon2,$lat2?overview=full&geometries=geojson');

  final resp = await http.get(url).timeout(const Duration(seconds: 10));
  if (resp.statusCode != 200) return [origin, destination];

  final data = json.decode(resp.body);
  final routes = data['routes'] as List<dynamic>?;
  if (routes == null || routes.isEmpty) return [origin, destination];

  final geometry = routes.first['geometry'];
  if (geometry == null || geometry['coordinates'] == null) return [origin, destination];

  final coords = geometry['coordinates'] as List<dynamic>;
  final pts = coords.map<LatLng>((c) {
    // OSRM returns [lon, lat]
    final lon = (c[0] as num).toDouble();
    final lat = (c[1] as num).toDouble();
    return LatLng(lat, lon);
  }).toList();

  if (pts.isEmpty) return [origin, destination];
  return pts;
}
