# Caddie Cat

An Apple-native iOS app for quickly checking golf club distances on the course.

## Current Phase

Phase 4: Validation & Hardening.

Modules 1 through 9 cover the local model, logic, persistence, first iOS app shell, add-club flow, target-yardage lookup, inactive-club management, club editing, bag-entry polish, and first-run bag setup. Phase 4 is adding edge-case coverage and final V1 hardening before any broader app polish or release prep.

## V1 Goal

Build a simple, offline-first iOS app that lets golfers store club distances by profile and quickly find the closest club options for a target yardage.

## Development Notes

- Keep the V1 simple and focused.
- Prioritize fast on-course readability over editing convenience.
- Store all data locally on the device.
- Use Apple-native iOS development tools and patterns.
- Ask before pushing anything to GitHub.
- Generate the Xcode project from `project.yml` with XcodeGen when project settings change.

## Validation

- Run unit tests with `swift test`.
- Run the iOS smoke UI test with `xcodebuild test -project GolfYardageCheatsheet.xcodeproj -scheme GolfYardageCheatsheet -destination 'platform=iOS Simulator,name=iPhone 17'`.
