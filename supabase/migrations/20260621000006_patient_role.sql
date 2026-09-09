-- Migration 006: Add 'patient' role to profiles.role constraint
-- and add RLS policies so patients can browse ambulances and create incidents.

-- 1. Extend the role CHECK constraint
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles
    ADD CONSTRAINT profiles_role_check
    CHECK (role IN ('dispatcher', 'driver', 'hospital', 'admin', 'patient'));

-- 2. Patients can read all ambulances (needed for the marketplace / map view)
CREATE POLICY "ambulances_select_patient"
ON public.ambulances FOR SELECT TO authenticated
USING (public.current_user_role() = 'patient');

-- 3. Patients can create incidents (self-service booking)
CREATE POLICY "incidents_insert_patient"
ON public.incidents FOR INSERT TO authenticated
WITH CHECK (public.current_user_role() = 'patient');

-- Note: incidents_select_patient_own is added in migration 008 after the
-- trips table exists (the policy references trips.patient_id).
