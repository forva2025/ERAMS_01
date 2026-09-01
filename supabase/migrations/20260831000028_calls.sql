-- ============================================================
-- Migration 028 — Call signaling
--
-- Adds a `calls` table so a Call button tap can actually notify the other
-- party (Realtime + push via the notifications backbone from migration
-- 027), instead of requiring both people to tap "Call" at the same moment.
-- `channel_name` deliberately reuses the incident id, matching the Agora
-- channel-naming convention already baked into generate_agora_token /
-- AgoraService.joinChannel — no changes needed there.
-- ============================================================

CREATE TABLE public.calls (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_id   UUID NOT NULL REFERENCES public.incidents(id) ON DELETE CASCADE,
    caller_id     UUID NOT NULL REFERENCES public.profiles(id),
    callee_id     UUID NOT NULL REFERENCES public.profiles(id),
    channel_name  TEXT NOT NULL,
    is_video      BOOLEAN NOT NULL DEFAULT FALSE,
    status        TEXT NOT NULL DEFAULT 'ringing'
                    CHECK (status IN ('ringing', 'accepted', 'declined', 'ended', 'missed')),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    answered_at   TIMESTAMPTZ,
    ended_at      TIMESTAMPTZ
);

CREATE INDEX calls_callee_id_idx   ON public.calls (callee_id, status);
CREATE INDEX calls_incident_id_idx ON public.calls (incident_id);

ALTER TABLE public.calls ENABLE ROW LEVEL SECURITY;

CREATE POLICY "calls_select_participant"
ON public.calls FOR SELECT TO authenticated
USING (auth.uid() IN (caller_id, callee_id));

CREATE POLICY "calls_update_participant"
ON public.calls FOR UPDATE TO authenticated
USING (auth.uid() IN (caller_id, callee_id))
WITH CHECK (auth.uid() IN (caller_id, callee_id));

-- Deliberately no INSERT policy for `authenticated` — every row is created
-- by the start_call() RPC below, which resolves caller/callee server-side
-- so a caller can't spoof calling as someone else or ring an unrelated user.

ALTER PUBLICATION supabase_realtime ADD TABLE public.calls;

CREATE OR REPLACE FUNCTION public.start_call(
  p_incident_id UUID,
  p_is_video    BOOLEAN DEFAULT FALSE
)
RETURNS public.calls
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid       UUID := auth.uid();
  v_role      TEXT;
  v_incident  incidents%ROWTYPE;
  v_callee_id UUID;
  v_call      calls%ROWTYPE;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'unauthorized: no authenticated user';
  END IF;

  SELECT role INTO v_role FROM profiles WHERE id = v_uid;
  SELECT * INTO v_incident FROM incidents WHERE id = p_incident_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'incident_not_found'; END IF;

  IF v_role = 'driver' THEN
    IF NOT EXISTS (
      SELECT 1 FROM ambulances
      WHERE id = v_incident.assigned_ambulance_id AND driver_id = v_uid
    ) THEN
      RAISE EXCEPTION 'unauthorized: caller does not own the assigned ambulance';
    END IF;
    SELECT patient_id INTO v_callee_id FROM trips
      WHERE incident_id = p_incident_id
      ORDER BY requested_at DESC
      LIMIT 1;
  ELSIF v_role = 'patient' THEN
    IF NOT EXISTS (
      SELECT 1 FROM trips WHERE incident_id = p_incident_id AND patient_id = v_uid
    ) THEN
      RAISE EXCEPTION 'unauthorized: caller is not this trip''s patient';
    END IF;
    SELECT driver_id INTO v_callee_id FROM ambulances WHERE id = v_incident.assigned_ambulance_id;
  ELSE
    RAISE EXCEPTION 'unauthorized: role % cannot initiate calls', v_role;
  END IF;

  IF v_callee_id IS NULL THEN
    RAISE EXCEPTION 'callee_not_found';
  END IF;

  INSERT INTO calls (incident_id, caller_id, callee_id, channel_name, is_video, status)
  VALUES (p_incident_id, v_uid, v_callee_id, p_incident_id::text, p_is_video, 'ringing')
  RETURNING * INTO v_call;

  PERFORM public.create_notification(
    v_callee_id, 'incoming_call',
    CASE WHEN p_is_video THEN 'Incoming video call' ELSE 'Incoming voice call' END,
    'Tap to answer.',
    jsonb_build_object('callId', v_call.id, 'incidentId', p_incident_id, 'isVideo', p_is_video)
  );

  RETURN v_call;
END;
$$;

GRANT EXECUTE ON FUNCTION public.start_call(uuid, boolean) TO authenticated;
