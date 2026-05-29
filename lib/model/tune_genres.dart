/// Canonical, finite set of tune genres offered in the genre dropdown.
///
/// Genre is stored as free text in the database (and synced as such), but the
/// UI constrains selection to this list. Values must stay stable once shipped —
/// existing tunes store the string, so renaming an entry orphans those tunes
/// onto a non-listed value (which the editor still preserves, see
/// `TuneDetailPage`). Append new genres rather than renaming.
const List<String> kTuneGenres = [
  'Irish',
  'Scottish',
  'English',
  'Welsh',
  'Old-time',
  'Bluegrass',
  'New England',
  'American',
  'Texas',
  'Cape Breton',
  'French-Canadian',
  'Quebecois',
  'Swedish',
  'Danish',
  'Norwegian',
  'Finnish',
  'Other',
];
