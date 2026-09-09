import '../models/call.dart';
import 'supabase_service.dart';

class CallService {
  Future<Call> startCall({required String incidentId, required bool isVideo}) async {
    final data = await supabaseClient.rpc('start_call', params: {
      'p_incident_id': incidentId,
      'p_is_video': isVideo,
    });
    return Call.fromJson(data as Map<String, dynamic>);
  }

  Future<void> updateStatus(String callId, String status) async {
    final now = DateTime.now().toIso8601String();
    final patch = <String, dynamic>{'status': status};
    if (status == 'accepted') patch['answered_at'] = now;
    if (status == 'declined' || status == 'ended' || status == 'missed') {
      patch['ended_at'] = now;
    }
    await supabaseClient.from('calls').update(patch).eq('id', callId);
  }
}
