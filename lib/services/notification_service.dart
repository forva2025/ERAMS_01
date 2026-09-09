import '../models/app_notification.dart';
import 'supabase_service.dart';

class NotificationService {
  Future<List<AppNotification>> fetchRecent({int limit = 50}) async {
    final userId = supabaseClient.auth.currentUser?.id;
    if (userId == null) return [];
    final data = await supabaseClient
        .from('notifications')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);
    return (data as List)
        .map((row) => AppNotification.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> markRead(String id) async {
    await supabaseClient
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('id', id);
  }
}
