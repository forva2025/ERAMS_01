import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/supabase_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Emits Supabase auth state changes (sign in, sign out, token refresh).
/// Used by GoRouter's refreshListenable to re-evaluate redirects.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  return supabaseClient.auth.onAuthStateChange;
});

/// The currently authenticated user's profile.
/// Null when logged out or while loading.
final currentProfileProvider = FutureProvider<Profile?>((ref) async {
  // Re-fetch whenever auth state changes (login/logout).
  ref.watch(authStateChangesProvider);
  return ref.read(authServiceProvider).currentProfile();
});
