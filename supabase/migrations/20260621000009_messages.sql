-- Migration 009: In-trip messaging table
-- Supports text messages between patient and driver within a trip.
-- Voice/video call signalling (Phase 14) will also store offer/answer SDPs here
-- by adding a message_type column in that migration.

CREATE TABLE IF NOT EXISTS public.messages (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trip_id     UUID NOT NULL REFERENCES public.trips(id) ON DELETE CASCADE,
    sender_id   UUID NOT NULL REFERENCES public.profiles(id),
    body        TEXT NOT NULL,
    sent_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    read_at     TIMESTAMPTZ
);

CREATE INDEX messages_trip_id_idx  ON public.messages (trip_id);
CREATE INDEX messages_sender_idx   ON public.messages (sender_id);
CREATE INDEX messages_sent_at_idx  ON public.messages (sent_at);

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Patient: can read and write messages on their own trips
CREATE POLICY "messages_select_trip_participant"
ON public.messages FOR SELECT TO authenticated
USING (
    trip_id IN (
        SELECT id FROM public.trips
        WHERE patient_id = auth.uid()
           OR driver_id  = auth.uid()
    )
    OR public.current_user_role() IN ('dispatcher', 'admin')
);

CREATE POLICY "messages_insert_trip_participant"
ON public.messages FOR INSERT TO authenticated
WITH CHECK (
    sender_id = auth.uid()
    AND (
        trip_id IN (
            SELECT id FROM public.trips
            WHERE patient_id = auth.uid()
               OR driver_id  = auth.uid()
        )
        OR public.current_user_role() IN ('dispatcher', 'admin')
    )
);

-- Realtime: drivers and patients subscribe to new messages in their trip
ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
