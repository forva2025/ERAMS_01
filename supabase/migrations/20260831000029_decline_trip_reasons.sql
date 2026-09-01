-- ============================================================
-- Migration 029 — Driver rejection reasons
--
-- Brings back an explicit decline path with a structured reason: crew not
-- qualified/equipped for the case, trip outside the ambulance's operational
-- area, patient needs a higher level of care, or unsafe access conditions
-- (inaccessible location, active violence, fire, dangerous terrain). The
-- 30s auto-decline-on-timeout path (unchanged in the UI) defaults to a
-- 'timeout' category so every declined trips row has one.
--
-- New dedicated columns rather than overloading `trips.cancel_reason` —
-- that field is already hardcoded to the literal 'driver_declined' and
-- reused by other cancel paths (e.g. patient-initiated cancellation),
-- overloading it would break those other readers.
-- ============================================================

-- Migration 021's changelog documents PostgREST's "Could not choose the best
-- candidate function" (PGRST203) when two overloads of the same RPC name
-- coexist — must drop the old 1-arg signature before creating the 3-arg one
-- below, or every existing decline_trip(p_incident_id) call breaks.
DROP FUNCTION IF EXISTS public.decline_trip(uuid);

ALTER TABLE public.trips
  ADD COLUMN reject_reason_category TEXT
    CHECK (reject_reason_category IS NULL OR reject_reason_category IN (
      'crew_not_qualified',         -- crew not qualified for the case / lacks required equipment
      'outside_operational_area',   -- trip is outside the ambulance's operational area
      'needs_higher_level_of_care', -- patient needs a higher level of care than this ambulance can provide
      'unsafe_access_conditions',   -- inaccessible location, active violence, fire, dangerous terrain
      'timeout'                     -- auto-declined: 30s job-offer countdown expired, no reason given
    )),
  ADD COLUMN reject_reason_notes TEXT;

