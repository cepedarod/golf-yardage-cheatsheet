# Golf Yardage Cheatsheet

An Apple-native iOS app for quickly checking golf club yardages on the course.

## Current Phase

Phase 3: Iterative Execution.

Modules 1 through 3 cover the local model, logic, persistence, and first iOS app shell. The project is using a state-gated process, so the add-club flow will wait for explicit approval after the app shell is reviewed.

## V1 Goal

Build a simple, offline-first iOS app that lets golfers store club distances by profile and quickly find the closest club options for a target yardage.

## Development Notes

- Keep the V1 simple and focused.
- Prioritize fast on-course readability over editing convenience.
- Store all data locally on the device.
- Use Apple-native iOS development tools and patterns.
- Ask before pushing anything to GitHub.
- Generate the Xcode project from `project.yml` with XcodeGen when project settings change.
