-- Migration 007: Ambulance marketplace columns
-- Adds service tier, pricing, and rating fields needed for the patient-facing
-- ambulance selection screen (like SafeBoda's driver cards).

ALTER TABLE public.ambulances
    ADD COLUMN IF NOT EXISTS service_type   TEXT    NOT NULL DEFAULT 'BLS'
        CHECK (service_type IN ('BLS', 'ALS', 'ICU', 'Neonatal', 'Bariatric')),
    ADD COLUMN IF NOT EXISTS base_fare      NUMERIC(10,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS price_per_km   NUMERIC(10,2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS rating         NUMERIC(3,2)  NOT NULL DEFAULT 0
        CHECK (rating >= 0 AND rating <= 5),
    ADD COLUMN IF NOT EXISTS rating_count   INTEGER  NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS equipment_notes TEXT    NOT NULL DEFAULT '';

COMMENT ON COLUMN public.ambulances.service_type IS
    'BLS=Basic Life Support, ALS=Advanced, ICU=Intensive Care Unit transport, etc.';
COMMENT ON COLUMN public.ambulances.base_fare IS
    'Fixed call-out fee in UGX before distance charges';
COMMENT ON COLUMN public.ambulances.price_per_km IS
    'Per-kilometre rate in UGX';
COMMENT ON COLUMN public.ambulances.rating IS
    'Rolling average star rating (0–5) updated after each completed trip';

-- Seed demo ambulances with service type and pricing
UPDATE public.ambulances SET
    service_type   = 'BLS',
    base_fare      = 50000,
    price_per_km   = 3000,
    equipment_notes = 'Oxygen, AED, stretcher'
WHERE plate_number = 'UBE 001A';

UPDATE public.ambulances SET
    service_type   = 'ALS',
    base_fare      = 80000,
    price_per_km   = 4500,
    equipment_notes = 'Ventilator, cardiac monitor, IV medications'
WHERE plate_number = 'UBE 002A';

UPDATE public.ambulances SET
    service_type   = 'BLS',
    base_fare      = 50000,
    price_per_km   = 3000,
    equipment_notes = 'Oxygen, AED, stretcher'
WHERE plate_number = 'UBE 003A';

UPDATE public.ambulances SET
    service_type   = 'ICU',
    base_fare      = 150000,
    price_per_km   = 7000,
    equipment_notes = 'Full ICU suite, ventilator, infusion pumps'
WHERE plate_number = 'UBE 004A';

UPDATE public.ambulances SET
    service_type   = 'ALS',
    base_fare      = 80000,
    price_per_km   = 4500,
    equipment_notes = 'Cardiac monitor, defibrillator, IV medications'
WHERE plate_number = 'UBE 005A';
