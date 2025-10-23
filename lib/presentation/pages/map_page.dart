import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_theme.dart';
import '../../domain/entities/business.dart';
import '../../data/datasources/supabase_business_datasource.dart';
import '../../data/repositories/business_repository_impl.dart';
import '../../domain/usecases/get_businesses.dart';
import '../../domain/usecases/add_business.dart';
import '../widgets/add_business_sheet.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final mapController = MapController();
  late final BusinessRepositoryImpl repository;
  late final GetBusinesses getBusinesses;
  late final AddBusiness addBusiness;
  final List<Business> _businesses = [];
  LatLng? _selectedPoint;
  LatLng? _userCenter;
  StreamSubscription<Position>? _posStream;

  @override
  void initState() {
    super.initState();
    final client = Supabase.instance.client;
    final ds = SupabaseBusinessDatasource(client);
    repository = BusinessRepositoryImpl(ds);
    getBusinesses = GetBusinesses(repository);
    addBusiness = AddBusiness(repository);
    _loadData();
    _initLocation();
  }

  Future<void> _loadData() async {
    final items = await getBusinesses();
    setState(() {
      _businesses
        ..clear()
        ..addAll(items);
    });
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
    mapController.move(_userCenter!, 14);

    _posStream = Geolocator.getPositionStream().listen((p) {
      setState(() {
        _userCenter = LatLng(p.latitude, p.longitude);
      });
    });
  }

  @override
  void dispose() {
    _posStream?.cancel();
    super.dispose();
  }

  void _openAddSheet(LatLng at) {
    _selectedPoint = at;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Theme(
        data: AppTheme.light(),
        child: AddBusinessSheet(
          onSubmit: (name, category, description) async {
            if (_selectedPoint == null) return;
            final b = Business(
              id: '',
              name: name,
              category: category,
              latitude: _selectedPoint!.latitude,
              longitude: _selectedPoint!.longitude,
              description: description,
            );
            final saved = await addBusiness(b);
            setState(() {
              _businesses.add(saved);
            });
          },
        ),
      ),
    );
  }

  void _showBusinessDetails(Business b) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(b.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(b.category, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 8),
            if (b.description != null) Text(b.description!),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Negocios locales'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
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
              onLongPress: (tapPos, latlng) => _openAddSheet(latlng),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.flutter_application_1',
              ),
              MarkerLayer(
                markers: [
                  for (final b in _businesses)
                    Marker(
                      point: LatLng(b.latitude, b.longitude),
                      width: 44,
                      height: 44,
                      child: GestureDetector(
                        onTap: () => _showBusinessDetails(b),
                        child: const _Marker(),
                      ),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 16,
            right: 16,
            top: 12,
            child: _SearchBar(onFilter: (text) {
              final t = text.trim().toLowerCase();
              setState(() {
                _businesses.sort((a, b) => a.name.compareTo(b.name));
              });
              // Nota: se puede mejorar con filtro real desde Supabase.
            }),
          ),
        ],
      ),
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF6CAECD),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: const Icon(Icons.storefront, color: Colors.white),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final void Function(String) onFilter;
  const _SearchBar({required this.onFilter});
  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: TextField(
        onChanged: onFilter,
        decoration: const InputDecoration(
          hintText: 'Buscar o filtrar...',
          prefixIcon: Icon(Icons.search),
          border: InputBorder.none,
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        ),
      ),
    );
  }
}