-- ============================================================
-- Migration 001 — Initial Schema
-- Apply AFTER enabling the PostGIS extension in Supabase:
--   Dashboard → Database → Extensions → search "postgis" → Enable
-- ============================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS postgis;

-- ============================================================
-- PROFILES
-- One row per auth.users entry (created by trigger in 002).
-- ============================================================
CREATE TABLE public.profiles (
    id          UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name   TEXT NOT NULL DEFAULT '',
    role        TEXT NOT NULL DEFAULT 'driver'
                  CHECK (role IN ('dispatcher', 'driver', 'hospital', 'admin')),
    hospital_id UUID,  -- FK added below after hospitals table
    phone       TEXT NOT NULL DEFAULT '',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- HOSPITALS
-- ============================================================
CREATE TABLE public.hospitals (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name          TEXT NOT NULL,
    address       TEXT NOT NULL DEFAULT '',
    location      GEOGRAPHY(POINT, 4326),
    contact_phone TEXT NOT NULL DEFAULT ''
);

-- Back-fill FK from profiles → hospitals
ALTER TABLE public.profiles
    ADD CONSTRAINT profiles_hospital_id_fkey
    FOREIGN KEY (hospital_id) REFERENCES public.hospitals(id) ON DELETE SET NULL;

-- ============================================================
-- AMBULANCES
-- ============================================================
CREATE TABLE public.ambulances (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plate_number         TEXT NOT NULL UNIQUE,
    status               TEXT NOT NULL DEFAULT 'available'
                           CHECK (status IN ('available','dispatched','en_route','busy','offline')),
    current_location     GEOGRAPHY(POINT, 4326),
    driver_id            UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    hospital_id          UUID REFERENCES public.hospitals(id) ON DELETE SET NULL,
    last_location_update TIMESTAMPTZ
);

-- ============================================================
-- INCIDENTS
-- ============================================================
CREATE TABLE public.incidents (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_name         TEXT NOT NULL DEFAULT '',
    reporter_phone        TEXT NOT NULL DEFAULT '',
    incident_location     GEOGRAPHY(POINT, 4326),
    location_description  TEXT NOT NULL DEFAULT '',
    nature_of_emergency   TEXT NOT NULL DEFAULT '',
    patient_condition_notes TEXT NOT NULL DEFAULT '',
    status                TEXT NOT NULL DEFAULT 'logged'
                            CHECK (status IN ('logged','dispatched','en_route','arrived','completed','cancelled')),
    created_by            UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    assigned_ambulance_id UUID REFERENCES public.ambulances(id) ON DELETE SET NULL,
    assigned_hospital_id  UUID REFERENCES public.hospitals(id) ON DELETE SET NULL,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    dispatched_at         TIMESTAMPTZ,
    arrived_at            TIMESTAMPTZ,
    completed_at          TIMESTAMPTZ
);

-- ============================================================
-- INCIDENT_EVENTS
-- Audit trail for every status change, message, or location ping.
-- ============================================================
CREATE TABLE public.incident_events (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    incident_id UUID NOT NULL REFERENCES public.incidents(id) ON DELETE CASCADE,
    event_type  TEXT NOT NULL
                  CHECK (event_type IN ('status_change','message','location_ping')),
    payload     TEXT NOT NULL DEFAULT '',
    actor_id    UUID REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- SPATIAL INDEXES (PostGIS GIST) for nearest-ambulance queries
-- ============================================================
CREATE INDEX idx_ambulances_location   ON public.ambulances   USING GIST (current_location);
CREATE INDEX idx_incidents_location    ON public.incidents     USING GIST (incident_location);
CREATE INDEX idx_hospitals_location    ON public.hospitals     USING GIST (location);

-- ============================================================
-- REALTIME — enable live subscriptions on key tables
-- ============================================================
ALTER PUBLICATION supabase_realtime ADD TABLE public.ambulances;
ALTER PUBLICATION supabase_realtime ADD TABLE public.incidents;
ALTER PUBLICATION supabase_realtime ADD TABLE public.incident_events;
