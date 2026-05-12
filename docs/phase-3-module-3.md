# Phase 3: Module 3 - iOS App Shell

## Goal

Create the native iOS app target and first profile flow.

## Scope

- Xcode project generation through `project.yml`.
- SwiftUI app entry point.
- Profile selection screen.
- Forced profile creation when no profiles exist.
- Add-profile sheet when profiles already exist.
- Placeholder yardage dashboard after selecting or creating a profile.

## Notes

- The app target currently shares the core Swift files from `Sources/GolfYardageCheatsheet`.
- `project.yml` is the readable project definition.
- `GolfYardageCheatsheet.xcodeproj` is generated from `project.yml` so the project can be opened directly in Xcode.
- Add-club UI is intentionally left disabled until the next module.

