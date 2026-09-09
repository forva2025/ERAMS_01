-- Migration 010: nearby_ambulances RPC
-- Returns available ambulances ordered by distance from the patient's GPS point.
-- Called by PatientService.fetchNearbyAmbulances().

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
    SELECT *
    FROM   public.ambulances
    WHERE  status = 'available'
       AND current_location IS NOT NULL
    ORDER BY current_location <-> ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)
    LIMIT  20;
$$;

GRANT EXECUTE ON FUNCTION public.nearby_ambulances TO authenticated;
