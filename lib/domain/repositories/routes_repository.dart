import '../entities/route_entry.dart';

abstract class RoutesRepository {
  Future<RouteEntry> save(RouteEntry entry);
  Future<List<RouteEntry>> getAll();
  // Agregar eliminación por id
  Future<void> deleteById(String id);
}