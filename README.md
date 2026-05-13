# Caddie Cat

An Apple-native iOS app for quickly checking golf club distances on the course.

## Current Phase

V1 release-readiness.

The app is feature-complete for the current personal/friends V1 scope, with simulator QA covered by unit tests and UI smoke tests. Physical iPhone signing, install, launch, and hands-on smoke testing are working.

## V1 Goal

Build a simple, offline-first iOS app that lets golfers store club distances by profile and quickly find the closest club options for a target yardage.

## Development Notes

- Keep the V1 simple and focused.
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

- `swift test`: 38 tests passing.
- iOS simulator smoke suite: 9 UI tests passing.
- Unsigned `iphoneos` Debug build: passing.
- Physical iPhone signed build: passing with automatic signing.
- Physical iPhone install: passing on `Lemmy Machine`.
- Physical iPhone launch: passing on `Lemmy Machine`.
- Physical iPhone smoke pass: passed, with follow-up refinements implemented from testing feedback.
