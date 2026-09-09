-- Migration 019: Fix nearby_ambulances distance ordering.
--
-- current_location is GEOGRAPHY, but ST_SetSRID(ST_MakePoint(...), 4326)
-- produces GEOMETRY. There is no `geography <-> geometry` operator, so the
-- KNN ORDER BY threw at runtime and PatientService.fetchNearbyAmbulances()
-- silently fell back to an unsorted `status = 'available'` query. Casting the
-- search point to geography makes the primary, distance-sorted path work and
-- keeps the `current_location IS NOT NULL` filter meaningful, so only
-- ambulances that are actually sharing a live GPS fix are discoverable.

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
    ORDER BY current_location <->
             ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography
    LIMIT  20;
$$;

GRANT EXECUTE ON FUNCTION public.nearby_ambulances TO authenticated;
