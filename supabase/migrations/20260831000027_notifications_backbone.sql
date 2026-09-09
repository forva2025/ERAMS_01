-- ============================================================
-- Migration 027 — Notification backbone
--
-- Adds a generic `notifications` table + `device_tokens` table so any
-- SECURITY DEFINER RPC can push a per-user notification that (a) shows up
-- in-app via Realtime and (b) fans out to a real device push via the
-- send_push_notification edge function (triggered by a Database Webhook on
-- INSERT, configured in the Supabase Dashboard — not part of this
-- migration, same category as Auth settings).
--
-- This does NOT touch the existing foreground job-offer flow
-- (DriverIncidentNotifier's Realtime-on-`incidents` subscription in
-- driver_provider.dart) — that stays the fast path while the app is open.
-- notifications/push exist purely to cover the backgrounded/killed-app
-- case, so there is no risk of a duplicate in-app dialog.
-- ============================================================

-- ── notifications ──────────────────────────────────────────────────────
CREATE TABLE public.notifications (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    type        TEXT NOT NULL CHECK (type IN (
                    'job_offer',            -- driver: new/reassigned incident pending acceptance
                    'incident_dispatched',  -- driver: dispatcher manually assigned (no accept/decline needed)
                    'trip_accepted',        -- patient: driver accepted
                    'trip_rejected',        -- patient: driver declined (+ reason, + hospital advisory)
                    'rejection_followup',   -- dispatcher: a patient trip was declined, needs follow-up
                    'incoming_call',        -- callee: someone is calling
                    'driver_arrived'
                 )),
    title       TEXT NOT NULL,
    body        TEXT NOT NULL,
    data        JSONB NOT NULL DEFAULT '{}'::jsonb,
    read_at     TIMESTAMPTZ,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX notifications_user_id_created_idx
    ON public.notifications (user_id, created_at DESC);

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notifications_select_own"
ON public.notifications FOR SELECT TO authenticated
USING (user_id = auth.uid());

CREATE POLICY "notifications_update_own"
ON public.notifications FOR UPDATE TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

-- Deliberately no INSERT policy for `authenticated` — every row is created
-- from inside a SECURITY DEFINER function (create_notification below),
-- which bypasses RLS. This prevents any authenticated user from writing
-- directly into another user's notification inbox.

ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;

-- ── device_tokens ──────────────────────────────────────────────────────
CREATE TABLE public.device_tokens (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    fcm_token     TEXT NOT NULL UNIQUE,
    platform      TEXT NOT NULL CHECK (platform IN ('android', 'ios', 'web')),
    device_info   TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_seen_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX device_tokens_user_id_idx ON public.device_tokens (user_id);

ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "device_tokens_select_own"
ON public.device_tokens FOR SELECT TO authenticated
USING (user_id = auth.uid());

CREATE POLICY "device_tokens_insert_own"
ON public.device_tokens FOR INSERT TO authenticated
WITH CHECK (user_id = auth.uid());

CREATE POLICY "device_tokens_update_own"
ON public.device_tokens FOR UPDATE TO authenticated
USING (user_id = auth.uid())
WITH CHECK (user_id = auth.uid());

CREATE POLICY "device_tokens_delete_own"
ON public.device_tokens FOR DELETE TO authenticated
USING (user_id = auth.uid());

-- ── create_notification() helper ─────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.create_notification(
  p_user_id UUID,
  p_type    TEXT,
  p_title   TEXT,
  p_body    TEXT,
  p_data    JSONB DEFAULT '{}'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_id UUID;
BEGIN
  INSERT INTO notifications (user_id, type, title, body, data)
  VALUES (p_user_id, p_type, p_title, p_body, p_data)
  RETURNING id INTO v_id;
  RETURN v_id;
END;
$$;

-- Intentionally NOT granted to `authenticated` — only reachable from inside
-- other SECURITY DEFINER functions (which run as the owning role and thus
-- already hold implicit EXECUTE). Stops any authenticated user from calling
-- this directly to spam notifications into another user's inbox.
REVOKE ALL ON FUNCTION public.create_notification(UUID, TEXT, TEXT, TEXT, JSONB) FROM PUBLIC;

-- ── accept_trip: notify the patient when a driver accepts ───────────────
-- Same body as migration 025, +1 SELECT (patient_id) +1 PERFORM at the end.
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
  v_patient_id   uuid;
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
  WHERE incident_id = p_incident_id AND status = 'requested'
  RETURNING patient_id INTO v_patient_id;

  INSERT INTO incident_events (incident_id, event_type, payload, actor_id)
  VALUES (
    p_incident_id,
    'status_change',
    jsonb_build_object('from', 'pending_acceptance', 'to', 'dispatched')::text,
    v_uid
  );

  IF v_patient_id IS NOT NULL THEN
    PERFORM public.create_notification(
      v_patient_id, 'trip_accepted', 'Ambulance on the way',
      'A driver has accepted your request and is heading to you.',
      jsonb_build_object('incidentId', p_incident_id)
    );
  END IF;

  RETURN jsonb_build_object('status', 'dispatched');
END;
$$;

GRANT EXECUTE ON FUNCTION public.accept_trip(uuid) TO authenticated;

-- ── dispatch_incident: notify the driver of a new/direct assignment ─────
-- Same body as migration 024, +2 PERFORM (patient-initiated job offer,
-- dispatcher-initiated direct assignment).
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

    IF v_ambulance.driver_id IS NOT NULL THEN
      PERFORM public.create_notification(
        v_ambulance.driver_id, 'incident_dispatched', 'New dispatch assigned',
        'Dispatch has assigned you a new incident.',
        jsonb_build_object('incidentId', p_incident_id)
      );
    END IF;
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

    IF v_ambulance.driver_id IS NOT NULL THEN
      PERFORM public.create_notification(
        v_ambulance.driver_id, 'job_offer', 'New trip request',
        'A patient near you needs an ambulance. Respond within 30 seconds.',
        jsonb_build_object('incidentId', p_incident_id)
      );
    END IF;
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
