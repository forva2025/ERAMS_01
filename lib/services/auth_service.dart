import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/profile.dart';
import 'push_notification_service.dart';
import 'supabase_service.dart';

class AuthService {
  Future<Profile> signIn({
    required String email,
    required String password,
  }) async {
    await supabaseClient.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return _fetchProfile();
  }

  /// Self-registration for patients: creates Supabase auth user + profile row.
  Future<void> registerPatient({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    final res = await supabaseClient.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName, 'role': 'patient', 'phone': phone},
      // Sends the confirmation link back to wherever this app is actually
      // running (the deployed Firebase Hosting URL, or localhost during
      // dev) instead of relying solely on the Supabase project's Site URL
      // default. Must also be added to Authentication → URL Configuration
      // → Redirect URLs in the Supabase Dashboard, or Supabase ignores it.
      emailRedirectTo: kIsWeb ? Uri.base.origin : null,
    );
    final userId = res.user?.id;
    if (userId == null) throw Exception('Registration failed — please try again.');

    // The handle_new_user trigger creates the profile row (SECURITY DEFINER,
    // bypasses RLS). If email confirmation is disabled the session is live
    // immediately, so we also UPDATE to ensure field values are in sync.
    // We never INSERT here — there is no INSERT policy on profiles.
    if (res.session != null) {
      await supabaseClient.from('profiles').update({
        'full_name': fullName,
        'phone': phone,
        'email': email,
        'role': 'patient',
      }).eq('id', userId);
    }
  }

  Future<void> signOut() async {
    // Must run before signOut() — deleting this device's token row needs a
    // still-valid session for the RLS-scoped delete to succeed.
    await PushNotificationService().unregisterCurrentToken();
    await supabaseClient.auth.signOut();
  }

  /// Returns the current user's profile, or null if not authenticated.
  Future<Profile?> currentProfile() async {
    if (supabaseClient.auth.currentUser == null) return null;
    return _fetchProfile();
  }

  Future<Profile> _fetchProfile() async {
    final userId = supabaseClient.auth.currentUser!.id;
    final data = await supabaseClient
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    return Profile.fromJson(data);
  }
}
