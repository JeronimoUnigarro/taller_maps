import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

import '../../core/app_theme.dart';
import '../../domain/entities/route_entry.dart';
import '../../data/datasources/supabase_routes_datasource.dart';
import '../../data/repositories/routes_repository_impl.dart';
import '../../domain/usecases/get_routes.dart';
import '../../domain/usecases/save_route.dart';
import '../../domain/usecases/delete_route.dart';

class RouteMapPage extends StatefulWidget {
  const RouteMapPage({super.key});

  @override
  State<RouteMapPage> createState() => _RouteMapPageState();
}

// Helpers de duración accesibles a todo el archivo
String formatDurationText(double minutes) {
  if (minutes >= 60) {
    final h = (minutes / 60).floor();
    int m = (minutes - h * 60).round();
    if (m == 60) {
      return '${h + 1} h 0 min';
    }
    return '$h h $m min';
  }
  return '${minutes.round()} min';
}

String vehicleLabelEs(String vehicle) {
  switch (vehicle) {
    case 'driving':
      return 'Carro';
    case 'cycling':
      return 'Bicicleta';
    case 'walking':
      return 'Caminata';
    default:
      return vehicle;
  }
}

class _RouteMapPageState extends State<RouteMapPage> {
  final mapController = MapController();
  late final RoutesRepositoryImpl repository;
  late final GetRoutes getRoutes;
  late final SaveRoute saveRoute;
  late final DeleteRoute deleteRoute;

  LatLng? _start;
  LatLng? _end;
  String _vehicle = 'driving'; // driving, cycling, walking

  List<LatLng> _polyline = [];
  double? _distanceKm;
  double? _durationMin;

  LatLng? _userCenter;

  List<RouteEntry> _savedRoutes = [];

