# V1 QA Punch List

## Automated Checks

- `swift test`: passed with 35 tests.
- `xcodebuild -project GolfYardageCheatsheet.xcodeproj -scheme GolfYardageCheatsheet -destination 'platform=iOS Simulator,name=iPhone 17' build`: passed.
- Clean simulator install: passed.

## Simulator Visual Checks

Screenshots were captured locally under `qa/screenshots/`.

1. Fresh install with no saved data
   - App opens directly to `Create Profile`.
   - `Create` is disabled while the name field is empty.
   - Layout has no visible overlap on iPhone 17.

2. Seeded representative bag data
   - Dashboard opens to the selected profile.
   - Active clubs are visible on the main dashboard.
   - Inactive seeded club is not shown on the main dashboard.
   - `Distance` is used as the dashboard title.
   - Club rows use the label-over-yardage grid.
   - `Stinger (Punch)` confirms nickname plus Punch suffix formatting.
   - `54° Wedge (Flop)` confirms loft plus Flop suffix formatting.
   - Half and Quarter labels render as words.

## Hands-On QA Still Needed

- Create a profile from the fresh install screen.
- Confirm the add-club sheet opens automatically for a brand-new empty profile.
- Add a club with `Finish`.
- Add multiple clubs using `Save & Add Another`.
- Edit a club from the dashboard swipe action.
- Enter a target yardage and confirm only the two closest matches display.
- Confirm target yardage clears after two minutes.
- Toggle Punch mode and confirm only Punch clubs remain visible.
- Open inactive clubs, restore a club, and delete a club.
- Restart the app and confirm saved profiles/clubs persist.

## Suggested V1 Fixes Before Release

1. Add a small smoke UI test target for first launch, profile creation, and add-club navigation.
2. Add app icon assets before any TestFlight or device install.
3. Run one real-device readability pass outdoors or near bright light.

## Completed V1 Fixes

- Added delete confirmation for inactive club deletion.
