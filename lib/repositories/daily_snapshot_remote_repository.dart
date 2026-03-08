import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/day_snapshot.dart';

class DailySnapshotRemoteRepository {
  final SupabaseClient _client;

  DailySnapshotRemoteRepository(this._client);

  static const String _table = 'daily_nutrition_snapshots';

  // ===========================================================================
  // == UPSERT : 1 snapshot / jour / utilisateur
  // ===========================================================================

  Future<void> upsertDaySnapshot(DaySnapshot snapshot) async {
    final user = _client.auth.currentUser;
    if (user == null) return; // pas connecté → on ignore silencieusement

    final payload = snapshot.toJson()
      ..['user_id'] = user.id;

    try {
      await _client
          .from(_table)
          .upsert(
            payload,
            onConflict: 'user_id,date',
          );
    } catch (e) {
      // ⚠️ volontairement silencieux
      // La sync ne doit JAMAIS casser l’UI
      // Tu peux logger si besoin
      // debugPrint('Supabase upsert error: $e');
    }
  }

  // ===========================================================================
  // == FETCH : derniers 90 jours (ou moins)
  // ===========================================================================

  Future<List<DaySnapshot>> fetchLastDays({int limit = 90}) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      final res = await _client
          .from(_table)
          .select()
          .eq('user_id', user.id)
          .order('date', ascending: false)
          .limit(limit);

      if (res is! List) return [];

      return res
          .map((e) => DaySnapshot.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // ⚠️ idem : erreur réseau / RLS → on retourne vide
      return [];
    }
  }
}

