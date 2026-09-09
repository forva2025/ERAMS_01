-- Migration 012: Ratings system
-- Adds patient_rating / patient_comment to trips, a trigger that keeps
-- ambulances.rating + rating_count in sync, and a trigger that marks trips
-- completed/cancelled whenever the parent incident closes.

-- ── 1. Rating columns on trips (safe to re-run) ──────────────────────────────

ALTER TABLE public.trips
  ADD COLUMN IF NOT EXISTS patient_rating  smallint CHECK (patient_rating BETWEEN 1 AND 5),
  ADD COLUMN IF NOT EXISTS patient_comment text;

-- ── 2. Trigger: recalculate ambulance rating after a trip is rated ─────────────

CREATE OR REPLACE FUNCTION public.update_ambulance_rating_fn()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Only fire when patient_rating actually changes value
  IF NEW.patient_rating IS NOT DISTINCT FROM OLD.patient_rating THEN
    RETURN NEW;
  END IF;
  IF NEW.ambulance_id IS NULL THEN
    RETURN NEW;
  END IF;

  UPDATE public.ambulances
  SET
    rating = COALESCE((
      SELECT AVG(patient_rating::numeric)
      FROM public.trips
      WHERE ambulance_id = NEW.ambulance_id
        AND patient_rating IS NOT NULL
    ), 0),
    rating_count = (
      SELECT COUNT(*)
      FROM public.trips
      WHERE ambulance_id = NEW.ambulance_id
        AND patient_rating IS NOT NULL
    )
  WHERE id = NEW.ambulance_id;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trips_after_rating_update ON public.trips;
CREATE TRIGGER trips_after_rating_update
  AFTER UPDATE OF patient_rating ON public.trips
  FOR EACH ROW
  EXECUTE FUNCTION public.update_ambulance_rating_fn();


-- ── 3. Trigger: keep trips in sync when incident is completed or cancelled ─────
-- update_incident_status() RPC only updates incidents + ambulances; this trigger
-- closes the gap by mirroring the final status into the trips table.

CREATE OR REPLACE FUNCTION public.sync_trips_on_incident_close()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
    UPDATE public.trips
    SET
      status       = 'completed',
      completed_at = NOW()
    WHERE incident_id = NEW.id
      AND status NOT IN ('completed', 'cancelled');

  ELSIF NEW.status = 'cancelled' AND OLD.status != 'cancelled' THEN
    UPDATE public.trips
    SET
      status        = 'cancelled',
      cancelled_at  = NOW(),
      cancel_reason = COALESCE(cancel_reason, 'incident_cancelled')
    WHERE incident_id = NEW.id
      AND status NOT IN ('completed', 'cancelled');
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS incidents_sync_trips ON public.incidents;
CREATE TRIGGER incidents_sync_trips
  AFTER UPDATE OF status ON public.incidents
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_trips_on_incident_close();


-- ── 4. RLS: patient can update their own trip's rating fields only ─────────────

DROP POLICY IF EXISTS "patient update own trip rating" ON public.trips;
CREATE POLICY "patient update own trip rating"
  ON public.trips
  FOR UPDATE
  TO authenticated
  USING (
    patient_id = auth.uid()
    AND status = 'completed'
    AND patient_rating IS NULL
  )
  WITH CHECK (
    patient_id = auth.uid()
  );
