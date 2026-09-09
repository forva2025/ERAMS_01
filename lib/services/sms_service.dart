import 'package:latlong2/latlong.dart';

import '../core/utils/geo_utils.dart';
import 'supabase_service.dart';

/// SMS fallback notifications (Africa's Talking) for the four Phase 16
/// trigger events. Every public method is best-effort: it swallows all
/// errors internally so a failed or unconfigured SMS provider never blocks
/// the caller's main flow (dispatch, accept, decline, status update).
class SmsService {
  Future<void> sendSms({
    required String phone,
    required String message,
    String? incidentId,
  }) async {
    try {
      await supabaseClient.functions.invoke('send_sms', body: {
        'phone': phone,
        'message': message,
        if (incidentId != null) 'incidentId': incidentId,
      });
    } catch (_) {
      // Best-effort notification channel — never block the caller.
    }
  }

  /// Driver new job offer — sent when [incidentId] is assigned to
  /// [ambulanceId] and is waiting on that driver's accept/decline.
  Future<void> notifyDriverJobOffer(
      String incidentId, String ambulanceId) async {
    try {
      final ambulance = await supabaseClient
          .from('ambulances')
          .select('driver_id')
          .eq('id', ambulanceId)
          .single();
      final driverId = ambulance['driver_id'] as String?;
      if (driverId == null) return;

      final driverPhone = await _phoneFor(driverId);
      if (driverPhone == null) return;

      final incident = await supabaseClient
          .from('incidents')
          .select('reporter_name, nature_of_emergency')
          .eq('id', incidentId)
          .single();

      final trip = await supabaseClient
          .from('trips')
          .select('distance_km, total_fare')
          .eq('incident_id', incidentId)
          .eq('status', 'requested')
          .order('requested_at', ascending: false)
          .limit(1)
          .maybeSingle();

      final distanceKm = (trip?['distance_km'] as num?)?.toDouble();
      final fare = (trip?['total_fare'] as num?)?.toDouble();
      final distanceText =
          distanceKm != null ? '${distanceKm.toStringAsFixed(1)}km' : 'nearby';
      final fareText = fare != null ? fare.toStringAsFixed(0) : '—';
      final patientName = incident['reporter_name'] as String? ?? 'Patient';
      final emergency =
          incident['nature_of_emergency'] as String? ?? 'Emergency';

      await sendSms(
        phone: driverPhone,
        message: 'ERAMS: New trip request from $patientName. '
            'Emergency: $emergency. Distance: $distanceText. '
            'Fare: UGX $fareText. Open the app to accept within 30 seconds.',
        incidentId: incidentId,
      );
    } catch (_) {}
  }

  /// Patient — driver accepted the trip on [incidentId].
  Future<void> notifyPatientDriverAccepted(String incidentId) async {
    try {
      final incident = await supabaseClient
          .from('incidents')
          .select('reporter_phone, assigned_ambulance_id')
          .eq('id', incidentId)
          .single();
      final patientPhone = incident['reporter_phone'] as String? ?? '';
      if (patientPhone.isEmpty) return;

      String driverName = 'Your driver';
      String plateNumber = '';
      final ambulanceId = incident['assigned_ambulance_id'] as String?;
      if (ambulanceId != null) {
        final ambulance = await supabaseClient
            .from('ambulances')
            .select('plate_number, driver_id')
            .eq('id', ambulanceId)
            .single();
        plateNumber = ambulance['plate_number'] as String? ?? '';
        final driverId = ambulance['driver_id'] as String?;
        if (driverId != null) {
          final profile = await supabaseClient
              .from('profiles')
              .select('full_name')
              .eq('id', driverId)
              .maybeSingle();
          driverName = profile?['full_name'] as String? ?? driverName;
        }
      }

      final trip = await supabaseClient
          .from('trips')
          .select('distance_km')
          .eq('incident_id', incidentId)
          .eq('status', 'accepted')
          .order('requested_at', ascending: false)
          .limit(1)
          .maybeSingle();
      final distanceKm = (trip?['distance_km'] as num?)?.toDouble();
      final etaText =
          distanceKm != null ? '${(distanceKm / 40 * 60).ceil()} min' : 'shortly';

      await sendSms(
        phone: patientPhone,
        message: 'ERAMS: Driver $driverName ($plateNumber) has accepted '
            'your request. ETA approx $etaText. Track live in the app.',
        incidentId: incidentId,
      );
    } catch (_) {}
  }

  /// Patient — driver has arrived at the scene for [incidentId].
  Future<void> notifyPatientDriverArrived(String incidentId) async {
    try {
      final incident = await supabaseClient
          .from('incidents')
          .select('reporter_phone')
          .eq('id', incidentId)
          .single();
      final phone = incident['reporter_phone'] as String? ?? '';
      if (phone.isEmpty) return;

      await sendSms(
        phone: phone,
        message: 'ERAMS: Your ambulance has arrived.',
        incidentId: incidentId,
      );
    } catch (_) {}
  }

  /// Hospital — incoming patient notification for [incidentId], sent once
  /// the incident is dispatched to a hospital-assigned ambulance.
  Future<void> notifyHospitalIncomingPatient(String incidentId) async {
    try {
      final incident = await supabaseClient
          .from('incidents')
          .select('assigned_hospital_id, assigned_ambulance_id, '
              'location_description, nature_of_emergency, '
              'patient_condition_notes, incident_location')
          .eq('id', incidentId)
          .single();

      final hospitalId = incident['assigned_hospital_id'] as String?;
      if (hospitalId == null) return;

      final hospital = await supabaseClient
          .from('hospitals')
          .select('contact_phone')
          .eq('id', hospitalId)
          .single();
      final hospitalPhone = hospital['contact_phone'] as String? ?? '';
      if (hospitalPhone.isEmpty) return;

      int? etaMinutes;
      final ambulanceId = incident['assigned_ambulance_id'] as String?;
      if (ambulanceId != null) {
        final ambulance = await supabaseClient
            .from('ambulances')
            .select('current_location')
            .eq('id', ambulanceId)
            .single();
        final ambLat = geoLat(ambulance['current_location']);
        final ambLng = geoLng(ambulance['current_location']);
        final incLat = geoLat(incident['incident_location']);
        final incLng = geoLng(incident['incident_location']);
        if (ambLat != null && ambLng != null && incLat != null && incLng != null) {
          final km = const Distance().as(
            LengthUnit.Kilometer,
            LatLng(ambLat, ambLng),
            LatLng(incLat, incLng),
          );
          etaMinutes = (km / 40 * 60).ceil();
        }
      }

      final location =
          (incident['location_description'] as String?)?.trim();
      final condition =
          (incident['patient_condition_notes'] as String?)?.trim();
      final emergency =
          incident['nature_of_emergency'] as String? ?? 'Emergency';

      await sendSms(
        phone: hospitalPhone,
        message: 'ERAMS: Incoming patient from '
            '${(location?.isNotEmpty ?? false) ? location : 'reported location'}. '
            'Emergency: $emergency. '
            'ETA approx ${etaMinutes != null ? '$etaMinutes min' : 'shortly'}. '
            'Condition: ${(condition?.isNotEmpty ?? false) ? condition : 'Not specified'}.',
        incidentId: incidentId,
      );
    } catch (_) {}
  }

  Future<String?> _phoneFor(String profileId) async {
    final profile = await supabaseClient
        .from('profiles')
        .select('phone')
        .eq('id', profileId)
        .maybeSingle();
    final phone = profile?['phone'] as String?;
    return (phone == null || phone.isEmpty) ? null : phone;
  }
}
