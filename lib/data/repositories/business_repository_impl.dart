import '../../domain/entities/business.dart';
import '../../domain/repositories/business_repository.dart';
import '../datasources/supabase_business_datasource.dart';

class BusinessRepositoryImpl implements BusinessRepository {
  final SupabaseBusinessDatasource datasource;
  BusinessRepositoryImpl(this.datasource);

  @override
  Future<Business> add(Business business) => datasource.add(business);

  @override
  Future<List<Business>> getAll() => datasource.getAll();
}