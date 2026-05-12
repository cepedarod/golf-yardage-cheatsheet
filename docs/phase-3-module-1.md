# Phase 3: Module 1 - Core Logic

## Goal

Build the first small unit of value: the local model and logic layer for club data.

No UI has been added in this module.

## Scope

- Swift package scaffold for testable core logic.
- Club type and shot type definitions.
- Swing and putter distance sets.
- Golfer profile and club models.
- Club display-name formatting.
- Club validation rules.
- Closest-yardage matching.
- Unit tests for the highest-risk rules.

## Notes

- The matcher returns the best match per club so a single club cannot fill both closest-result slots.
- Wedge loft is stored separately from club type.
- Wedge loft affects display names only when no nickname exists.
- Full iOS app scaffolding still requires Xcode to be installed or selected on the machine.

