# Phase 2: Modular Blueprint

## Status

Draft for approval.

This document defines the project structure, model contracts, validation rules, and coding standards before implementation begins.

## Recommended Project Structure

```text
GolfYardageCheatsheet/
  GolfYardageCheatsheetApp.swift
  Models/
    GolferProfile.swift
    Club.swift
    ClubType.swift
    ShotType.swift
    SwingDistanceSet.swift
    PutterDistanceSet.swift
    YardageMatch.swift
  Services/
    YardageMatcher.swift
    ClubDisplayNameFormatter.swift
    ClubValidator.swift
  ViewModels/
    ProfileSelectionViewModel.swift
    YardageDashboardViewModel.swift
    AddClubViewModel.swift
    BagManagementViewModel.swift
  Views/
    Profiles/
      ProfileSelectionView.swift
      CreateProfileView.swift
    Yardage/
      YardageDashboardView.swift
      TargetYardageInputView.swift
      ClubDistanceListView.swift
      ShotFilterToggleView.swift
    Bag/
      AddClubView.swift
      ClubDistanceFormView.swift
      ManageBagView.swift
      InactiveClubsView.swift
    Shared/
      ClubRowView.swift
      LargeActionButton.swift
      EmptyStateView.swift
  Resources/
    Assets.xcassets
  Tests/
    YardageMatcherTests.swift
    ClubValidatorTests.swift
    ClubDisplayNameFormatterTests.swift
```

Beginner-friendly reason for this structure: each folder has one job. Models describe the data, Services handle reusable logic, ViewModels prepare data for screens, and Views draw the interface. That separation keeps the app easier to understand and safer to change.

## Data Model Contracts

### GolferProfile

Represents one golfer who can have their own bag.

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| id | UUID | Yes | Unique profile identifier |
| name | String | Yes | Display name for the golfer |
| clubs | List of Club | Yes | Clubs that belong to this profile |
| createdAt | Date | Yes | Used for stable ordering and debugging |
| updatedAt | Date | Yes | Updated when profile details change |

### Club

Represents one club entry for one golfer profile.

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| id | UUID | Yes | Unique club identifier |
| profile | GolferProfile | Yes | Parent profile relationship |
| nickname | String? | No | Overrides club type in display when present |
| clubType | ClubType | Yes | Driver, woods, hybrids, irons, wedges, or putter |
| wedgeLoft | Int? | No | Optional whole-number loft for wedge entries only |
| shotType | ShotType? | Conditional | Not used for putter; defaults to Normal otherwise |
| isActive | Bool | Yes | Inactive clubs are hidden from main yardage view |
| swingDistances | SwingDistanceSet? | Conditional | Used for non-putters |
| putterDistances | PutterDistanceSet? | Conditional | Used only for putter |
| createdAt | Date | Yes | Used for stable ordering |
| updatedAt | Date | Yes | Updated when club details change |

### SwingDistanceSet

Used for every non-putter club.

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| full | Int? | No | Yardage for full swing |
| threeQuarter | Int? | No | Yardage for 3/4 swing |
| half | Int? | No | Yardage for 1/2 swing |
| quarter | Int? | No | Yardage for 1/4 swing |

At least one of these values must be present before saving.

### PutterDistanceSet

Used only for putter entries.

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| long | Int? | No | Yardage or pace reference for long stroke |
| medium | Int? | No | Yardage or pace reference for medium stroke |
| short | Int? | No | Yardage or pace reference for short stroke |

At least one of these values must be present before saving.

### YardageMatch

Represents one candidate result when the user enters a target yardage.

| Field | Type | Required | Notes |
| --- | --- | --- | --- |
| club | Club | Yes | The matching club |
| label | String | Yes | Full, 3/4, 1/2, 1/4, long, medium, or short |
| distance | Int | Yes | Recorded yardage |
| differenceFromTarget | Int | Yes | Absolute difference from the entered target |

## Enum Contracts

### ClubType

Recommended V1 values:

- Driver
- 3 Wood
- 5 Wood
- 7 Wood
- 2 Hybrid
- 3 Hybrid
- 4 Hybrid
- 5 Hybrid
- 2 Iron
- 3 Iron
- 4 Iron
- 5 Iron
- 6 Iron
- 7 Iron
- 8 Iron
- 9 Iron
- Pitching Wedge
- Gap Wedge
- Sand Wedge
- Lob Wedge
- Putter

