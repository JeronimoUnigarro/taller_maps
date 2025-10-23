import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/business.dart';

class SupabaseBusinessDatasource {
  final SupabaseClient client;
  SupabaseBusinessDatasource(this.client);

  static const String table = 'businesses';

  Future<List<Business>> getAll() async {
    final res = await client.from(table).select().order('created_at');
    return (res as List)
        .map((e) => Business.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<Business> add(Business business) async {
    final inserted = await client.from(table).insert(business.toInsertMap()).select().single();
    return Business.fromMap(inserted);
  }
}