# Phase 3 Module 4 - Add Club Flow

## Scope

- Replaced the disabled dashboard placeholder with an active bag dashboard.
- Added a native SwiftUI add-club sheet.
- Wired club saves through `GolfBagRepository` so the shared validator and local JSON store remain the source of truth.
- Added active-club loading and sorting for the selected profile.

## Included Rules

- Club type selection uses the existing `ClubType` list.
- Nickname is optional.
- Wedge loft is available only for wedge club types.
- Wedge loft accepts whole-number input and validates through the 30-80 core rule.
- Putters collect Long, Medium, and Short values.
- Non-putters collect Full, 3/4, Half, and Quarter values.
- At least one distance is required before save succeeds.
- Wedge shot types are Normal or Flop.
- Non-wedge, non-putter shot types are Normal or Punch.

## Next Gate

The next module should add the target-yardage lookup screen using the existing matcher, then inactive-club management can follow as a separate focused pass.
