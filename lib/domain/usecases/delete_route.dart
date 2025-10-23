import '../repositories/routes_repository.dart';

class DeleteRoute {
  final RoutesRepository repository;
  DeleteRoute(this.repository);
  Future<void> call(String id) => repository.deleteById(id);
}