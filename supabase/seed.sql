-- ============================================================
-- ERAMS Demo Seed Data
-- Apply AFTER all three migrations (001, 002, 003).
--
-- DEMO ACCOUNTS — create these manually in:
--   Supabase Dashboard → Authentication → Users → Add User
--
--   The Gmail + alias trick means all emails arrive in one inbox.
--
--   Email                                  Password       Role
--   -------------------------------------  -------------  ----------
--   katusiime66+dispatcher@gmail.com       Erams2026!     dispatcher
--   katusiime66+driver@gmail.com           Erams2026!     driver
--   katusiime66+hospital@gmail.com         Erams2026!     hospital
--   katusiime66+admin@gmail.com            Erams2026!     admin
--
-- After creating each account, the trigger auto-creates a profiles row
-- with role = 'driver'. Run the UPDATE statements at the bottom of this
-- file to set the correct roles.
-- ============================================================


-- ============================================================
-- HOSPITALS
-- Coordinates: (longitude, latitude) per PostGIS convention
-- ============================================================
INSERT INTO public.hospitals (id, name, address, location, contact_phone) VALUES

-- Healthstone Hospital, Banda (Nakawa Division, Kampala)
('a1b2c3d4-e5f6-7890-abcd-ef1234567890',
 'Healthstone Hospital',
 'Banda, Nakawa Division, Kampala, Uganda',
 ST_GeogFromText('SRID=4326;POINT(32.6406 0.3476)'),
 '+256-414-123-456'),

-- Mulago National Referral Hospital
('b2c3d4e5-f6a7-8901-bcde-f12345678901',
 'Mulago National Referral Hospital',
 'Upper Mulago Hill Road, Kampala, Uganda',
 ST_GeogFromText('SRID=4326;POINT(32.5733 0.3350)'),
 '0800-100-036');


-- ============================================================
-- DEMO AMBULANCES
-- Scattered at realistic Kampala positions.
-- Home base assigned to nearest hospital.
-- driver_id set to NULL — link to driver account after creating it.
-- ============================================================
INSERT INTO public.ambulances (id, plate_number, status, current_location, hospital_id) VALUES

-- Ambulance 1 — Nakasero (central Kampala)
('c3d4e5f6-a7b8-9012-cdef-123456789012',
 'UBE 001A',
 'available',
 ST_GeogFromText('SRID=4326;POINT(32.5810 0.3240)'),
 'b2c3d4e5-f6a7-8901-bcde-f12345678901'),   -- Mulago

-- Ambulance 2 — Ntinda (east)
('d4e5f6a7-b8c9-0123-defa-234567890123',
 'UBE 002A',
 'available',
 ST_GeogFromText('SRID=4326;POINT(32.6260 0.3420)'),
 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'),   -- Healthstone

-- Ambulance 3 — Mengo (southwest)
('e5f6a7b8-c9d0-1234-efab-345678901234',
 'UBE 003A',
 'available',
 ST_GeogFromText('SRID=4326;POINT(32.5587 0.3153)'),
 'b2c3d4e5-f6a7-8901-bcde-f12345678901'),   -- Mulago

-- Ambulance 4 — Bukoto (north)
('f6a7b8c9-d0e1-2345-fabc-456789012345',
 'UBE 004A',
 'available',
 ST_GeogFromText('SRID=4326;POINT(32.5930 0.3480)'),
 'b2c3d4e5-f6a7-8901-bcde-f12345678901'),   -- Mulago

-- Ambulance 5 — Bweyogerere (far east, near Banda)
('a7b8c9d0-e1f2-3456-abcd-567890123456',
 'UBE 005A',
 'available',
 ST_GeogFromText('SRID=4326;POINT(32.6780 0.3450)'),
 'a1b2c3d4-e5f6-7890-abcd-ef1234567890');   -- Healthstone


-- ============================================================
-- ROLE UPDATES
-- After creating the 4 demo accounts in the Auth dashboard,
-- find their UUIDs in Authentication → Users, then run:
--
UPDATE public.profiles SET role = 'dispatcher' WHERE id = '92e8eedb-a17a-4f91-a6df-53a02ae4774d';
UPDATE public.profiles SET role = 'hospital', hospital_id = 'b2c3d4e5-f6a7-8901-bcde-f12345678901'  -- Mulago
     WHERE id = '556728b1-f3a7-441c-b095-952f2d8a94a7';
--
UPDATE public.profiles SET role = 'admin' WHERE id = '68a07cee-8108-4f63-9866-71c292c3ca48';
--
--   -- driver role is already the default; just link the ambulance:
 UPDATE public.ambulances SET driver_id = '624afe4b-f573-4301-8aa1-22c4cd3b791c' WHERE plate_number = 'UBE 001A';
--
-- The driver account email is katusiime66+driver@gmail.com — link
-- that user to ambulance UBE 001A so dispatch tests work immediately.
-- ============================================================


-- ============================================================
-- DEMO DISPLAY NAMES
-- The 4 demo accounts were created manually in the Auth dashboard
-- with no full_name in user metadata, so the auth trigger inserted
-- an empty string. Set readable display names for the admin Users
-- screen and avatar initials.
-- ============================================================
UPDATE public.profiles SET full_name = 'Patricia Nabukenya' WHERE id = '92e8eedb-a17a-4f91-a6df-53a02ae4774d';   -- dispatcher
UPDATE public.profiles SET full_name = 'Moses Kiggundu'     WHERE id = '624afe4b-f573-4301-8aa1-22c4cd3b791c';   -- driver
UPDATE public.profiles SET full_name = 'Grace Achieng'      WHERE id = '556728b1-f3a7-441c-b095-952f2d8a94a7';   -- hospital
UPDATE public.profiles SET full_name = 'Eugene Katusiime'   WHERE id = '68a07cee-8108-4f63-9866-71c292c3ca48';   -- admin
-- ============================================================
