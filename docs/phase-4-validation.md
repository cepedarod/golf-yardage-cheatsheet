# Phase 4 - Validation & Hardening

## Edge Cases Covered

1. Invalid target lookup input: zero, negative targets, and zero result limits now have explicit matcher coverage.
2. Corrupt or invalid saved club data: matcher ignores non-positive distances, and validator rejects impossible putter/non-putter data combinations.
3. Cross-profile club edits: repository rejects updates that try to reuse a club ID under a different profile and preserves the original club.
4. Missing club mutations: repository returns `clubNotFound` for restore, deactivate, or delete actions against an unknown club ID.
5. Local file-store failures: tests cover missing files, corrupt JSON, and creating missing directories while saving.
6. App reload failures: profile and dashboard view models clear stale screen state on load failure and clear old errors after a successful reload.
7. Target lookup mode: the dashboard now hides the full active club list while a valid target is entered, so target mode shows only the closest club recommendations.
8. Punch-only filtering: target lookup and the normal dashboard club list now share the same Punch-only filter rule.
9. Permanent deletion safety: inactive club deletion now requires confirmation before removing stored data.
10. First-launch smoke coverage: XCUITest verifies profile creation opens the add-club flow for a brand-new bag.
11. Add-club save paths: XCUITest verifies `Finish` saves a club and `Save & Add Another` saves multiple clubs in sequence.
12. Target-yardage recommendations: XCUITest verifies target entry switches the dashboard to the two closest visible club matches.

## Tests Added

- `YardageMatcherTests`
  - Invalid targets and limits return no matches.
  - Non-positive distances are ignored when matching.
- `ClubValidatorTests`
  - Putter records with shot type or swing distances are rejected.
  - Non-putter records with putter distances are rejected.
- `GolfBagRepositoryTests`
  - Cross-profile club overwrites are rejected without data loss.
  - Missing club restore/deactivate/delete paths throw `clubNotFound`.
- `FileGolfBagStoreTests`
  - Missing store file loads as empty data.
  - Corrupt JSON throws rather than silently replacing data.
  - Saving creates missing directories and persists data.
- App state hardening
  - Profile loading clears stale profiles and selection when loading fails.
  - Dashboard club loading clears stale clubs and matches when loading fails.
- `ShotFilterTests`
  - All mode includes normal, punch, and putter clubs.
  - Punch-only mode includes only clubs marked as Punch.
- `GolfYardageCheatsheetUITests`
  - Fresh launch creates a profile and opens the add-club flow.
  - Add-club `Finish` saves a club and returns to the dashboard.
  - `Save & Add Another` saves one club, resets the form, and allows saving a second club.
  - Target yardage entry shows only the two closest club recommendations.

## Performance Notes

- Current lookup work is small for V1 because a personal golf bag has a tiny club count.
- If the app grows to large historical datasets, cache active clubs by selected profile in the view model instead of repeatedly loading and filtering all clubs.
- If target matching ever becomes noticeably expensive, precompute each club's filled distance entries after loading the profile and reuse them during target changes.
- Keep JSON storage for V1; consider SwiftData only if future features require richer queries, relationships, or migration support.
