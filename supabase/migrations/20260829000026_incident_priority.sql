-- Migration 026: Incident prioritization
-- Adds priority to incidents (auto-derived server-side from nature_of_emergency,
-- overridable by dispatcher/admin), a generated priority_rank for cheap sorting,
-- and an index supporting the priority-first dashboard/list queries.

-- ── 1. Schema changes ──────────────────────────────────────────────────────────

ALTER TABLE public.incidents
  ADD COLUMN IF NOT EXISTS priority text NOT NULL DEFAULT 'medium';

ALTER TABLE public.incidents
  DROP CONSTRAINT IF EXISTS incidents_priority_check;

ALTER TABLE public.incidents
  ADD CONSTRAINT incidents_priority_check CHECK (
    priority IN ('critical', 'high', 'medium', 'low')
  );

-- Sortable numeric rank (lower = more severe). PostgREST .order() only takes a
-- column name, not an expression, and 'critical' < 'high' < 'low' < 'medium'
-- alphabetically does not match severity order — so we store the rank.
ALTER TABLE public.incidents
  ADD COLUMN IF NOT EXISTS priority_rank smallint
  GENERATED ALWAYS AS (
    CASE priority
      WHEN 'critical' THEN 0
      WHEN 'high'      THEN 1
      WHEN 'medium'    THEN 2
      WHEN 'low'       THEN 3
      ELSE 2
    END
  ) STORED;

CREATE INDEX IF NOT EXISTS incidents_priority_rank_created_idx
  ON public.incidents (priority_rank, created_at);

-- ── 2. Trigger: auto-derive priority from nature_of_emergency ──────────────────
-- Runs server-side so it can't be skipped or spoofed by either client. Only
-- upgrades from the default 'medium' — an explicit non-default priority on
-- insert (not currently used by any client, but kept for forward-compat) is
-- left untouched.
--
-- First-pass severity mapping, not a medical judgment — flag for review by a
-- domain-knowledgeable reviewer before treating it as final.

CREATE OR REPLACE FUNCTION public.set_incident_priority()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.priority = 'medium' THEN
    NEW.priority := CASE NEW.nature_of_emergency
      WHEN 'Cardiac Arrest'      THEN 'critical'
      WHEN 'Stroke'              THEN 'critical'
      WHEN 'Unconscious Patient' THEN 'critical'
      WHEN 'Severe Bleeding'     THEN 'critical'

      WHEN 'Breathing Difficulty'                THEN 'high'
      WHEN 'Trauma / Injury'                      THEN 'high'
      WHEN 'Obstetric / Childbirth Emergency'     THEN 'high'
      WHEN 'Poisoning / Overdose'                 THEN 'high'
      WHEN 'Seizure'                               THEN 'high'

      WHEN 'Road Traffic Accident' THEN 'medium'
      WHEN 'Fire / Burns'          THEN 'medium'

      WHEN 'Other' THEN 'low'

      ELSE 'medium'
    END;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS incidents_set_priority ON public.incidents;
CREATE TRIGGER incidents_set_priority
  BEFORE INSERT ON public.incidents
  FOR EACH ROW
  EXECUTE FUNCTION public.set_incident_priority();
