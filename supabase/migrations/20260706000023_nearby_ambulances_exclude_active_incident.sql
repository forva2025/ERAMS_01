-- ============================================================
-- Migration 023 — nearby_ambulances must exclude ambulances tied
-- to a live incident, not just ones flagged busy by status
-- ============================================================
-- Bug: dispatch_incident() deliberately leaves ambulances.status =
-- 'available' for patient trips until the driver accepts (see
-- migration 021), so an ambulance already sitting in
-- pending_acceptance still passes the `status = 'available'` filter
-- in nearby_ambulances(). Patients see it in the list, select it,
-- and dispatch_incident() immediately rejects them with
-- ambulance_already_busy (migration 020/021's guard is correct —
-- the list feeding it was stale).
--
-- Fix: also exclude ambulances that have an incident in a
-- non-terminal status, mirroring the guard in dispatch_incident().
-- ============================================================

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
