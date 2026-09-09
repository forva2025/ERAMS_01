-- ============================================================
-- Migration 025 — accept_trip: diagnose the "unauthorized" 400
-- ============================================================
-- A driver got a generic `unauthorized` error accepting a job offer even
-- though the underlying data was consistent (incident pending_acceptance,
-- assigned to an ambulance whose driver_id matched the driver's own
-- profile). That data consistency rules out a bad row and points at
-- auth.uid() not resolving to what the client UI shows at RPC time (e.g.
-- an expired/stale session token, or a second account signed in without a
-- page reload). This migration doesn't change accept_trip's behavior —
-- only makes each unauthorized/invalid_status branch report exactly which
-- check failed and with what values, so the next failure is diagnosable
-- from the SnackBar/network response alone.
-- ============================================================

CREATE OR REPLACE FUNCTION public.accept_trip(p_incident_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_incident     incidents%ROWTYPE;
  v_ambulance_id uuid;
  v_uid          uuid;
  v_role         text;
BEGIN
  v_uid := auth.uid();
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'unauthorized: no authenticated user (auth.uid() is null — session/JWT missing or expired)';
  END IF;

  SELECT role INTO v_role FROM profiles WHERE id = v_uid;
  IF v_role IS NULL THEN
    RAISE EXCEPTION 'unauthorized: no profile row for uid %', v_uid;
  END IF;
  IF v_role != 'driver' THEN
    RAISE EXCEPTION 'unauthorized: uid % has role %, expected driver', v_uid, v_role;
  END IF;

  SELECT * INTO v_incident FROM incidents WHERE id = p_incident_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'incident_not_found: %', p_incident_id; END IF;
  IF v_incident.status != 'pending_acceptance' THEN
    RAISE EXCEPTION 'invalid_status: incident % has status %, expected pending_acceptance',
      p_incident_id, v_incident.status;
  END IF;

  v_ambulance_id := v_incident.assigned_ambulance_id;

  -- Verify the calling driver owns this ambulance
  IF NOT EXISTS (
    SELECT 1 FROM ambulances WHERE id = v_ambulance_id AND driver_id = v_uid
  ) THEN
    RAISE EXCEPTION 'unauthorized: uid % does not own ambulance % (incident %)',
      v_uid, v_ambulance_id, p_incident_id;
  END IF;

  -- Accept: move to dispatched
  UPDATE incidents
  SET status = 'dispatched', dispatched_at = now()
  WHERE id = p_incident_id;

  UPDATE ambulances SET status = 'dispatched' WHERE id = v_ambulance_id;

  UPDATE trips
  SET status = 'accepted', accepted_at = now()
  WHERE incident_id = p_incident_id AND status = 'requested';

  INSERT INTO incident_events (incident_id, event_type, payload, actor_id)
  VALUES (
    p_incident_id,
    'status_change',
    jsonb_build_object('from', 'pending_acceptance', 'to', 'dispatched')::text,
    v_uid
  );

  RETURN jsonb_build_object('status', 'dispatched');
END;
$$;

GRANT EXECUTE ON FUNCTION public.accept_trip(uuid) TO authenticated;
