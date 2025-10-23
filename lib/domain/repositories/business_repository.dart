import '../entities/business.dart';

abstract class BusinessRepository {
  Future<List<Business>> getAll();
  Future<Business> add(Business business);
}