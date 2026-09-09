-- Migration 013: In-app messaging between patient, driver, and dispatcher
-- Replaces the trip-based messages table from migration 009.

-- ── 0. Drop old schema from migration 009 ────────────────────────────────────
DROP TABLE IF EXISTS public.messages;

-- ── 1. Table ──────────────────────────────────────────────────────────────────

CREATE TABLE public.messages (
    id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_id uuid        NOT NULL REFERENCES public.incidents(id) ON DELETE CASCADE,
    sender_id   uuid        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    sender_role text        NOT NULL DEFAULT '',
    sender_name text        NOT NULL DEFAULT '',
    body        text        NOT NULL,
    created_at  timestamptz NOT NULL DEFAULT NOW()
);

CREATE INDEX ON public.messages (incident_id, created_at);

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;

-- ── 2. Trigger: auto-populate sender_role and sender_name from profiles ────────
-- Prevents role spoofing: the client only sends body + incident_id.

CREATE OR REPLACE FUNCTION public.set_message_sender_info()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  SELECT role, COALESCE(full_name, '')
  INTO NEW.sender_role, NEW.sender_name
  FROM public.profiles
  WHERE id = NEW.sender_id;
  RETURN NEW;
END;
$$;

CREATE TRIGGER messages_set_sender_info
  BEFORE INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.set_message_sender_info();


-- ── 3. RLS policies ───────────────────────────────────────────────────────────

-- SELECT: dispatchers/admins see all messages;
--         patients see messages on incidents they created;
--         drivers see messages on incidents where they are the assigned driver.
CREATE POLICY "read incident messages"
  ON public.messages FOR SELECT TO authenticated
  USING (
    current_user_role() IN ('dispatcher', 'admin')
    OR EXISTS (
        SELECT 1 FROM public.incidents
        WHERE id = messages.incident_id
          AND created_by = auth.uid()
    )
    OR EXISTS (
        SELECT 1 FROM public.trips
        WHERE incident_id = messages.incident_id
          AND driver_id = auth.uid()
    )
  );

-- INSERT: same participant check; enforces sender_id = current user
CREATE POLICY "send incident messages"
  ON public.messages FOR INSERT TO authenticated
  WITH CHECK (
    sender_id = auth.uid()
    AND (
      current_user_role() IN ('dispatcher', 'admin')
      OR EXISTS (
          SELECT 1 FROM public.incidents
          WHERE id = messages.incident_id
            AND created_by = auth.uid()
      )
      OR EXISTS (
          SELECT 1 FROM public.trips
          WHERE incident_id = messages.incident_id
            AND driver_id = auth.uid()
      )
    )
  );
