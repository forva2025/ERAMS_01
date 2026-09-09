import '../models/ambulance.dart';
import '../models/hospital.dart';
import '../models/incident.dart';
import 'sms_service.dart';
import 'supabase_service.dart';

class DriverService {
  Future<Ambulance?> fetchMyAmbulance() async {
    final userId = supabaseClient.auth.currentUser?.id;
    if (userId == null) return null;
    final data = await supabaseClient
        .from('ambulances')
        .select()
        .eq('driver_id', userId)
        .maybeSingle();
    if (data == null) return null;
    return Ambulance.fromJson(data);
  }

  Future<Incident?> fetchActiveIncident(String ambulanceId) async {
    final data = await supabaseClient
        .from('incidents')
        .select()
        .eq('assigned_ambulance_id', ambulanceId)
        .inFilter('status', ['pending_acceptance', 'dispatched', 'en_route', 'arrived'])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (data == null) return null;
    return Incident.fromJson(data);
  }

  Future<void> acceptTrip(String incidentId) async {
    await supabaseClient.rpc('accept_trip', params: {'p_incident_id': incidentId});
    // Best-effort SMS fallbacks — never block the accept flow.
    await SmsService().notifyPatientDriverAccepted(incidentId);
    await SmsService().notifyHospitalIncomingPatient(incidentId);
  }

  Future<void> declineTrip(
    String incidentId, {
    String? reasonCategory,
    String? reasonNotes,
  }) async {
    final result = await supabaseClient.rpc('decline_trip', params: {
      'p_incident_id': incidentId,
      'p_reason_category': reasonCategory,
      'p_reason_notes': reasonNotes,
    });
    final nextAmbulanceId =
        result is Map ? result['next_ambulance_id'] as String? : null;
    if (nextAmbulanceId != null) {
      await SmsService().notifyDriverJobOffer(incidentId, nextAmbulanceId);
    }
  }

  Future<Hospital?> fetchHospital(String hospitalId) async {
    final data = await supabaseClient
        .from('hospitals')
        .select()
        .eq('id', hospitalId)
        .single();
    return Hospital.fromJson(data);
  }

  Future<void> setAmbulanceStatus(String ambulanceId, String status) async {
    await supabaseClient
        .from('ambulances')
        .update({'status': status})
        .eq('id', ambulanceId);
  }

  Future<void> pushLocation(
      String ambulanceId, double lat, double lng) async {
    await supabaseClient.from('ambulances').update({
      'current_location': 'SRID=4326;POINT($lng $lat)',
      'last_location_update': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', ambulanceId);
  }

  Future<void> updateIncidentStatus(
      String incidentId, String status) async {
    await supabaseClient.rpc('update_incident_status', params: {
      'p_incident_id': incidentId,
      'p_new_status': status,
    });
    if (status == 'arrived') {
      await SmsService().notifyPatientDriverArrived(incidentId);
    }
  }
}
