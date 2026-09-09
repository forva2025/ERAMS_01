-- Migration 008: Trips table
-- A trip is the patient-initiated booking lifecycle: request → accepted →
-- en_route → arrived → completed (or cancelled).  One trip corresponds to
-- one incident for billing/tracking purposes.

CREATE TABLE IF NOT EXISTS public.trips (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_id         UUID NOT NULL REFERENCES public.incidents(id) ON DELETE CASCADE,
    patient_id          UUID NOT NULL REFERENCES public.profiles(id),
    ambulance_id        UUID REFERENCES public.ambulances(id),
    driver_id           UUID REFERENCES public.profiles(id),

    -- Status machine mirrors the ride-hailing flow
    status              TEXT NOT NULL DEFAULT 'requested'
        CHECK (status IN (
            'requested',        -- patient submitted, awaiting driver acceptance
            'accepted',         -- driver accepted, heading to patient
            'en_route',         -- driver en route after picking up patient
            'arrived',          -- arrived at destination hospital
            'completed',        -- trip closed, rating prompt shown
            'cancelled'         -- cancelled by patient or driver
        )),

    -- Pricing snapshot at booking time (rates may change later)
    base_fare           NUMERIC(10,2) NOT NULL DEFAULT 0,
    price_per_km        NUMERIC(10,2) NOT NULL DEFAULT 0,
    distance_km         NUMERIC(8,3),
    total_fare          NUMERIC(10,2),

    -- Payment
    payment_method      TEXT NOT NULL DEFAULT 'cash'
        CHECK (payment_method IN ('cash', 'mtn_momo', 'airtel_money')),
    payment_status      TEXT NOT NULL DEFAULT 'pending'
        CHECK (payment_status IN ('pending', 'paid', 'failed', 'refunded')),
    payment_reference   TEXT,          -- Flutterwave transaction reference

    -- Patient rating (filled after completion)
    patient_rating      SMALLINT CHECK (patient_rating BETWEEN 1 AND 5),
    patient_comment     TEXT,

    -- Timestamps
    requested_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    accepted_at         TIMESTAMPTZ,
    pickup_at           TIMESTAMPTZ,
    arrived_at          TIMESTAMPTZ,
    completed_at        TIMESTAMPTZ,
    cancelled_at        TIMESTAMPTZ,
    cancel_reason       TEXT
);

-- Indexes for common query patterns
CREATE INDEX trips_patient_id_idx    ON public.trips (patient_id);
CREATE INDEX trips_ambulance_id_idx  ON public.trips (ambulance_id);
CREATE INDEX trips_incident_id_idx   ON public.trips (incident_id);
CREATE INDEX trips_status_idx        ON public.trips (status);

-- Enable RLS
ALTER TABLE public.trips ENABLE ROW LEVEL SECURITY;

-- Patient: full access to own trips
CREATE POLICY "trips_select_patient_own"
ON public.trips FOR SELECT TO authenticated
USING (
    public.current_user_role() = 'patient'
    AND patient_id = auth.uid()
);

CREATE POLICY "trips_insert_patient"
ON public.trips FOR INSERT TO authenticated
WITH CHECK (
    public.current_user_role() = 'patient'
    AND patient_id = auth.uid()
);

CREATE POLICY "trips_update_patient_own"
ON public.trips FOR UPDATE TO authenticated
USING (
    public.current_user_role() = 'patient'
    AND patient_id = auth.uid()
);

-- Driver: can see and update trips assigned to their ambulance
CREATE POLICY "trips_select_driver"
ON public.trips FOR SELECT TO authenticated
USING (
    public.current_user_role() = 'driver'
    AND driver_id = auth.uid()
);

CREATE POLICY "trips_update_driver"
ON public.trips FOR UPDATE TO authenticated
USING (
    public.current_user_role() = 'driver'
    AND driver_id = auth.uid()
);

-- Dispatcher and admin: full read, dispatcher can update
CREATE POLICY "trips_select_dispatcher_admin"
ON public.trips FOR SELECT TO authenticated
USING (public.current_user_role() IN ('dispatcher', 'admin'));

CREATE POLICY "trips_update_dispatcher"
ON public.trips FOR UPDATE TO authenticated
USING (public.current_user_role() IN ('dispatcher', 'admin'));

-- Now that trips exists, add the patient incident visibility policy
CREATE POLICY "incidents_select_patient_own"
ON public.incidents FOR SELECT TO authenticated
USING (
    public.current_user_role() = 'patient'
    AND id IN (
        SELECT incident_id FROM public.trips WHERE patient_id = auth.uid()
    )
);

-- Enable Realtime on trips so drivers see new booking requests instantly
ALTER PUBLICATION supabase_realtime ADD TABLE public.trips;
