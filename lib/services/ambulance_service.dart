import '../models/ambulance.dart';
import 'supabase_service.dart';

class AmbulanceService {
  Future<List<Ambulance>> fetchAllAmbulances() async {
    final data = await supabaseClient.from('ambulances').select();
    return (data as List).map((e) => Ambulance.fromJson(e as Map<String, dynamic>)).toList();
  }
}
