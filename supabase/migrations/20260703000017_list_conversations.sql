-- Migration 017: list_conversations() — powers the WhatsApp/Telegram-style
-- chat-history list. Returns one row per incident the caller is chatting in,
-- ordered by most recent message. The counterpart shown depends on the
-- caller's role: a driver sees the patient, a patient sees the driver,
-- dispatchers/hospital staff see the incident creator (patient).

CREATE OR REPLACE FUNCTION public.list_conversations()
RETURNS TABLE (
  incident_id uuid,
  other_name  text,
  other_role  text,
  last_body   text,
  last_at     timestamptz,
  unread      integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid  uuid := auth.uid();
  v_role text;
BEGIN
  SELECT role INTO v_role FROM public.profiles WHERE id = v_uid;

  RETURN QUERY
  WITH my_incidents AS (
    -- Every incident the caller can see messages in (mirrors messages RLS),
    -- restricted to those that actually have at least one message.
    SELECT DISTINCT m.incident_id AS iid
    FROM public.messages m
    WHERE
      v_role IN ('dispatcher', 'admin')
      OR EXISTS (
        SELECT 1 FROM public.incidents i
        JOIN public.ambulances a ON a.id = i.assigned_ambulance_id
        WHERE i.id = m.incident_id AND a.driver_id = v_uid
      )
      OR EXISTS (
        SELECT 1 FROM public.incidents i
        WHERE i.id = m.incident_id
          AND i.assigned_hospital_id =
              (SELECT hospital_id FROM public.profiles WHERE id = v_uid)
      )
      OR EXISTS (
        SELECT 1 FROM public.incidents i
        WHERE i.id = m.incident_id AND i.created_by = v_uid
      )
      OR EXISTS (
        SELECT 1 FROM public.trips t
        WHERE t.incident_id = m.incident_id AND t.patient_id = v_uid
      )
  )
  SELECT
    mi.iid,
    COALESCE(cp.full_name, 'Unknown'),
    COALESCE(cp.role, ''),
    lm.body,
    lm.created_at,
    (
      SELECT COUNT(*)::int
      FROM public.messages um
      WHERE um.incident_id = mi.iid
        AND um.sender_id  <> v_uid
        AND NOT (v_uid = ANY(um.seen_by))
    )
  FROM my_incidents mi
  -- Last message in the incident.
  LEFT JOIN LATERAL (
    SELECT body, created_at
    FROM public.messages
    WHERE incident_id = mi.iid
    ORDER BY created_at DESC
    LIMIT 1
  ) lm ON true
  -- Counterpart profile, chosen by the caller's role.
  LEFT JOIN LATERAL (
    SELECT p.full_name, p.role
    FROM public.profiles p
    WHERE p.id = (
      CASE
        WHEN v_role = 'driver' THEN
          COALESCE(
            (SELECT t.patient_id FROM public.trips t
               WHERE t.incident_id = mi.iid LIMIT 1),
            (SELECT i.created_by FROM public.incidents i WHERE i.id = mi.iid)
          )
        WHEN v_role = 'patient' THEN
          (SELECT a.driver_id
             FROM public.incidents i
             JOIN public.ambulances a ON a.id = i.assigned_ambulance_id
             WHERE i.id = mi.iid)
        ELSE
          (SELECT i.created_by FROM public.incidents i WHERE i.id = mi.iid)
      END
    )
  ) cp ON true
  ORDER BY lm.created_at DESC NULLS LAST;
END;
$$;

GRANT EXECUTE ON FUNCTION public.list_conversations() TO authenticated;
