-- Migration 015: Fix messages RLS policies
-- The policies from migration 013 were too narrow:
--   • Drivers were checked via trips.driver_id — but dispatcher-created incidents
--     don't create trip rows, so drivers couldn't read/send messages.
--   • Hospital staff had no coverage at all.
-- This migration drops the broken policies and replaces them with correct ones.

-- ── Drop old policies ──────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "read incident messages"  ON public.messages;
DROP POLICY IF EXISTS "send incident messages"  ON public.messages;

-- ── Helper: is the current user a participant in this incident? ────────────────
-- Used by both SELECT and INSERT.  Defined inline in each policy to keep things
-- readable without needing an extra SQL function.

-- SELECT ───────────────────────────────────────────────────────────────────────
CREATE POLICY "messages_select"
  ON public.messages FOR SELECT TO authenticated
  USING (
    -- dispatchers and admins see everything
    current_user_role() IN ('dispatcher', 'admin')

    -- driver assigned to the incident's ambulance
    OR EXISTS (
      SELECT 1 FROM public.incidents i
      JOIN  public.ambulances a ON a.id = i.assigned_ambulance_id
      WHERE i.id = messages.incident_id
        AND a.driver_id = auth.uid()
    )

    -- hospital staff whose hospital is assigned to the incident
    OR EXISTS (
      SELECT 1 FROM public.incidents i
      WHERE i.id = messages.incident_id
        AND i.assigned_hospital_id = (
          SELECT hospital_id FROM public.profiles WHERE id = auth.uid()
        )
    )

    -- patient who created the incident (dispatcher-logged) or via their trip
    OR EXISTS (
      SELECT 1 FROM public.incidents
      WHERE id = messages.incident_id
        AND created_by = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.trips
      WHERE incident_id = messages.incident_id
        AND patient_id  = auth.uid()
    )
  );

-- INSERT ───────────────────────────────────────────────────────────────────────
CREATE POLICY "messages_insert"
  ON public.messages FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND (
      current_user_role() IN ('dispatcher', 'admin')

      OR EXISTS (
        SELECT 1 FROM public.incidents i
        JOIN  public.ambulances a ON a.id = i.assigned_ambulance_id
        WHERE i.id = messages.incident_id
          AND a.driver_id = auth.uid()
      )

      OR EXISTS (
        SELECT 1 FROM public.incidents i
        WHERE i.id = messages.incident_id
          AND i.assigned_hospital_id = (
            SELECT hospital_id FROM public.profiles WHERE id = auth.uid()
          )
      )

      OR EXISTS (
        SELECT 1 FROM public.incidents
        WHERE id = messages.incident_id
          AND created_by = auth.uid()
      )
      OR EXISTS (
        SELECT 1 FROM public.trips
        WHERE incident_id = messages.incident_id
          AND patient_id  = auth.uid()
      )
    )
  );
