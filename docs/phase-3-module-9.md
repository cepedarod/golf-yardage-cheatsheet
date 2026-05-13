# Phase 3 Module 9 - First Bag Setup Polish

## Scope

- Added a first-run bag setup prompt when a selected profile has no active or inactive clubs.
- Kept the prompt one-time per dashboard visit so canceling the sheet returns the user to the dashboard.
- Added a visible `Add First Club` action to the empty dashboard state.
- Clarified the empty dashboard state when a profile has inactive clubs but no active clubs.
- Changed the add-club confirmation action to `Finish` while leaving edit mode as `Save`.

## Notes

- Profiles with inactive clubs are not treated as brand-new bags, since they already have stored club data.
- The existing `Save & Add Another` action remains the fast path for entering a full bag.
