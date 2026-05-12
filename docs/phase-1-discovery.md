# Phase 1: Discovery & Technical Architecture

## Confirmed Product Decisions

- V1 is for personal use and friends, not a public commercial launch.
- Profiles only need a golfer name for now.
- Club entries may leave some distance values empty, but each club must have at least one distance value.
- Distances are stored in yards only.
- Target-yardage matching should compare against all recorded swing or stroke distances.
- If more than two entries tie for closest target distance, use the two clubs whose full-swing distances are closest to the target.
- Inactive clubs should only appear in a dedicated inactive clubs screen.
- The main app view should prioritize speed and readability over editing controls.
- V1 should work fully offline using local device storage.
- The app should be Apple-native iOS.

## Recommended Tech Stack

### App Platform

Use Swift and SwiftUI.

Swift is Apple's main programming language for iOS apps. SwiftUI is Apple's modern UI framework. This is the simplest native path for a new iOS app because it avoids bringing in a cross-platform layer and keeps us aligned with current Apple tooling.

### Local Data Storage

Use SwiftData if the minimum iOS version can be iOS 17 or newer.

SwiftData is Apple's newer local persistence framework. It is built for storing structured app data like profiles and clubs. It gives us durable local storage, so the data should survive app closes, phone restarts, and normal iOS updates.

If we later decide the app must support older iOS versions, Core Data would be the fallback.

### State Management

Use SwiftUI state plus a small view model layer.

For a simple V1, we do not need a large architecture framework. SwiftUI's built-in state tools are enough for screen-level interactions, while small view models can hold logic like target-yardage filtering and form validation.

### Testing

Use XCTest for unit tests.

XCTest is Apple's standard testing framework. In V1, the most important tests should cover the distance-matching logic, form validation, and profile/club data rules.

## High-Level Architecture Plan

### Screens

1. Profile selection screen
   - Shows existing golfer profiles.
   - Forces profile creation if no profiles exist.
   - Allows adding a new profile with a plus button.

2. Main yardage screen
   - Shows active club distances for the selected profile.
   - Includes a large target-yardage input at the top.
   - Shows only the two closest club options when a target yardage is entered.
   - Auto-clears the target yardage after two minutes.
   - Includes a quick toggle for All vs Punch shots.

3. Add club flow
   - Used when a profile has no clubs yet.
   - Also available later from the main app.
   - Captures club type, optional nickname, shot type, and distances.
   - Requires at least one distance value before saving.
   - Supports "Add Club" and "Add and Finish".

4. Bag management screen
   - Used for editing, deleting, and marking clubs inactive.
   - Keeps editing controls away from the fast on-course screen.

5. Inactive clubs screen
   - Shows inactive clubs for the selected profile.
   - Allows reactivating or deleting inactive club data.

### Core Data Models

#### GolferProfile

Represents one golfer.

Likely fields:

- id
- name
- createdAt
- updatedAt

#### Club

Represents one club entry for a profile.

Likely fields:

- id
- profileId
- nickname
- clubType
- wedgeLoft
- shotType
- isActive
- distanceFull
- distanceThreeQuarter
- distanceHalf
- distanceQuarter
- putterDistanceLong
- putterDistanceMedium
- putterDistanceShort
- createdAt
- updatedAt

For non-putter clubs, the app uses the swing distance fields. For putters, the app uses the long, medium, and short stroke fields.

### Important Business Rules

- A profile must have a name.
- A club must belong to one profile.
- A club must have a club type.
- A club must have at least one relevant distance value.
- Putters do not use full, three-quarter, half, or quarter swing labels.
- Non-putters do not use long, medium, or short stroke labels.
- Shot type defaults to Normal.
- Wedges can be Normal or Flop.
- Wedges may optionally store a whole-number loft from 30 to 80 degrees.
- Non-wedge, non-putter clubs can be Normal or Punch.
- Putters do not have a shot type.
- Normal clubs display as the club type unless a nickname exists.
- If a wedge has a loft value and no nickname, the displayed base name is the loft plus "° Wedge", such as "54° Wedge".
- Flop or Punch clubs display as "Club type (Flop)" or "Club type (Punch)" unless the club has a nickname. If a nickname exists, the nickname overrides the club type or loft-based name while keeping the shot type in parentheses, such as "Stinger 4 Iron (Punch)".
- Inactive clubs are hidden from the main yardage screen.

### Distance Matching Logic

When the user enters a target yardage:

1. Look at active clubs for the current profile.
2. If the Punch filter is on, only include Punch clubs.
3. Compare the target yardage to every recorded distance value for each included club.
4. Rank matches by absolute difference from the target.
5. Return the two closest matches.
6. If more than two matches tie, prefer clubs whose full-swing distance is closest to the target.
7. If still tied, use a stable sort by club order so the result does not jump around.

### API Structure

For V1, there is no network API.

The app can still use a clean internal service layer, which is just a small set of Swift types that separate app logic from screens:

- Profile service: create, list, select, and update profiles.
- Club service: create, update, delete, activate, deactivate, and list clubs.
- Yardage matcher: calculate closest clubs for a target yardage.

This keeps the app easier to test and safer to change later.

## Recommended Next Phase

Phase 2 should define the project blueprint:

- folder structure
- exact SwiftData models
- enums for club type and shot type
- validation rules
- naming conventions
- coding standards

We should not begin implementation until the Phase 2 blueprint is approved.
