/// Static list of exams students can pick from in Profile Setup / "Change
/// Exam". Kept as a plain constant for v1 — move to `/appConfig/global` in
/// Firestore later if this needs to be editable without an app release.
const List<String> examCatalog = [
  'CTET Paper 1',
  'CTET Paper 2',
  'UPTET',
  'REET',
  'MPTET',
  'Bihar STET',
  'HTET',
  'HP TET',
  'Rajasthan 3rd Grade Teacher',
  'KVS/NVS Recruitment',
  'DSSSB TGT/PGT',
  'Super TET (UP)',
];
