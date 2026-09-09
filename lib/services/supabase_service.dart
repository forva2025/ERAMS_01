import 'package:supabase_flutter/supabase_flutter.dart';

// Convenience accessor — use supabaseClient throughout the app instead of
// Supabase.instance.client directly so it's easy to swap in tests.
SupabaseClient get supabaseClient => Supabase.instance.client;
