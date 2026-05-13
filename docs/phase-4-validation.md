# Phase 4 - Validation & Hardening

## Edge Cases Covered

1. Invalid target lookup input: zero, negative targets, and zero result limits now have explicit matcher coverage.
2. Corrupt or invalid saved club data: matcher ignores non-positive distances, and validator rejects impossible putter/non-putter data combinations.
3. Cross-profile club edits: repository rejects updates that try to reuse a club ID under a different profile and preserves the original club.
4. Missing club mutations: repository returns `clubNotFound` for restore, deactivate, or delete actions against an unknown club ID.
5. Local file-store failures: tests cover missing files, corrupt JSON, and creating missing directories while saving.

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

## Performance Notes

- Current lookup work is small for V1 because a personal golf bag has a tiny club count.
- If the app grows to large historical datasets, cache active clubs by selected profile in the view model instead of repeatedly loading and filtering all clubs.
- If target matching ever becomes noticeably expensive, precompute each club's filled distance entries after loading the profile and reuse them during target changes.
- Keep JSON storage for V1; consider SwiftData only if future features require richer queries, relationships, or migration support.