CREATE OR REPLACE FUNCTION public.decline_trip(
  p_incident_id     uuid,
  p_reason_category text DEFAULT NULL,
  p_reason_notes    text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_incident        incidents%ROWTYPE;
  v_declined_amb_id uuid;
  v_next_amb_id     uuid;
  v_next_ambulance  ambulances%ROWTYPE;
  v_patient_id      uuid;
  v_payment_method  text;
  v_dist_km         numeric;
  v_category        text;
  v_hospitals       jsonb;
BEGIN
  IF (SELECT role FROM profiles WHERE id = auth.uid()) != 'driver' THEN
    RAISE EXCEPTION 'unauthorized';
  END IF;

  SELECT * INTO v_incident FROM incidents WHERE id = p_incident_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'incident_not_found'; END IF;
  IF v_incident.status != 'pending_acceptance' THEN RAISE EXCEPTION 'invalid_status'; END IF;

  v_declined_amb_id := v_incident.assigned_ambulance_id;

  -- Verify calling driver owns the declining ambulance
  IF NOT EXISTS (
    SELECT 1 FROM ambulances WHERE id = v_declined_amb_id AND driver_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'unauthorized';
  END IF;

  v_category := COALESCE(p_reason_category, 'timeout');
  IF v_category NOT IN ('crew_not_qualified', 'outside_operational_area',
                         'needs_higher_level_of_care', 'unsafe_access_conditions', 'timeout') THEN
    RAISE EXCEPTION 'invalid_reason_category: %', v_category;
  END IF;

  -- Grab patient info before cancelling the trips row
  SELECT patient_id, payment_method
  INTO v_patient_id, v_payment_method
  FROM trips
  WHERE incident_id = p_incident_id AND status = 'requested'
  LIMIT 1;

  -- Cancel this offer, recording the reason
  UPDATE trips
  SET status = 'cancelled', cancelled_at = now(), cancel_reason = 'driver_declined',
      reject_reason_category = v_category, reject_reason_notes = p_reason_notes
  WHERE incident_id = p_incident_id AND status = 'requested';

  -- Find next nearest available ambulance with a linked driver, skipping the one that declined
  SELECT * INTO v_next_ambulance
  FROM ambulances
  WHERE status = 'available'
    AND current_location IS NOT NULL
    AND driver_id IS NOT NULL
    AND id != v_declined_amb_id
  ORDER BY current_location <-> v_incident.incident_location
  LIMIT 1;

  IF v_next_ambulance.id IS NOT NULL THEN
    v_next_amb_id := v_next_ambulance.id;

    -- Re-assign incident to next driver (status stays pending_acceptance)
    UPDATE incidents
    SET assigned_ambulance_id = v_next_amb_id
    WHERE id = p_incident_id;

    -- Estimate distance to next ambulance
    IF v_next_ambulance.current_location IS NOT NULL AND v_incident.incident_location IS NOT NULL THEN
      v_dist_km := ROUND(
        (ST_Distance(
          v_next_ambulance.current_location::geography,
          v_incident.incident_location::geography
        ) / 1000.0)::numeric,
        3
      );
    ELSE
      v_dist_km := NULL;
    END IF;

    -- Create new trips row for next driver
    INSERT INTO trips (
      incident_id, patient_id, ambulance_id, driver_id,
      status, base_fare, price_per_km, distance_km, total_fare, payment_method
    ) VALUES (
      p_incident_id,
      v_patient_id,
      v_next_amb_id,
      v_next_ambulance.driver_id,
      'requested',
      v_next_ambulance.base_fare,
      v_next_ambulance.price_per_km,
      v_dist_km,
      CASE
        WHEN v_dist_km IS NOT NULL
        THEN ROUND((v_next_ambulance.base_fare + v_dist_km * v_next_ambulance.price_per_km)::numeric, 2)
        ELSE v_next_ambulance.base_fare
      END,
      COALESCE(v_payment_method, 'cash')
    );

    INSERT INTO incident_events (incident_id, event_type, payload, actor_id)
    VALUES (
      p_incident_id,
      'status_change',
      jsonb_build_object(
        'declined_by', v_declined_amb_id,
        'offered_to',  v_next_amb_id,
        'reason',      v_category
      )::text,
      auth.uid()
    );

    IF v_next_ambulance.driver_id IS NOT NULL THEN
      PERFORM public.create_notification(
        v_next_ambulance.driver_id, 'job_offer', 'New trip request',
        'A patient near you needs an ambulance. Respond within 30 seconds.',
        jsonb_build_object('incidentId', p_incident_id)
      );
    END IF;
  ELSE
    -- No more ambulances available: reset incident so patient can retry
    UPDATE incidents
    SET status = 'logged', assigned_ambulance_id = NULL
    WHERE id = p_incident_id;

    INSERT INTO incident_events (incident_id, event_type, payload, actor_id)
    VALUES (
      p_incident_id,
      'status_change',
      jsonb_build_object(
        'from',   'pending_acceptance',
        'to',     'logged',
        'reason', 'no_ambulance_available'
      )::text,
      auth.uid()
    );
  END IF;

  -- Nearest-3-hospitals advisory for the patient (by distance from incident location)
  SELECT jsonb_agg(jsonb_build_object('name', h.name, 'phone', h.contact_phone))
  INTO v_hospitals
  FROM (
    SELECT name, contact_phone FROM hospitals
    WHERE location IS NOT NULL AND contact_phone <> ''
    ORDER BY location <-> v_incident.incident_location
    LIMIT 3
  ) h;

  IF v_patient_id IS NOT NULL THEN
    PERFORM public.create_notification(
      v_patient_id, 'trip_rejected', 'Your ambulance request was declined',
      CASE WHEN v_next_amb_id IS NOT NULL
        THEN 'The assigned driver declined your trip; we are contacting the next nearest ambulance.'
        ELSE 'The assigned driver declined your trip and no other ambulance is currently available nearby. Please contact a hospital directly below.'
      END,
      jsonb_build_object(
        'incidentId', p_incident_id, 'reasonCategory', v_category, 'reasonNotes', p_reason_notes,
        'reassigned', v_next_amb_id IS NOT NULL, 'hospitals', COALESCE(v_hospitals, '[]'::jsonb)
      )
    );
  END IF;

  -- Fan out to every dispatcher — no single "assigned dispatcher" concept
  -- exists in this schema, so all of them are notified to follow up.
  INSERT INTO notifications (user_id, type, title, body, data)
  SELECT id, 'rejection_followup', 'Driver declined a dispatch',
    'A driver declined incident ' || p_incident_id || ' (' || v_category || '). Follow-up may be needed.',
    jsonb_build_object('incidentId', p_incident_id, 'reasonCategory', v_category, 'reasonNotes', p_reason_notes)
  FROM profiles WHERE role = 'dispatcher';

  IF v_next_amb_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'status', 'pending_acceptance', 'next_ambulance_id', v_next_amb_id, 'reason_category', v_category
    );
  ELSE
    RETURN jsonb_build_object(
      'status', 'logged', 'message', 'no_ambulance_available', 'reason_category', v_category
    );
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.decline_trip(uuid, text, text) TO authenticated;
