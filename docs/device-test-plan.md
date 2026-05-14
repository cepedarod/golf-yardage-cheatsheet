# Device Test Plan

## Current Readiness

- `xcodebuild -project GolfYardageCheatsheet.xcodeproj -scheme GolfYardageCheatsheet -configuration Debug -sdk iphoneos CODE_SIGNING_ALLOWED=NO build`: passed.
- `xcrun xctrace list devices`: shows `Lemmy Machine`.
- V2 beta `xcodebuild -project GolfYardageCheatsheet.xcodeproj -scheme GolfYardageCheatsheet -destination 'platform=iOS,name=Lemmy Machine' -allowProvisioningUpdates build`: passed with automatic signing.
- V2 beta `xcrun devicectl device install app --device 0ACBB310-B196-5C2B-87A1-E1D47EC481CC "<DerivedData>/Build/Products/Debug-iphoneos/Caddie Cat.app"`: installed successfully.
- V2 beta `xcrun devicectl device process launch --device 0ACBB310-B196-5C2B-87A1-E1D47EC481CC com.cepedarod.GolfYardageCheatsheet`: launched successfully.
- V1 physical smoke pass: passed.
- V2 physical beta pass: pending.

## One-Time Xcode Setup

1. Open `GolfYardageCheatsheet.xcodeproj` in Xcode.
2. Open Xcode Settings, then Accounts, and add the Apple ID you want to use for local device signing.
3. Select the `GolfYardageCheatsheet` project, then the `GolfYardageCheatsheet` app target.
4. In Signing & Capabilities, select your personal or paid development team.
5. Keep automatic signing enabled. The current development team is `6G3D6K987W`.
6. If the bundle identifier is unavailable, change it to a unique value such as `com.cepedarod.caddiecat`.

## iPhone Setup

1. Connect the iPhone by cable.
2. Unlock the phone and accept any `Trust This Computer` prompt.
3. Enable Developer Mode on the phone in Settings -> Privacy & Security -> Developer Mode, then restart it.
4. Trust the Apple Development profile in Settings -> General -> VPN & Device Management after the first install.
5. In Xcode, select the physical iPhone as the run destination.
6. Run the app from Xcode.

## V2 Physical Beta Pass

1. Confirm the app appears as `Caddie Cat` with the final cat caddie icon.
2. Fresh install:
   - Create a profile.
   - Confirm the Add Club flow opens.
3. Add clubs:
   - Add one normal club.
   - Add one club with Low Trajectory values.
   - Add one wedge with loft and Flop values.
   - Confirm switching distance categories in Add/Edit Club preserves already-entered values.
4. Dashboard:
   - Confirm the title says `Distance`.
   - Confirm the label-over-yardage grid is readable.
   - Confirm Half and Quarter labels fit.
   - Confirm empty swing distances show `-`.
   - Confirm Normal filter shows normal and wedge Flop values when present.
   - Confirm Low Trajectory filter only shows Low Trajectory values.
   - Confirm Manual mode shows manually-entered values.
   - Confirm Real mode shows Pure-shot averages and parenthesized manual fallbacks.
5. Target yardage:
   - Enter a target.
   - Confirm the result shows the closest long shot and closest short shot.
   - Confirm Normal target results exclude Low Trajectory shots.
   - Confirm Low Trajectory target results include only Low Trajectory shots.
   - Confirm Manual and Real modes use their selected value source.
   - Confirm a supplemental third result appears only when it is closer than both primary results.
   - Confirm Clear exits target mode.
6. Record shots:
   - Record a Pure shot with a distance and confirm Real mode updates.
   - Record a Thin or Chunk shot with a distance and confirm it does not affect Real average distance.
   - Record a shot with no distance and confirm recorded-shot history shows `-`.
   - Record a Low Trajectory shot.
   - Record a Flop shot for a wedge.
7. Analysis:
   - Confirm active clubs appear before inactive clubs.
   - Open a club and confirm total shots, Manual/Average comparison, strike distribution, and direction distribution.
   - Tap Total Shots and confirm recorded shots are chronological.
   - Edit a recorded shot and confirm the list updates.
   - Delete a recorded shot and confirm it disappears.
8. Edit clubs:
   - Edit an existing club distance.
   - Confirm the dashboard updates.
9. Inactive clubs:
   - Deactivate a club.
   - Restore it from Inactive Clubs.
   - Deactivate another club and delete it from Inactive Clubs.
10. Relaunch:
   - Force quit and reopen the app.
   - Confirm the selected profile, saved clubs, and recorded shots persist.
11. Readability:
   - Check the dashboard indoors and near bright outdoor light.
   - Confirm row text and yardage numbers are readable at normal phone distance.
