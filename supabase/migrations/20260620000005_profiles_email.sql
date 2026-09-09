-- ============================================================
-- Migration 005 — Profiles email column
-- Needed for the admin "Create User" and "Reset Password" flows:
-- the admin Users screen displays each user's email, and the
-- profiles table is the only client-readable source of truth
-- (admins cannot query auth.users directly from the Flutter app).
-- ============================================================

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email TEXT NOT NULL DEFAULT '';

-- Backfill existing rows from auth.users
UPDATE public.profiles p
SET email = u.email
FROM auth.users u
WHERE u.id = p.id AND p.email = '';

-- Auth trigger now also copies the new user's email onto the profile
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    INSERT INTO public.profiles (id, full_name, role, phone, email)
    VALUES (
        NEW.id,
        COALESCE(NEW.raw_user_meta_data->>'full_name', ''),
        COALESCE(NEW.raw_user_meta_data->>'role', 'driver'),
        COALESCE(NEW.raw_user_meta_data->>'phone', ''),
        COALESCE(NEW.email, '')
    );
    RETURN NEW;
END;
$$;
