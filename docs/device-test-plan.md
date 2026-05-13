# Device Test Plan

## Current Readiness

- `xcodebuild -project GolfYardageCheatsheet.xcodeproj -scheme GolfYardageCheatsheet -configuration Debug -sdk iphoneos CODE_SIGNING_ALLOWED=NO build`: passed.
- `xcrun xctrace list devices`: shows `Lemmy Machine`.
- `xcodebuild -project GolfYardageCheatsheet.xcodeproj -scheme GolfYardageCheatsheet -destination 'id=00008130-001A3CE60A3A001C' -allowProvisioningUpdates build`: passed with automatic signing.
- `xcrun devicectl device install app --device 00008130-001A3CE60A3A001C "<DerivedData>/Build/Products/Debug-iphoneos/Caddie Cat.app"`: installed successfully.
- First command-line launch is blocked until the iPhone trusts the Apple Development profile in Settings -> General -> VPN & Device Management.

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

## Physical QA Pass

1. Confirm the app appears as `Caddie Cat` with the final cat caddie icon.
2. Fresh install:
   - Create a profile.
   - Confirm the Add Club flow opens.
3. Add clubs:
   - Add one normal club.
   - Add one Punch club.
   - Add one wedge with loft.
4. Dashboard:
   - Confirm the title says `Distance`.
   - Confirm the label-over-yardage grid is readable.
   - Confirm Half and Quarter labels fit.
5. Target yardage:
   - Enter a target.
   - Confirm only the two closest clubs show.
   - Confirm Clear exits target mode.
6. Edit:
   - Edit an existing club distance.
   - Confirm the dashboard updates.
7. Inactive clubs:
   - Deactivate a club.
   - Restore it from Inactive Clubs.
   - Deactivate another club and delete it from Inactive Clubs.
8. Relaunch:
   - Force quit and reopen the app.
   - Confirm the selected profile and saved clubs persist.
9. Readability:
   - Check the dashboard indoors and near bright outdoor light.
   - Confirm row text and yardage numbers are readable at normal phone distance.
