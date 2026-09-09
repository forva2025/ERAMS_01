import '../models/ambulance.dart';
import '../models/hospital.dart';
import '../models/incident.dart';
import 'supabase_service.dart';

class HospitalService {
  Future<Hospital?> fetchMyHospital() async {
    final userId = supabaseClient.auth.currentUser?.id;
    if (userId == null) return null;
    final profile = await supabaseClient
        .from('profiles')
        .select('hospital_id')
        .eq('id', userId)
        .single();
    final hospitalId = profile['hospital_id'] as String?;
    if (hospitalId == null) return null;
    final data = await supabaseClient
        .from('hospitals')
        .select()
        .eq('id', hospitalId)
        .single();
    return Hospital.fromJson(data);
  }

  Future<List<Incident>> fetchAssignedIncidents(String hospitalId) async {
    final data = await supabaseClient
        .from('incidents')
        .select()
        .eq('assigned_hospital_id', hospitalId)
        .inFilter('status', ['dispatched', 'en_route', 'arrived'])
        .order('priority_rank', ascending: true)
        .order('created_at', ascending: true);
    return (data as List).map((e) => Incident.fromJson(e)).toList();
  }

  Future<List<Ambulance>> fetchAllAmbulances() async {
    final data = await supabaseClient.from('ambulances').select();
    return (data as List)
        .map((e) => Ambulance.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns the set of incident IDs (from [incidentIds]) that have already
  /// been acknowledged by this hospital in incident_events.
  Future<Set<String>> fetchAcknowledgedIncidentIds(
      List<String> incidentIds) async {
    if (incidentIds.isEmpty) return {};
    final data = await supabaseClient
        .from('incident_events')
        .select('incident_id')
        .inFilter('incident_id', incidentIds)
        .eq('event_type', 'message')
        .like('payload', '%hospital_acknowledged%');
    return (data as List)
        .map((e) => e['incident_id'] as String)
        .toSet();
  }

  Future<void> acknowledgeIncident(String incidentId) async {
    final userId = supabaseClient.auth.currentUser!.id;
    await supabaseClient.from('incident_events').insert({
      'incident_id': incidentId,
      'event_type': 'message',
      'payload':
          '{"type":"hospital_acknowledged","message":"Hospital ready to receive patient"}',
      'actor_id': userId,
    });
  }
}
