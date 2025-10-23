import '../entities/business.dart';
import '../repositories/business_repository.dart';

class AddBusiness {
  final BusinessRepository repository;
  AddBusiness(this.repository);
  Future<Business> call(Business business) => repository.add(business);
}