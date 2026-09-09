-- ============================================================
-- Migration 021 — Fix dispatch_incident overload conflict
-- ============================================================
-- Migration 020 re-created a dispatch_incident(uuid, uuid) overload to add
-- the "already busy" guard, not realising migration 011 had already dropped
-- that 2-arg signature in favour of a 3-arg one (p_incident_id, p_ambulance_id,
-- p_patient_id) that both the dispatcher manual-dispatch flow and the patient
-- request flow actually call. With both overloads present, PostgREST cannot
-- resolve a call that only supplies 2 named params (PGRST203: "Could not
-- choose the best candidate function") — this broke manual dispatch and
-- patient ambulance requests entirely.
--
-- Fix: drop the erroneous 2-arg overload and re-apply the busy-ambulance
-- guard to the real 3-arg function.
-- ============================================================

DROP FUNCTION IF EXISTS public.dispatch_incident(uuid, uuid);

CREATE OR REPLACE FUNCTION public.dispatch_incident(
  p_incident_id   uuid,
  p_ambulance_id  uuid  DEFAULT NULL,
  p_patient_id    uuid  DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role         text;
  v_incident     incidents%ROWTYPE;
  v_ambulance    ambulances%ROWTYPE;
  v_ambulance_id uuid;
  v_is_patient   boolean;
  v_new_status   text;
  v_dist_km      numeric;
BEGIN
  -- Auth check
  SELECT role INTO v_role FROM profiles WHERE id = auth.uid();
  IF v_role NOT IN ('dispatcher', 'admin', 'patient') THEN
    RAISE EXCEPTION 'unauthorized';
  END IF;
  -- Patients must always supply their own patient_id
  IF v_role = 'patient' THEN
    IF p_patient_id IS NULL OR p_patient_id != auth.uid() THEN
      RAISE EXCEPTION 'unauthorized';
    END IF;
  END IF;

  v_is_patient := p_patient_id IS NOT NULL;

  -- Lock the incident row
  SELECT * INTO v_incident FROM incidents WHERE id = p_incident_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'incident_not_found'; END IF;
  IF v_incident.status != 'logged' THEN RAISE EXCEPTION 'incident_already_dispatched'; END IF;

  -- Resolve ambulance
  IF p_ambulance_id IS NOT NULL THEN
    SELECT * INTO v_ambulance FROM ambulances WHERE id = p_ambulance_id FOR UPDATE;
    IF NOT FOUND OR v_ambulance.status != 'available' THEN
      RAISE EXCEPTION 'no_ambulance_available';
    END IF;
    v_ambulance_id := p_ambulance_id;
  ELSE
    SELECT id INTO v_ambulance_id
    FROM ambulances
    WHERE status = 'available' AND current_location IS NOT NULL
    ORDER BY current_location <-> v_incident.incident_location
    LIMIT 1;
    IF v_ambulance_id IS NULL THEN RAISE EXCEPTION 'no_ambulance_available'; END IF;
    SELECT * INTO v_ambulance FROM ambulances WHERE id = v_ambulance_id;
  END IF;

  -- Reject if the resolved ambulance already has an incident in progress —
  -- defense-in-depth against the ambulances.status field being out of sync
  -- with reality (see migration 020's changelog note).
  IF EXISTS (
    SELECT 1 FROM incidents
    WHERE assigned_ambulance_id = v_ambulance_id
      AND status IN ('pending_acceptance', 'dispatched', 'en_route', 'arrived')
  ) THEN
    RAISE EXCEPTION 'ambulance_already_busy: ambulance % already has an active incident', v_ambulance_id;
  END IF;

  -- Status: patient trips wait for driver acceptance; dispatcher trips go straight to dispatched
  v_new_status := CASE WHEN v_is_patient THEN 'pending_acceptance' ELSE 'dispatched' END;

  UPDATE incidents
  SET assigned_ambulance_id = v_ambulance_id,
      status                = v_new_status,
      dispatched_at         = CASE WHEN v_is_patient THEN NULL ELSE now() END
  WHERE id = p_incident_id;

  -- Lock ambulance immediately for dispatcher/admin; leave available until driver accepts for patient
  IF NOT v_is_patient THEN
    UPDATE ambulances SET status = 'dispatched' WHERE id = v_ambulance_id;
  END IF;

  -- Create trips row for patient flow, with fare snapshot and distance estimate
  IF v_is_patient THEN
    -- Estimate distance (km) from ambulance to incident, if both have locations
    IF v_ambulance.current_location IS NOT NULL AND v_incident.incident_location IS NOT NULL THEN
      v_dist_km := ROUND(
        (ST_Distance(
          v_ambulance.current_location::geography,
          v_incident.incident_location::geography
        ) / 1000.0)::numeric,
        3
      );
    ELSE
      v_dist_km := NULL;
    END IF;

    INSERT INTO trips (
      incident_id,
      patient_id,
      ambulance_id,
      driver_id,
      status,
      base_fare,
      price_per_km,
      distance_km,
      total_fare,
      payment_method
    ) VALUES (
      p_incident_id,
      p_patient_id,
      v_ambulance_id,
      v_ambulance.driver_id,
      'requested',
      v_ambulance.base_fare,
      v_ambulance.price_per_km,
      v_dist_km,
      CASE
        WHEN v_dist_km IS NOT NULL
        THEN ROUND((v_ambulance.base_fare + v_dist_km * v_ambulance.price_per_km)::numeric, 2)
        ELSE v_ambulance.base_fare
      END,
      'cash'  -- default; updated by Phase 14 payment flow
    );
  END IF;

  -- Audit row
  INSERT INTO incident_events (incident_id, event_type, payload, actor_id)
  VALUES (
    p_incident_id,
    'status_change',
    jsonb_build_object(
      'from',         v_incident.status,
      'to',           v_new_status,
      'ambulance_id', v_ambulance_id,
      'manual',       p_ambulance_id IS NOT NULL,
      'patient',      v_is_patient
    )::text,
    auth.uid()
  );

  RETURN jsonb_build_object(
    'incident_id',  p_incident_id,
    'ambulance_id', v_ambulance_id,
    'status',       v_new_status,
    'is_patient',   v_is_patient
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.dispatch_incident(uuid, uuid, uuid) TO authenticated;
