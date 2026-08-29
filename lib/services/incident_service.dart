import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/incident.dart';
import '../models/hospital.dart';
import 'sms_service.dart';
import 'supabase_service.dart';

class DispatchException implements Exception {
  final String code;
  final String message;
  const DispatchException(this.code, this.message);

  @override
  String toString() => message;
}

/// Maps a dispatch_incident/cancel_trip PostgrestException to a friendly
/// DispatchException. Shared by the dispatcher and patient flows, which
/// both call dispatch_incident under the hood.
DispatchException parseDispatchError(PostgrestException e) {
  final msg = e.message.toLowerCase();
  if (e.code == '42501') {
    return const DispatchException(
      'row_level_security',
      'Your session may have expired or your account isn\'t authorized '
          'for this action. Please log out and log back in, then try again.',
    );
  }
  if (msg.contains('no_ambulance_available')) {
    return const DispatchException(
      'no_ambulance_available',
      'No available ambulance found. All units are currently busy or offline.',
    );
  }
  if (msg.contains('ambulance_already_busy')) {
    return const DispatchException(
      'ambulance_already_busy',
      'This ambulance was just taken by another request. Please choose another.',
    );
  }
  if (msg.contains('incident_already_dispatched')) {
    return const DispatchException(
      'incident_already_dispatched',
      'This incident has already been dispatched.',
    );
  }
  if (msg.contains('incident_not_found')) {
    return const DispatchException(
      'incident_not_found',
      'Incident not found.',
    );
  }
  if (msg.contains('unauthorized')) {
    return const DispatchException(
      'unauthorized',
      'You do not have permission to perform this action.',
    );
  }
  if (msg.contains('trip_already_closed')) {
    return const DispatchException(
      'trip_already_closed',
      'This trip is already completed or cancelled.',
    );
  }
  return DispatchException('unknown', e.message);
}

class IncidentService {
  Future<List<Incident>> fetchActiveIncidents() async {
    final data = await supabaseClient
        .from('incidents')
        .select()
        .inFilter('status', ['logged', 'pending_acceptance', 'dispatched', 'en_route', 'arrived'])
        .order('priority_rank', ascending: true)
        .order('created_at', ascending: true);
    return (data as List).map((e) => Incident.fromJson(e)).toList();
  }

  Future<List<Hospital>> fetchHospitals() async {
    final data = await supabaseClient.from('hospitals').select();
    return (data as List).map((e) => Hospital.fromJson(e)).toList();
  }

  Future<Incident> createIncident({
    required String reporterName,
    required String reporterPhone,
    required double latitude,
    required double longitude,
    required String locationDescription,
    required String natureOfEmergency,
    required String patientConditionNotes,
    required String assignedHospitalId,
  }) async {
    final userId = supabaseClient.auth.currentUser!.id;
    final data = await supabaseClient
        .from('incidents')
        .insert({
          'reporter_name': reporterName,
          'reporter_phone': reporterPhone,
          'incident_location': 'POINT($longitude $latitude)',
          'location_description': locationDescription,
          'nature_of_emergency': natureOfEmergency,
          'patient_condition_notes': patientConditionNotes,
          'assigned_hospital_id': assignedHospitalId,
          'status': 'logged',
          'created_by': userId,
        })
        .select()
        .single();
    return Incident.fromJson(data);
  }

  /// Auto-assigns the nearest available ambulance to [incidentId].
  /// Throws [DispatchException] with code 'no_ambulance_available' when
  /// there are no available ambulances.
  Future<void> dispatchIncident(String incidentId) async {
    try {
      await supabaseClient.rpc('dispatch_incident', params: {
        'p_incident_id': incidentId,
      });
    } on PostgrestException catch (e) {
      throw parseDispatchError(e);
    }
    // Best-effort SMS fallback — never block the dispatch flow.
    await SmsService().notifyHospitalIncomingPatient(incidentId);
  }

  /// Manually assigns a specific [ambulanceId] to [incidentId],
  /// bypassing the availability check (dispatcher override).
  Future<void> dispatchIncidentManual(
      String incidentId, String ambulanceId) async {
    try {
      await supabaseClient.rpc('dispatch_incident', params: {
        'p_incident_id': incidentId,
        'p_ambulance_id': ambulanceId,
      });
    } on PostgrestException catch (e) {
      throw parseDispatchError(e);
    }
    await SmsService().notifyHospitalIncomingPatient(incidentId);
  }

  /// Transitions [incidentId] to [newStatus].
  /// Valid targets: en_route, arrived, completed, cancelled.
  Future<void> updateIncidentStatus(
      String incidentId, String newStatus) async {
    try {
      await supabaseClient.rpc('update_incident_status', params: {
        'p_incident_id': incidentId,
        'p_new_status': newStatus,
      });
    } on PostgrestException catch (e) {
      throw parseDispatchError(e);
    }
  }

  /// Dispatcher/admin override of the auto-derived priority.
  Future<void> updateIncidentPriority(
      String incidentId, String priority) async {
    await supabaseClient
        .from('incidents')
        .update({'priority': priority})
        .eq('id', incidentId);
  }
}
