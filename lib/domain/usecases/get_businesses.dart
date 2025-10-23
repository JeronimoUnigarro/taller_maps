import '../entities/business.dart';
import '../repositories/business_repository.dart';

class GetBusinesses {
  final BusinessRepository repository;
  GetBusinesses(this.repository);
  Future<List<Business>> call() => repository.getAll();
}