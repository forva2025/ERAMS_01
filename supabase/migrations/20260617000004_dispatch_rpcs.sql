-- ============================================================
-- Migration 004 — Dispatch RPC Functions
-- ============================================================
-- Two server-side functions that run in a single transaction
-- (SECURITY DEFINER so RLS does not interfere mid-transaction).
--
-- 1. dispatch_incident(p_incident_id, p_ambulance_id DEFAULT NULL)
--    • p_ambulance_id = NULL  → auto-assigns nearest available ambulance
--    • p_ambulance_id = <id>  → manual override (bypasses availability check)
--
-- 2. update_incident_status(p_incident_id, p_new_status)
--    • Transitions incident through its lifecycle
--    • Keeps ambulance status in sync
--    • Writes an audit row to incident_events
-- ============================================================


-- ============================================================
-- FUNCTION 1: dispatch_incident
-- ============================================================
CREATE OR REPLACE FUNCTION public.dispatch_incident(
    p_incident_id   uuid,
    p_ambulance_id  uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_incident      incidents%ROWTYPE;
    v_ambulance_id  uuid;
    v_caller_role   text;
BEGIN
    -- Only dispatchers and admins may call this function
    SELECT role INTO v_caller_role
    FROM public.profiles
    WHERE id = auth.uid();

    IF v_caller_role NOT IN ('dispatcher', 'admin') THEN
        RAISE EXCEPTION 'unauthorized: only dispatchers and admins can dispatch incidents';
    END IF;

    -- Lock and read the incident
    SELECT * INTO v_incident
    FROM public.incidents
    WHERE id = p_incident_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'incident_not_found';
    END IF;

    IF v_incident.status != 'logged' THEN
        RAISE EXCEPTION 'incident_already_dispatched: current status is %', v_incident.status;
    END IF;

    IF v_incident.incident_location IS NULL AND p_ambulance_id IS NULL THEN
        RAISE EXCEPTION 'incident_has_no_location: cannot auto-assign without coordinates';
    END IF;

    -- Resolve ambulance
    IF p_ambulance_id IS NOT NULL THEN
        -- Manual override — use the specified ambulance regardless of its status
        v_ambulance_id := p_ambulance_id;

        IF NOT EXISTS (SELECT 1 FROM public.ambulances WHERE id = v_ambulance_id) THEN
            RAISE EXCEPTION 'ambulance_not_found';
        END IF;
    ELSE
        -- Auto: nearest available ambulance ordered by PostGIS straight-line distance
        SELECT id INTO v_ambulance_id
        FROM public.ambulances
        WHERE status = 'available'
          AND current_location IS NOT NULL
        ORDER BY ST_Distance(current_location, v_incident.incident_location)
        LIMIT 1;

        IF v_ambulance_id IS NULL THEN
            RAISE EXCEPTION 'no_ambulance_available: no available ambulance with a known location';
        END IF;
    END IF;

    -- Atomically update incident
    UPDATE public.incidents SET
        assigned_ambulance_id = v_ambulance_id,
        status                = 'dispatched',
        dispatched_at         = NOW()
    WHERE id = p_incident_id;

    -- Atomically update ambulance
    UPDATE public.ambulances SET
        status = 'dispatched'
    WHERE id = v_ambulance_id;

    -- Audit trail
    INSERT INTO public.incident_events (incident_id, event_type, payload, actor_id)
    VALUES (
        p_incident_id,
        'status_change',
        jsonb_build_object(
            'from', 'logged',
            'to',   'dispatched',
            'ambulance_id', v_ambulance_id,
            'manual', p_ambulance_id IS NOT NULL
        )::text,
        auth.uid()
    );

    RETURN jsonb_build_object(
        'incident_id',   p_incident_id,
        'ambulance_id',  v_ambulance_id,
        'status',        'dispatched',
        'manual',        p_ambulance_id IS NOT NULL
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.dispatch_incident(uuid, uuid) TO authenticated;


-- ============================================================
-- FUNCTION 2: update_incident_status
-- ============================================================
CREATE OR REPLACE FUNCTION public.update_incident_status(
    p_incident_id  uuid,
    p_new_status   text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_incident    incidents%ROWTYPE;
    v_caller_role text;
BEGIN
    -- Validate new_status value
    IF p_new_status NOT IN ('en_route', 'arrived', 'completed', 'cancelled') THEN
        RAISE EXCEPTION 'invalid_status: % is not a valid transition target', p_new_status;
    END IF;

    SELECT role INTO v_caller_role
    FROM public.profiles
    WHERE id = auth.uid();

    -- Drivers can transition their assigned incident; dispatchers/admins can do anything
    IF v_caller_role NOT IN ('dispatcher', 'admin', 'driver') THEN
        RAISE EXCEPTION 'unauthorized';
    END IF;

    -- Lock and read incident
    SELECT * INTO v_incident
    FROM public.incidents
    WHERE id = p_incident_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'incident_not_found';
    END IF;

    -- Drivers may only update incidents assigned to their ambulance
    IF v_caller_role = 'driver' THEN
        IF NOT EXISTS (
            SELECT 1 FROM public.ambulances
            WHERE id = v_incident.assigned_ambulance_id
              AND driver_id = auth.uid()
        ) THEN
            RAISE EXCEPTION 'unauthorized: incident is not assigned to your ambulance';
        END IF;
    END IF;

    -- Update incident with appropriate timestamp
    UPDATE public.incidents SET
        status       = p_new_status,
        arrived_at   = CASE WHEN p_new_status = 'arrived'   THEN NOW() ELSE arrived_at   END,
        completed_at = CASE WHEN p_new_status = 'completed' THEN NOW() ELSE completed_at END
    WHERE id = p_incident_id;

    -- Keep ambulance status in sync
    IF v_incident.assigned_ambulance_id IS NOT NULL THEN
        UPDATE public.ambulances SET
            status = CASE p_new_status
                WHEN 'en_route'   THEN 'en_route'
                WHEN 'arrived'    THEN 'busy'
                WHEN 'completed'  THEN 'available'
                WHEN 'cancelled'  THEN 'available'
                ELSE status
            END
        WHERE id = v_incident.assigned_ambulance_id;
    END IF;

    -- Audit trail
    INSERT INTO public.incident_events (incident_id, event_type, payload, actor_id)
    VALUES (
        p_incident_id,
        'status_change',
        jsonb_build_object('from', v_incident.status, 'to', p_new_status)::text,
        auth.uid()
    );

    RETURN jsonb_build_object(
        'incident_id', p_incident_id,
        'old_status',  v_incident.status,
        'new_status',  p_new_status
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_incident_status(uuid, text) TO authenticated;
