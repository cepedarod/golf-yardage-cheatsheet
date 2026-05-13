# V1 QA Punch List

## Automated Checks

- `swift test`: passed with 35 tests.
- `xcodebuild -project GolfYardageCheatsheet.xcodeproj -scheme GolfYardageCheatsheet -destination 'platform=iOS Simulator,name=iPhone 17' build`: passed.
- `xcodebuild test -project GolfYardageCheatsheet.xcodeproj -scheme GolfYardageCheatsheet -destination 'platform=iOS Simulator,name=iPhone 17'`: passed with 8 UI smoke tests.
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

- Restart the app and confirm saved profiles/clubs persist.

## Suggested V1 Fixes Before Release

1. Run one real-device readability pass outdoors or near bright light.

## Completed V1 Fixes

- Added delete confirmation for inactive club deletion.
- Added a small smoke UI test target for first launch, profile creation, and add-club navigation.
- Added Caddie Cat app icon assets before TestFlight or device install.
- Added UI smoke coverage for adding a club with `Finish` and adding multiple clubs with `Save & Add Another`.
- Added UI smoke coverage for target yardage entry showing only the two closest club matches.
- Added UI smoke coverage for Punch filter visibility.
- Added UI smoke coverage for editing a club from the dashboard swipe action.
- Added UI smoke coverage for target yardage auto-clear using a shortened test delay while production remains two minutes.
- Added UI smoke coverage for inactive-club restore and permanent delete confirmation flows.
