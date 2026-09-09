-- ============================================================
-- Migration 003 — Row Level Security Policies
-- ============================================================

-- -------------------------------------------------------
-- Helper: returns the role of the currently signed-in user.
-- Used in policy USING / WITH CHECK expressions.
-- -------------------------------------------------------
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public
AS $$
    SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

-- Enable RLS on every table
ALTER TABLE public.profiles        ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hospitals       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ambulances      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.incidents       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.incident_events ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- PROFILES
-- ============================================================

-- Everyone can read their own profile
CREATE POLICY "profiles_select_own"
ON public.profiles FOR SELECT TO authenticated
USING (id = auth.uid());

-- Dispatchers and admins can read all profiles
CREATE POLICY "profiles_select_dispatcher_admin"
ON public.profiles FOR SELECT TO authenticated
USING (public.current_user_role() IN ('dispatcher', 'admin'));

-- Users can update their own name/phone (role field is locked to its current value)
CREATE POLICY "profiles_update_own"
ON public.profiles FOR UPDATE TO authenticated
USING (id = auth.uid())
WITH CHECK (
    id = auth.uid()
    AND role = (SELECT role FROM public.profiles WHERE id = auth.uid())
);

-- Admins can update any profile, including the role field
CREATE POLICY "profiles_update_admin"
ON public.profiles FOR UPDATE TO authenticated
USING (public.current_user_role() = 'admin');

-- ============================================================
-- HOSPITALS
-- ============================================================

CREATE POLICY "hospitals_select_authenticated"
ON public.hospitals FOR SELECT TO authenticated
USING (true);

CREATE POLICY "hospitals_insert_admin"
ON public.hospitals FOR INSERT TO authenticated
WITH CHECK (public.current_user_role() = 'admin');

CREATE POLICY "hospitals_update_admin"
ON public.hospitals FOR UPDATE TO authenticated
USING (public.current_user_role() = 'admin');

CREATE POLICY "hospitals_delete_admin"
ON public.hospitals FOR DELETE TO authenticated
USING (public.current_user_role() = 'admin');

-- ============================================================
-- AMBULANCES
-- ============================================================

-- Dispatchers, admins, and hospital staff can read all ambulances
CREATE POLICY "ambulances_select_dispatcher_admin_hospital"
ON public.ambulances FOR SELECT TO authenticated
USING (public.current_user_role() IN ('dispatcher', 'admin', 'hospital'));

-- Drivers can read only their own assigned ambulance
CREATE POLICY "ambulances_select_driver_own"
ON public.ambulances FOR SELECT TO authenticated
USING (
    public.current_user_role() = 'driver'
    AND driver_id = auth.uid()
);

-- Drivers can update location and status on their own ambulance only
CREATE POLICY "ambulances_update_driver_own"
ON public.ambulances FOR UPDATE TO authenticated
USING (
    public.current_user_role() = 'driver'
    AND driver_id = auth.uid()
)
WITH CHECK (driver_id = auth.uid());

-- Dispatchers can update status and assignment on any ambulance
CREATE POLICY "ambulances_update_dispatcher"
ON public.ambulances FOR UPDATE TO authenticated
USING (public.current_user_role() = 'dispatcher');

-- Admins have full write access
CREATE POLICY "ambulances_all_admin"
ON public.ambulances FOR ALL TO authenticated
USING (public.current_user_role() = 'admin');

-- ============================================================
-- INCIDENTS
-- ============================================================

-- Dispatchers and admins see all incidents
CREATE POLICY "incidents_select_dispatcher_admin"
ON public.incidents FOR SELECT TO authenticated
USING (public.current_user_role() IN ('dispatcher', 'admin'));

-- Drivers see only the incident assigned to their ambulance
CREATE POLICY "incidents_select_driver_assigned"
ON public.incidents FOR SELECT TO authenticated
USING (
    public.current_user_role() = 'driver'
    AND assigned_ambulance_id IN (
        SELECT id FROM public.ambulances WHERE driver_id = auth.uid()
    )
);

-- Hospital staff see incidents assigned to their hospital
CREATE POLICY "incidents_select_hospital"
ON public.incidents FOR SELECT TO authenticated
USING (
    public.current_user_role() = 'hospital'
    AND assigned_hospital_id = (
        SELECT hospital_id FROM public.profiles WHERE id = auth.uid()
    )
);

-- Only dispatchers and admins can create incidents
CREATE POLICY "incidents_insert_dispatcher_admin"
ON public.incidents FOR INSERT TO authenticated
WITH CHECK (public.current_user_role() IN ('dispatcher', 'admin'));

-- Dispatchers and admins can update any incident field
CREATE POLICY "incidents_update_dispatcher_admin"
ON public.incidents FOR UPDATE TO authenticated
USING (public.current_user_role() IN ('dispatcher', 'admin'));

-- Drivers can update the status of their assigned incident
CREATE POLICY "incidents_update_driver_assigned"
ON public.incidents FOR UPDATE TO authenticated
USING (
    public.current_user_role() = 'driver'
    AND assigned_ambulance_id IN (
        SELECT id FROM public.ambulances WHERE driver_id = auth.uid()
    )
);

-- ============================================================
-- INCIDENT_EVENTS
-- ============================================================

-- Dispatchers and admins see all events
CREATE POLICY "incident_events_select_dispatcher_admin"
ON public.incident_events FOR SELECT TO authenticated
USING (public.current_user_role() IN ('dispatcher', 'admin'));

-- Drivers see events for their assigned incident
CREATE POLICY "incident_events_select_driver"
ON public.incident_events FOR SELECT TO authenticated
USING (
    public.current_user_role() = 'driver'
    AND incident_id IN (
        SELECT i.id FROM public.incidents i
        JOIN public.ambulances a ON i.assigned_ambulance_id = a.id
        WHERE a.driver_id = auth.uid()
    )
);

-- Hospital staff see events for their hospital's incidents
CREATE POLICY "incident_events_select_hospital"
ON public.incident_events FOR SELECT TO authenticated
USING (
    public.current_user_role() = 'hospital'
    AND incident_id IN (
        SELECT id FROM public.incidents
        WHERE assigned_hospital_id = (
            SELECT hospital_id FROM public.profiles WHERE id = auth.uid()
        )
    )
);

-- Dispatchers and admins can log events
CREATE POLICY "incident_events_insert_dispatcher_admin"
ON public.incident_events FOR INSERT TO authenticated
WITH CHECK (public.current_user_role() IN ('dispatcher', 'admin'));

-- Drivers can log events on their incident
CREATE POLICY "incident_events_insert_driver"
ON public.incident_events FOR INSERT TO authenticated
WITH CHECK (
    public.current_user_role() = 'driver'
    AND incident_id IN (
        SELECT i.id FROM public.incidents i
        JOIN public.ambulances a ON i.assigned_ambulance_id = a.id
        WHERE a.driver_id = auth.uid()
    )
);

-- Hospital staff can log acknowledge events on their hospital's incidents
CREATE POLICY "incident_events_insert_hospital"
ON public.incident_events FOR INSERT TO authenticated
WITH CHECK (
    public.current_user_role() = 'hospital'
    AND incident_id IN (
        SELECT id FROM public.incidents
        WHERE assigned_hospital_id = (
            SELECT hospital_id FROM public.profiles WHERE id = auth.uid()
        )
    )
);
