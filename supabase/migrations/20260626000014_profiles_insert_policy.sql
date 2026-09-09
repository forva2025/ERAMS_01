-- Migration 014: Allow authenticated users to INSERT their own profile row.
-- The handle_new_user trigger creates the profile via SECURITY DEFINER, so
-- this policy is a safety net for any edge case where the client needs to
-- write a profile row directly (e.g. trigger delay, manual recovery).
-- Without this policy, upsert/insert on profiles returns 403 for all users.

DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;

CREATE POLICY "profiles_insert_own"
ON public.profiles FOR INSERT TO authenticated
WITH CHECK (id = auth.uid());
