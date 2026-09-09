-- ============================================================
-- Migration 022 — Patient trip cancellation
-- ============================================================
-- Patients had no way to cancel a request once submitted: incidents has
-- no patient UPDATE policy (only dispatcher/admin/assigned-driver can
-- write to it), so the previous status column edits available to a
-- patient (via trips_update_patient_own) never touched incidents.status.
--
-- cancel_trip() lets the requesting patient cancel their own incident at
-- any stage before it's completed or already cancelled, closes out the
-- trips row, and frees the assigned ambulance back to 'available' unless
-- it's still legitimately busy with a different active incident.
-- ============================================================

CREATE OR REPLACE FUNCTION public.cancel_trip(
  p_incident_id uuid,
  p_reason      text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_incident     incidents%ROWTYPE;
  v_trip         trips%ROWTYPE;
  v_ambulance_id uuid;
BEGIN
  IF (SELECT role FROM profiles WHERE id = auth.uid()) != 'patient' THEN
    RAISE EXCEPTION 'unauthorized: only the requesting patient can cancel via this function';
  END IF;

  SELECT * INTO v_incident FROM incidents WHERE id = p_incident_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'incident_not_found';
  END IF;

  -- Ownership: incidents has no patient_id column, so verify via trips.
  SELECT * INTO v_trip
  FROM trips
  WHERE incident_id = p_incident_id AND patient_id = auth.uid()
  ORDER BY requested_at DESC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'unauthorized: this trip does not belong to you';
  END IF;

  IF v_incident.status IN ('completed', 'cancelled') THEN
    RAISE EXCEPTION 'trip_already_closed: current status is %', v_incident.status;
  END IF;

  v_ambulance_id := v_incident.assigned_ambulance_id;

  UPDATE incidents
  SET status = 'cancelled'
  WHERE id = p_incident_id;

  UPDATE trips
  SET status        = 'cancelled',
      cancelled_at  = now(),
      cancel_reason = COALESCE(p_reason, 'patient_cancelled')
  WHERE id = v_trip.id;

  -- Free the ambulance, but only if nothing else active is relying on it
  -- (mirrors the guard added in migration 021).
  IF v_ambulance_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM incidents
    WHERE assigned_ambulance_id = v_ambulance_id
      AND id != p_incident_id
      AND status IN ('pending_acceptance', 'dispatched', 'en_route', 'arrived')
  ) THEN
    UPDATE ambulances SET status = 'available' WHERE id = v_ambulance_id;
  END IF;

  INSERT INTO incident_events (incident_id, event_type, payload, actor_id)
  VALUES (
    p_incident_id,
    'status_change',
    jsonb_build_object(
      'from',   v_incident.status,
      'to',     'cancelled',
      'reason', COALESCE(p_reason, 'patient_cancelled')
    )::text,
    auth.uid()
  );

  RETURN jsonb_build_object('status', 'cancelled');
END;
$$;

GRANT EXECUTE ON FUNCTION public.cancel_trip(uuid, text) TO authenticated;
