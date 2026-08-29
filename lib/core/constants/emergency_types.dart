/// Canonical emergency-type options, shared by the dispatcher's and patient's
/// incident forms so the two lists can't drift out of sync. Each label must
/// match a case in the `set_incident_priority()` trigger
/// (supabase/migrations/20260829000026_incident_priority.sql) for auto-derived
/// severity to apply.
const List<String> emergencyTypes = [
  'Road Traffic Accident',
  'Cardiac Arrest',
  'Breathing Difficulty',
  'Trauma / Injury',
  'Obstetric / Childbirth Emergency',
  'Stroke',
  'Unconscious Patient',
  'Fire / Burns',
  'Poisoning / Overdose',
  'Severe Bleeding',
  'Seizure',
  'Other',
];
