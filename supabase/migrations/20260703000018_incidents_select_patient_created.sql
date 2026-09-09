-- Migration 018: Patients must be able to read an incident immediately after
-- creating it (PatientService.createPatientIncident() does insert().select()),
-- but the existing incidents_select_patient_own policy only matched via a
-- trips.patient_id row, which isn't created until dispatch_incident() runs
-- afterward. This caused a 403 on POST /incidents?select=* right at creation.

DROP POLICY IF EXISTS "incidents_select_patient_own" ON public.incidents;

CREATE POLICY "incidents_select_patient_own"
ON public.incidents FOR SELECT TO authenticated
USING (
    public.current_user_role() = 'patient'
    AND (
        created_by = auth.uid()
        OR id IN (
            SELECT incident_id FROM public.trips WHERE patient_id = auth.uid()
        )
    )
);
