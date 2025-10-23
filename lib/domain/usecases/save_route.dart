import '../entities/route_entry.dart';
import '../repositories/routes_repository.dart';

class SaveRoute {
  final RoutesRepository repository;
  SaveRoute(this.repository);
  Future<RouteEntry> call(RouteEntry entry) => repository.save(entry);
}