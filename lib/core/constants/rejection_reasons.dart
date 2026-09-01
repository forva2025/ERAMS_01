/// Driver job-offer rejection reason categories. Values must match the
/// `trips.reject_reason_category` CHECK constraint in
/// supabase/migrations/20260831000029_decline_trip_reasons.sql.
const Map<String, String> rejectionReasonLabels = {
  'crew_not_qualified': 'Crew not qualified / lacking equipment',
  'outside_operational_area': 'Outside operational area',
  'needs_higher_level_of_care': 'Patient needs higher level of care',
  'unsafe_access_conditions': 'Unsafe access conditions',
};
