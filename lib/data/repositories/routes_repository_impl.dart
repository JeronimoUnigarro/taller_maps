import '../../domain/entities/route_entry.dart';
import '../../domain/repositories/routes_repository.dart';
import '../datasources/supabase_routes_datasource.dart';

class RoutesRepositoryImpl implements RoutesRepository {
  final SupabaseRoutesDatasource datasource;
  RoutesRepositoryImpl(this.datasource);

  @override
  Future<List<RouteEntry>> getAll() => datasource.getAll();

  @override
  Future<RouteEntry> save(RouteEntry entry) => datasource.save(entry);

  // Nuevo: eliminar por id
  @override
  Future<void> deleteById(String id) => datasource.delete(id);
}