  // Buscador eliminado: se removieron controladores y estado

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    final ds = SupabaseRoutesDatasource(client);
    repository = RoutesRepositoryImpl(ds);
    getRoutes = GetRoutes(repository);
    saveRoute = SaveRoute(repository);
    deleteRoute = DeleteRoute(repository);
    _loadSaved();
    _initLocation();
  }

  Future<void> _loadSaved() async {
    try {
      final items = await getRoutes();
      setState(() => _savedRoutes = items);
    } catch (_) {}
  }

  Future<void> _initLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    final pos = await Geolocator.getCurrentPosition();
    _userCenter = LatLng(pos.latitude, pos.longitude);
    mapController.move(_userCenter!, 13);
  }

  void _onMapTap(TapPosition tapPosition, LatLng latLng) {
    setState(() {
      if (_start == null) {
        _start = latLng;
      } else if (_end == null) {
        _end = latLng;
      } else {
        _start = latLng;
        _end = null;
        _polyline = [];
        _distanceKm = null;
        _durationMin = null;
      }
    });
  }

  // Helpers de duración (top-level)
  double _estimateDurationMinutes(double distanceKm, String vehicle) {
    const speeds = {
      'driving': 25.0,
      'cycling': 12.0,
      'walking': 4.5,
    };
    final speed = speeds[vehicle] ?? 25.0;
    if (distanceKm <= 0 || speed <= 0) return 0;
    return (distanceKm / speed) * 60.0;
  }
  
  // Formateador de duración accesible a todo el archivo
  String formatDurationText(double minutes) {
    if (minutes >= 60) {
      final h = (minutes / 60).floor();
      int m = (minutes - h * 60).round();
      if (m == 60) {
        return '${h + 1} h 0 min';
      }
      return '$h h $m min';
    }
    return '${minutes.round()} min';
  }

  Future<void> _computeRoute() async {
    if (_start == null || _end == null) return;
    final profile = _vehicle; // 'driving' | 'cycling' | 'walking'
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/$profile/${_start!.longitude},${_start!.latitude};${_end!.longitude},${_end!.latitude}?overview=full&geometries=geojson',
    );
    final resp = await http.get(url);
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>;
      if (routes.isNotEmpty) {
        final route = routes.first as Map<String, dynamic>;
        final geom = route['geometry'] as Map<String, dynamic>;
        final coords = (geom['coordinates'] as List<dynamic>)
            .map<List<double>>(
              (p) => [(p as List<dynamic>)[0].toDouble(), p[1].toDouble()],
            )
            .toList();
        setState(() {
          _polyline = coords.map((c) => LatLng(c[1], c[0])).toList();
          _distanceKm = (route['distance'] as num).toDouble() / 1000.0;
          // Duración estimada según velocidad por vehículo
          _durationMin = _estimateDurationMinutes(_distanceKm!, _vehicle);
        });
        if (_polyline.isNotEmpty) {
          mapController.fitCamera(
            CameraFit.bounds(
              bounds: LatLngBounds(_polyline.first, _polyline.last),
              padding: const EdgeInsets.all(60),
            ),
          );
        }
      }
    }
  }

  Future<void> _saveCurrentRoute() async {
    if (_start == null ||
        _end == null ||
        _polyline.isEmpty ||
        _distanceKm == null ||
        _durationMin == null)
      return;
    // Convert polyline to OSRM-like coordinates [[lng, lat], ...]
    final coords = _polyline.map((p) => [p.longitude, p.latitude]).toList();
    final entry = RouteEntry(
      id: '',
      startLat: _start!.latitude,
      startLng: _start!.longitude,
      endLat: _end!.latitude,
      endLng: _end!.longitude,
      vehicle: _vehicle,
      distanceKm: _distanceKm!,
      durationMin: _durationMin!,
      coordinates: coords,
      createdAt: DateTime.now(),
    );
    final saved = await saveRoute(entry);
    setState(() {
      _savedRoutes.insert(0, saved);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Ruta guardada')));
  }

  void _openSavedRoutes() {
    showModalBottomSheet(
      context: context,
      builder: (_) => Theme(
        data: AppTheme.light(),
        child: SafeArea(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _savedRoutes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final r = _savedRoutes[i];
              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tileColor: const Color(0xFFEAF4F9),
                title: Text(
                  '${vehicleLabelEs(r.vehicle)} • ${r.distanceKm.toStringAsFixed(2)} km',
                ),
                subtitle: Text(
                   'Desde (${r.startLat.toStringAsFixed(4)}, ${r.startLng.toStringAsFixed(4)}) a (${r.endLat.toStringAsFixed(4)}, ${r.endLng.toStringAsFixed(4)})',
                 ),
                 trailing: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Text(formatDurationText(r.durationMin)),
                     const SizedBox(width: 8),
                     IconButton(
                       tooltip: 'Eliminar',
                       icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                       onPressed: () async {
                         if (r.id.isEmpty) {
                           ScaffoldMessenger.of(context).showSnackBar(
                             const SnackBar(content: Text('No se puede eliminar: id vacío')),
                           );
                           return;
                         }
                         try {
                           await deleteRoute(r.id);
                           setState(() {
                             _savedRoutes.removeWhere((e) => e.id == r.id);
                           });
                           ScaffoldMessenger.of(context)
                               .showSnackBar(const SnackBar(content: Text('Ruta eliminada')));
                         } catch (_) {
                           ScaffoldMessenger.of(context).showSnackBar(
                             const SnackBar(content: Text('Error al eliminar la ruta')),
                           );
                         }
                       },
                     ),
                   ],
                 ),
                onTap: () {
                  Navigator.of(context).pop();
                  // Restore route on map
                  setState(() {
                    _start = LatLng(r.startLat, r.startLng);
                    _end = LatLng(r.endLat, r.endLng);
                    _vehicle = r.vehicle;
                    _polyline = (r.coordinates)
                        .map<LatLng>(
                          (p) => LatLng(p[1] as double, p[0] as double),
                        )
                        .toList();
                    _distanceKm = r.distanceKm;
                    _durationMin = r.durationMin;
                  });
                  if (_polyline.isNotEmpty) {
                    mapController.fitCamera(
                      CameraFit.bounds(
                        bounds: LatLngBounds(_polyline.first, _polyline.last),
                        padding: const EdgeInsets.all(60),
                      ),
                    );
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Métodos de buscador eliminados

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculador de rutas'),
        backgroundColor: const Color(0xFF6CAECD),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Mis rutas',
            onPressed: _openSavedRoutes,
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            tooltip: 'Mi ubicación',
            onPressed: () {
              if (_userCenter != null) {
                mapController.move(_userCenter!, 14);
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialCenter: _userCenter ?? const LatLng(4.7110, -74.0721),
              initialZoom: 13,
              onTap: _onMapTap,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.flutter_application_1',
              ),
              MarkerLayer(
                markers: [
                  if (_start != null)
                    Marker(
                      point: _start!,
                      width: 40,
                      height: 40,
                      child: const _PointMarker(
                        color: Color(0xFF6CAECD),
                        icon: Icons.flag,
                      ),
                    ),
                  if (_end != null)
                    Marker(
                      point: _end!,
                      width: 40,
                      height: 40,
                      child: const _PointMarker(
                        color: Color(0xFF95D1A3),
                        icon: Icons.place,
                      ),
                    ),
                ],
              ),
              if (_polyline.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _polyline,
                      strokeWidth: 5,
                      color: const Color(0xFF6CAECD),
                    ),
                  ],
                ),
            ],
          ),
          // Removed search UI overlay
          Positioned(
            right: 12,
            bottom: 100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  onPressed: () {
                    final camera = mapController.camera;
                    final newZoom = (camera.zoom + 1).clamp(2.0, 18.0).toDouble();
                    mapController.move(camera.center, newZoom);
                  },
                  child: const Icon(Icons.zoom_in),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  onPressed: () {
                    final camera = mapController.camera;
                    final newZoom = (camera.zoom - 1).clamp(2.0, 18.0).toDouble();
                    mapController.move(camera.center, newZoom);
                  },
                  child: const Icon(Icons.zoom_out),
                ),
              ],
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: _Controls(
                  vehicle: _vehicle,
                  onVehicleChanged: (v) => setState(() => _vehicle = v),
                  onCompute: _computeRoute,
                  onSave: _saveCurrentRoute,
                  canCompute: _start != null && _end != null,
                  canSave: _polyline.isNotEmpty,
                  distanceKm: _distanceKm,
                  durationMin: _durationMin,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PointMarker extends StatelessWidget {
  final Color color;
  final IconData icon;
  const _PointMarker({required this.color, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
      ),
      child: Icon(icon, color: Colors.white),
    );
  }
}

class _Controls extends StatelessWidget {
  final String vehicle;
  final void Function(String) onVehicleChanged;
  final VoidCallback onCompute;
  final VoidCallback onSave;
  final bool canCompute;
  final bool canSave;
  final double? distanceKm;
  final double? durationMin;
  const _Controls({
    required this.vehicle,
    required this.onVehicleChanged,
    required this.onCompute,
    required this.onSave,
    required this.canCompute,
    required this.canSave,
    required this.distanceKm,
    required this.durationMin,
  });
  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: vehicle,
                    items: const [
                      DropdownMenuItem(
                        value: 'driving',
                        child: Text('🚗 Carro'),
                      ),
                      DropdownMenuItem(
                        value: 'cycling',
                        child: Text('🚴 Bicicleta'),
                      ),
                      DropdownMenuItem(
                        value: 'walking',
                        child: Text('🚶 Caminata'),
                      ),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Tipo de vehículo',
                      filled: true,
                      fillColor: Color(0xFFEAF4F9),
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                    ),
                    onChanged: (v) {
                      if (v != null) onVehicleChanged(v);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: canCompute ? onCompute : null,
                    icon: const Icon(Icons.alt_route),
                    label: const Text('Calcular ruta'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6CAECD),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: canSave ? onSave : null,
                    icon: const Icon(Icons.save_alt),
                    label: const Text('Guardar ruta'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF95D1A3),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (distanceKm != null && durationMin != null)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF4F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Distancia: ${distanceKm!.toStringAsFixed(2)} km',
                          ),
                          Text(
                            'Duración: ${formatDurationText(durationMin!)}',
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Clase de sugerencia eliminada, ya no se usa

