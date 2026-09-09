-- ============================================================
-- Migration 024 — Never offer/assign a trip to a driverless ambulance
-- ============================================================
-- Bug: nearby_ambulances(), dispatch_incident()'s auto-assign path, and
-- decline_trip()'s reassignment path all pick an ambulance by
-- `status = 'available' AND current_location IS NOT NULL`, with no check
-- that the ambulance actually has a driver_id. When one of those paths
-- lands on a driverless ambulance, the resulting incident sits in
-- pending_acceptance forever: nobody is logged in to see the job-offer
-- countdown, and decline_trip()'s own auth check requires the caller to
-- be the assigned ambulance's driver, so nobody can ever accept or
-- decline it either. Observed live: a driver's 30s job-offer countdown
-- expired, auto-declined, and reassigned to a driverless ambulance,
-- permanently stranding the incident.
--
-- Fix: require driver_id IS NOT NULL wherever an ambulance is picked
-- automatically (auto-dispatch, decline-reassignment, and the patient-
-- facing "available ambulances" list they can pick from). Manual
-- dispatcher override is untouched — a dispatcher explicitly choosing a
-- specific ambulance is a deliberate action, not an auto-pick.
-- ============================================================

-- ── nearby_ambulances: patient-facing pick list ──────────────────────────
CREATE OR REPLACE FUNCTION public.nearby_ambulances(
    p_lat  DOUBLE PRECISION,
    p_lng  DOUBLE PRECISION
)
RETURNS SETOF public.ambulances
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT a.*
    FROM   public.ambulances a
    WHERE  a.status = 'available'
       AND a.current_location IS NOT NULL
       AND a.driver_id IS NOT NULL
       AND NOT EXISTS (
           SELECT 1 FROM public.incidents i
           WHERE i.assigned_ambulance_id = a.id
             AND i.status IN ('pending_acceptance', 'dispatched', 'en_route', 'arrived')
       )
    ORDER BY a.current_location <->
             ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
    LIMIT  20;
$$;

GRANT EXECUTE ON FUNCTION public.nearby_ambulances TO authenticated;

-- ── dispatch_incident: auto-assign path only ─────────────────────────────
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
    WHERE status = 'available' AND current_location IS NOT NULL AND driver_id IS NOT NULL
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

-- ── decline_trip: reassignment path ──────────────────────────────────────
CREATE OR REPLACE FUNCTION public.decline_trip(p_incident_id uuid)
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

  -- Grab patient info before cancelling the trips row
  SELECT patient_id, payment_method
  INTO v_patient_id, v_payment_method
  FROM trips
  WHERE incident_id = p_incident_id AND status = 'requested'
  LIMIT 1;

  -- Cancel this offer
  UPDATE trips
  SET status = 'cancelled', cancelled_at = now(), cancel_reason = 'driver_declined'
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
        'offered_to',  v_next_amb_id
      )::text,
      auth.uid()
    );

    RETURN jsonb_build_object(
      'status',            'pending_acceptance',
      'next_ambulance_id', v_next_amb_id
    );
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

    RETURN jsonb_build_object('status', 'logged', 'message', 'no_ambulance_available');
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.decline_trip(uuid) TO authenticated;
