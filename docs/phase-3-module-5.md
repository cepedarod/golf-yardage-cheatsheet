# Phase 3 Module 5 - Target Yardage Lookup

## Scope

- Added a target-yardage input to the main dashboard.
- Added an All/Punch segmented filter.
- Shows the two closest active-club matches using the existing `YardageMatcher`.
- Keeps one result per club because that behavior remains inside the matcher.
- Clears target yardage automatically after two minutes.

## Notes

- Match rows display club name, matched swing or stroke label, saved distance, and whether the result is short, long, or exact.
- When target yardage is active, the full active club list is hidden so only the closest matches are shown.
- The next focused module should add inactive-club management.
