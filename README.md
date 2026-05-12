# Golf Yardage Cheatsheet

An Apple-native iOS app for quickly checking golf club yardages on the course.

## Current Phase

Phase 3: Iterative Execution.

Modules 1 through 5 cover the local model, logic, persistence, first iOS app shell, add-club flow, and target-yardage lookup. The project is using a state-gated process, so inactive-club management will wait for explicit approval after the lookup flow is reviewed.

## V1 Goal

Build a simple, offline-first iOS app that lets golfers store club distances by profile and quickly find the closest club options for a target yardage.

## Development Notes

- Keep the V1 simple and focused.
- Prioritize fast on-course readability over editing convenience.
- Store all data locally on the device.
- Use Apple-native iOS development tools and patterns.
- Ask before pushing anything to GitHub.
- Generate the Xcode project from `project.yml` with XcodeGen when project settings change.
