import 'supabase_service.dart';

class ProfileService {
  Future<void> updateProfile({
    required String userId,
    required String fullName,
    required String phone,
  }) async {
    await supabaseClient.from('profiles').update({
      'full_name': fullName,
      'phone': phone,
    }).eq('id', userId);
  }

  /// Completed + cancelled incidents for a dispatcher, last 30 days.
  Future<List<Map<String, dynamic>>> fetchDispatcherHistory() async {
    final since =
        DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    return List<Map<String, dynamic>>.from(
      await supabaseClient
          .from('incidents')
          .select('*, hospitals(name)')
          .inFilter('status', ['completed', 'cancelled'])
          .gte('created_at', since)
          .order('created_at', ascending: false),
    );
  }

  /// Completed incidents assigned to the given hospital, last 30 days.
  Future<List<Map<String, dynamic>>> fetchHospitalHistory(
      String hospitalId) async {
    final since =
        DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    return List<Map<String, dynamic>>.from(
      await supabaseClient
          .from('incidents')
          .select('*, hospitals(name)')
          .eq('assigned_hospital_id', hospitalId)
          .inFilter('status', ['completed', 'cancelled'])
          .gte('created_at', since)
          .order('created_at', ascending: false),
    );
  }

  /// Completed incidents where the given ambulance was assigned, last 30 days.
  Future<List<Map<String, dynamic>>> fetchDriverHistory(
      String ambulanceId) async {
    final since =
        DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
    return List<Map<String, dynamic>>.from(
      await supabaseClient
          .from('incidents')
          .select('*, hospitals(name)')
          .eq('assigned_ambulance_id', ambulanceId)
          .inFilter('status', ['completed', 'cancelled'])
          .gte('created_at', since)
          .order('created_at', ascending: false),
    );
  }
}
