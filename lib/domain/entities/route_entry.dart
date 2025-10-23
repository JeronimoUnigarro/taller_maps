class RouteEntry {
  final String id;
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;
  final String vehicle; // driving, cycling, walking
  final double distanceKm;
  final double durationMin;
  final List<dynamic> coordinates; // OSRM GeoJSON coordinates [[lng, lat], ...]
  final DateTime createdAt;

  RouteEntry({
    required this.id,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
    required this.vehicle,
    required this.distanceKm,
    required this.durationMin,
    required this.coordinates,
    required this.createdAt,
  });

  factory RouteEntry.fromMap(Map<String, dynamic> map) {
    return RouteEntry(
      id: map['id']?.toString() ?? '',
      startLat: (map['start_lat'] as num).toDouble(),
      startLng: (map['start_lng'] as num).toDouble(),
      endLat: (map['end_lat'] as num).toDouble(),
      endLng: (map['end_lng'] as num).toDouble(),
      vehicle: map['vehicle'] ?? 'driving',
      distanceKm: (map['distance_km'] as num).toDouble(),
      durationMin: (map['duration_min'] as num).toDouble(),
      coordinates: map['route_coords'] as List<dynamic>,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'start_lat': startLat,
      'start_lng': startLng,
      'end_lat': endLat,
      'end_lng': endLng,
      'vehicle': vehicle,
      'distance_km': distanceKm,
      'duration_min': durationMin,
      'route_coords': coordinates,
    };
  }
}