-- ============================================================
-- Migration 020 — Guard dispatch_incident against double-booking
-- ============================================================
-- Bug: the manual-override path in dispatch_incident() assigns the
-- specified ambulance "regardless of its status" with no check for an
-- incident already in progress on it. A dispatcher re-using the same
-- ambulance for successive manual dispatches stacked multiple active
-- incidents onto one ambulance; the driver app only ever surfaces the
-- single newest one (fetchActiveIncident orders by created_at desc,
-- limit 1), so the older ones became invisible and stuck.
--
-- Fix: reject dispatch (auto or manual) if the resolved ambulance
-- already has an incident in a non-terminal status.
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

    -- Reject if the resolved ambulance already has an incident in progress —
    -- covers both the manual-override path (which otherwise bypasses the
    -- 'available' filter) and any stale-status edge case on the auto path.
    IF EXISTS (
        SELECT 1 FROM public.incidents
        WHERE assigned_ambulance_id = v_ambulance_id
          AND status IN ('pending_acceptance', 'dispatched', 'en_route', 'arrived')
    ) THEN
        RAISE EXCEPTION 'ambulance_already_busy: ambulance % already has an active incident', v_ambulance_id;
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
