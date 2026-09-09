-- Migration 016: Add seen_by to messages for WhatsApp-style read receipts.
-- Each UUID in the array is a user who has opened the chat after this message
-- was sent (and is not the original sender).

ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS seen_by uuid[] NOT NULL DEFAULT '{}';

-- RPC: mark all messages in an incident (sent by others) as seen by the caller.
-- Called when a user opens the chat sheet and whenever new messages arrive.
CREATE OR REPLACE FUNCTION public.mark_messages_seen(p_incident_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  UPDATE public.messages
  SET seen_by = array_append(seen_by, auth.uid())
  WHERE incident_id = p_incident_id
    AND sender_id   != auth.uid()
    AND NOT (auth.uid() = ANY(seen_by));
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_messages_seen(uuid) TO authenticated;
