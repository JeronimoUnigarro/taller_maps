import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/route_entry.dart';

class SupabaseRoutesDatasource {
  final SupabaseClient client;
  SupabaseRoutesDatasource(this.client);

  static const table = 'routes';

  Future<RouteEntry> save(RouteEntry entry) async {
    final inserted = await client
        .from(table)
        .insert(entry.toInsertMap())
        .select()
        .single();
    return RouteEntry.fromMap(inserted);
  }

  Future<List<RouteEntry>> getAll() async {
    final res = await client
        .from(table)
        .select()
        .order('created_at', ascending: false);
    return (res as List)
        .map((e) => RouteEntry.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  // Nuevo: eliminar por id
  Future<void> delete(String id) async {
    await client.from(table).delete().eq('id', id);
  }
}