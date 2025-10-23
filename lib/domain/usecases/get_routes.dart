import '../entities/route_entry.dart';
import '../repositories/routes_repository.dart';

class GetRoutes {
  final RoutesRepository repository;
  GetRoutes(this.repository);
  Future<List<RouteEntry>> call() => repository.getAll();
}