This list is simple enough for V1 and covers the common range from driver through putter.

Wedge loft note: Pitching Wedge, Gap Wedge, Sand Wedge, and Lob Wedge remain available as normal club type options. When adding any wedge, the user may optionally enter a whole-number loft from 30 to 80 degrees. If a loft is entered and there is no nickname, the display name uses the loft, such as `54° Wedge`.

### ShotType

Recommended V1 values:

- Normal
- Punch
- Flop

Rules:

- Putter has no shot type.
- Wedges can use Normal or Flop.
- Non-wedge, non-putter clubs can use Normal or Punch.
- Normal is the default for non-putters.

## Display Name Rules

| Club setup | Display name |
| --- | --- |
| No nickname, Normal shot | Club type |
| Nickname, Normal shot | Nickname |
| Wedge with loft, no nickname, Normal shot | Loft + "° Wedge" |
| Wedge with loft and nickname, Normal shot | Nickname |
| No nickname, Flop shot | Club type + " (Flop)" |
| Nickname, Flop shot | Nickname + " (Flop)" |
| Wedge with loft, no nickname, Flop shot | Loft + "° Wedge (Flop)" |
| Wedge with loft and nickname, Flop shot | Nickname + " (Flop)" |
| No nickname, Punch shot | Club type + " (Punch)" |
| Nickname, Punch shot | Nickname + " (Punch)" |
| Putter with nickname | Nickname |
| Putter without nickname | Putter |

## Validation Rules

- Profile name is required.
- Club type is required.
- Nickname is optional.
- Wedge loft is optional for Pitching Wedge, Gap Wedge, Sand Wedge, and Lob Wedge.
- Wedge loft must be a positive whole number from 30 to 80 if entered.
- Wedge loft should be entered with a number pad so the user is not offered negative-number input.
- Wedge loft is not available for non-wedge clubs.
- Non-putter clubs require at least one swing distance.
- Putters require at least one putter stroke distance.
- Distances must be positive whole numbers.
- Putter entries cannot have Punch or Flop shot types.
- Wedges can be Normal or Flop.
- Non-wedge, non-putter clubs can be Normal or Punch.
- Inactive clubs remain stored but are excluded from the main yardage dashboard.

## Yardage Matching Contract

When the user enters a target yardage:

1. Start with active clubs for the selected profile.
2. If the Punch filter is on, only include clubs with Punch shot type.
3. Compare the target against every filled distance value.
4. Keep only the best match for each club, so one club cannot occupy both result slots.
5. Sort matches by smallest difference from the target.
6. Return two matches.
7. If more than two matches tie, prefer the entries whose club full-swing distance is closest to the target.
8. If still tied, keep the older club first based on creation order.
9. Clear the target yardage automatically after two minutes.

## Coding Standards

### Swift And SwiftUI

- Use Swift and SwiftUI for the iOS app.
- Use SwiftData for local persistence if the minimum iOS version is iOS 17 or newer.
- Use XCTest for unit tests.
- Keep views small and focused on display.
- Put business logic in services or view models, not directly inside views.

Beginner-friendly reason: SwiftUI screens can get messy if they do too much. Keeping logic outside the screen files makes bugs easier to find and gives us smaller pieces to test.

### Naming

- Use clear names that describe the app concept: `Club`, `GolferProfile`, `YardageMatcher`.
- Use singular names for models.
- Use `View` suffix for SwiftUI screens and reusable UI pieces.
- Use `ViewModel` suffix for screen state and screen actions.
- Use `Service`, `Validator`, or `Formatter` suffixes for reusable logic.

### Data Safety

- Do not delete club data when marking a club inactive.
- Keep delete and deactivate as separate actions.
- Keep V1 local-only; no cloud sync or accounts.
- Avoid password or authentication flows for V1 profiles.

### Testing Focus

V1 unit tests should cover:

- Club validation with empty distances.
- Putter validation rules.
- Wedge loft validation and display rules.
- Wedge Flop rules.
- Punch filtering.
- Closest-yardage matching and tie-breaking.
- Display name formatting with and without nicknames.

## Approval Gate

If this blueprint looks right, the next phase will be Phase 3: Iterative Execution.

Recommended first implementation module: local data model and validation logic. That gives the app a stable foundation before we build screens.
