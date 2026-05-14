# Caddie Cat

An Apple-native iOS app for quickly checking golf club distances on the course.

## Current Phase

V2 beta validation.

The app has moved beyond the original V1 distance cheat sheet into the V2 beta scope: distance categories, Manual/Real values, shot recording, club analysis, and recorded-shot history are implemented on `codex/v2-beta`. Current work is focused on simulator validation, physical iPhone beta testing, and final visual polish.

## Product Goal

Build a simple, offline-first iOS app that lets golfers store club distances by profile and quickly find the closest club options for a target yardage.

## Development Notes

- Keep the app simple and focused.
- Prioritize fast on-course readability over editing convenience.
- Store all data locally on the device.
- Use Apple-native iOS development tools and patterns.
- Keep commits small and push checkpoints after validation.
- Generate the Xcode project from `project.yml` with XcodeGen when project settings change.

## Validation

- Run unit tests with `swift test`.
- Run the iOS smoke UI suite with `xcodebuild test -project GolfYardageCheatsheet.xcodeproj -scheme GolfYardageCheatsheet -destination 'platform=iOS Simulator,name=iPhone 17'`.
- Verify device SDK compilation with `xcodebuild -project GolfYardageCheatsheet.xcodeproj -scheme GolfYardageCheatsheet -configuration Debug -sdk iphoneos CODE_SIGNING_ALLOWED=NO build`.
- Use `docs/device-test-plan.md` for physical iPhone setup and hands-on QA.

## Current QA Status

- `swift test`: 52 tests passing.
- iOS simulator smoke suite: 13 UI tests passing.
- Unsigned `iphoneos` Debug build: passing.
- Physical iPhone V2 beta signed build: passing with automatic signing.
- Physical iPhone V2 beta install: passing on `Lemmy Machine`.
- Physical iPhone V2 beta launch: passing on `Lemmy Machine`.
- Physical iPhone V1 smoke pass: passed, with follow-up refinements implemented from testing feedback.
- Physical iPhone V2 beta pass: pending.
