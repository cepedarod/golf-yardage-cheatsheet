# Caddie Cat

Caddie Cat is an Apple-native iPhone app for tracking golf shot distances, learning real club yardages, and making faster on-course club decisions.

## Current State

V4 is complete and the project is in App Store handoff preparation.

Current release branch:

`codex/v4-app-store-ready`

The app is ready for final App Store Connect upload prep through a developer account owner. The existing bundle ID should remain unchanged for the first release:

`com.cepedarod.GolfYardageCheatsheet`

Keeping the current bundle ID preserves continuity with existing on-device app data.

## What Caddie Cat Does

- Stores golfer profiles, clubs, and static yardages locally on device.
- Tracks distances for full, 3/4, half, quarter, flop, and low-trajectory shots.
- Suggests closest club and swing options for a target yardage.
- Records shots with club, distance, shot type, grass, strike quality, direction, and timestamp.
- Calculates app-generated yardage averages from tracked shots.
- Shows static values and app-calculated values side by side.
- Supports GPS shot tracking during active rounds.
- Lets users audit GPS distances on a map and manually adjust start or finish points.
- Tracks rounds, round shot counts, and recorded shot history.
- Uses Live Activities and Dynamic Island for active-round access.
- Supports altitude-aware distance adjustment from a user home base.
- Provides overall and club-specific analysis for distances, grass modifiers, strike quality, and shot direction.
- Includes an in-app instruction manual.

## App Store Readiness

Public support and privacy pages are live through GitHub Pages:

- Support: https://cepedarod.github.io/golf-yardage-cheatsheet/support.html
- Privacy Policy: https://cepedarod.github.io/golf-yardage-cheatsheet/privacy-policy.html

App Store handoff materials:

- [App Store handoff checklist](docs/app-store-handoff.md)
- [App Store readiness notes](docs/app-store-readiness.md)
- [App Store screenshots](docs/app-store-screenshots)
- [Support page source](docs/support.md)
- [Privacy policy source](docs/privacy-policy.md)

Approved App Store metadata:

- App name: `Caddie Cat`
- Subtitle: `Track your golf game like never before`
- Category: `Sports`
- Age rating target: all ages
- Support email: `cepedarod@gmail.com`

## Product Goal

Caddie Cat is built for golfers who want practical yardage knowledge beyond a basic club-distance chart. The app helps users understand how far they hit different clubs across real shot types, swing lengths, lies, and trajectories, then turns that data into quick on-course recommendations.

## Development Notes

- Keep the app simple and fast for on-course use.
- Prioritize readability and low-friction workflows.
- Store user golf data locally on device.
- Use Apple-native iOS tools and SwiftUI patterns.
- Keep the current bundle ID for the first App Store release.
- Generate the Xcode project from `project.yml` with XcodeGen when project settings change.

## Validation

Recommended local checks:

- Unit tests: `swift test`
- iOS UI smoke suite: `xcodebuild test -project GolfYardageCheatsheet.xcodeproj -scheme GolfYardageCheatsheet -destination 'platform=iOS Simulator,name=iPhone 17'`
- Device SDK compile: `xcodebuild -project GolfYardageCheatsheet.xcodeproj -scheme GolfYardageCheatsheet -configuration Debug -sdk iphoneos CODE_SIGNING_ALLOWED=NO build`
- Physical iPhone QA: use [device-test-plan.md](docs/device-test-plan.md)

Most recent recorded V4 validation:

- Unit tests passing.
- Generic iOS build passing.
- Physical iPhone install and launch passing.
- Physical iPhone V4 smoke testing passing.
- App Store screenshots generated at 1320 x 2868.
- GitHub Pages privacy and support URLs returning HTTP 200.

## Next Release Steps

1. Developer account owner opens the project in Xcode.
2. Developer account owner signs the main app and Live Activity extension.
3. Archive and upload the build to App Store Connect.
4. Enter metadata, privacy details, age rating, support URL, privacy policy URL, and screenshots.
5. Invite Rodrigo to TestFlight.
6. Run a TestFlight smoke test on the release build.
7. Submit for App Review.
