# V4 Phase 1: Discovery & App Store Readiness Gate

## Source Brief

This phase is based on `Golf app prompt V4.docx` plus follow-up answers from June 3, 2026.

## Recommended Git Workflow

- Use `codex/v4-app-store-ready` for V4 work.
- Keep V3.1 cleanup checkpointed before V4 implementation begins.
- Commit each approved V4 module separately.
- Keep app-store metadata, screenshots, privacy copy, and code changes grouped into readable commits.
- Do not merge V4 back to `main` until simulator QA, physical phone smoke testing, and App Store readiness review are complete.

## Confirmed V4 Direction

V4 is the final major feature volley before preparing Caddie Cat for App Store distribution. It should preserve the existing design philosophy:

- Fast on-course use.
- Apple-native UI.
- Local-first app data.
- Readability over dense editing controls.
- Gated modules with screenshots or phone testing after major UI changes.

## V4 Feature Scope

### Round Shot List

- When viewing a completed round, tapping `Total Tracked Shots` should open a list of shots for that round.
- The list should behave like the existing shot-list flows:
  - Show all shots for that round.
  - Sort chronologically in a sensible review order.
  - Allow users to edit or delete shots when supported by the shared shot-list model.

### Rough and Deep Rough Distance Modifiers

- Club analysis should show distance loss for `Rough` and `Deep Rough` compared with `Fairway`.
- Comparisons must only be made between like-for-like shot shapes:
  - Full vs Full.
  - 3/4 vs 3/4.
  - Half vs Half.
  - Quarter vs Quarter.
  - Matching low-trajectory types where applicable.
- The displayed value should be the average reduction across all matching shot types that have both comparison points.
- Do not show a modifier, or show a blank/placeholder state, if either comparison side is missing.
- QA should include mixed data where only some swing lengths have valid fairway/rough pairs.

### Altitude Tracking and Normalization

- Every recorded shot should store altitude.
- New GPS-tracked shots should prefer the start-anchor GPS altitude.
- If using the GPS altitude per shot creates instability, use the active round altitude as the fallback.
- Prior shots without altitude should migrate to Chicago altitude.
- Chicago baseline altitude: `594 ft`.

Profiles gain a `Home Base` city:

- User enters city only.
- The app records an altitude for that city when the city is added or changed.
- Existing profiles without a home base should default to `Chicago, IL` and `594 ft`.
- Technical design note: a city can be geocoded to a coordinate with Apple location services, but altitude lookup for an arbitrary city is not directly guaranteed by Core Location. V4 should prefer an Apple-native/local approach where feasible, and avoid adding a network elevation API unless explicitly approved.

Profile altitude preference:

- Add profile setting: `Shot Calculations`
  - `Adjust for Altitude`
  - `Ignore Altitude`
- If `Ignore Altitude`, averages and distance calculations remain as they are today.
- If `Adjust for Altitude`, shots recorded more than `1000 ft` above or below home-base altitude should be normalized back to home-base altitude before contributing to real-distance averages.
- Toggling this setting should recalculate displayed distances.

Round altitude behavior:

- When starting a round, if the profile is set to `Adjust for Altitude`, record current altitude.
- If current round altitude differs from home-base altitude by more than `1000 ft`, notify/prompt the user that altitude is expected to affect shot distance.
- Prompt choices:
  - `Account for Altitude`
  - `Ignore Altitude`
- During an active round, show a Distance Tracking toggle under Round when profile altitude calculations are enabled:
  - `Account for Altitude`
  - `Ignore Altitude`
- This round setting is modifiable during the round.
- If `Ignore Altitude`, Distance tab values show normalized home-base values.
- If `Account for Altitude`, Distance tab values show altitude-adjusted expected values for the current round.
- The Distance tab must make it obvious when altitude-adjusted values are being shown.

Altitude formula:

- `altitudeDeltaFeet = currentRoundAltitudeFeet - homeBaseAltitudeFeet`
- Only apply when `abs(altitudeDeltaFeet) > 1000`.
- `distanceModifier = 1 + (altitudeDeltaFeet * 0.00001)`
- Example: home base `0 ft`, current round `5000 ft`, modifier is `1.05`.
- A 150-yard home-base shot would display as `158 yds` after whole-number rounding.
- Negative deltas reduce distance.

### Profile Strike Quality Chart

- Profile tab should show a stacked bar chart with one bar per club.
- Bar stacks:
  - `Pure`: green.
  - `Thin + Chunk`: red.
- The chart should help users quickly see which clubs are producing the cleanest strike patterns.

### Adopt Real Distances Into Manual Distances

- On club analysis, add an adopt-distance action for each swing distance.
- The action copies the current real value into the corresponding manual value.
- Each swing distance should have a separate button/action.
- It should not overwrite manual values for unrelated swing distances.
- Empty real values should not offer an adopt action.

### Club Analysis Navigation

- Add an easy way to move between club analysis screens.
- Preferred implementation: swipe right/left to previous/next active club.
- Keep a clear fallback affordance if swipe discoverability is weak.

## V3.1 Fixes Included In V4

- Lock Screen action card can get stuck on club selection after reinstall.
- Tapping the Lock Screen action currently opens the Round tab; it should open the Distance tab.

## App Store Readiness Scope

V4 should include mandatory App Store readiness work, including:

- App metadata draft:
  - App name.
  - Subtitle.
  - Promotional text if useful.
  - Description.
  - Keywords.
  - Support URL plan.
  - Marketing URL decision.
- Privacy and data disclosures:
  - Local app data.
  - Location usage.
  - No account requirement.
  - Any tracking/data collection claims required by App Store Connect.
- Privacy policy text or hosted policy plan.
- Permission copy review:
  - Location.
  - Notifications.
  - Live Activities where applicable.
- Release checklist:
  - Bundle ID and signing.
  - App icon.
  - Launch behavior.
  - Physical iPhone smoke test.
  - Screenshot capture plan.
  - TestFlight readiness.
  - App Review notes for GPS/Live Activity behavior.

Current App Store requirements should be verified against Apple’s official documentation before final submission prep.

## Future Backlog To Track, Not Implement In V4

- Tapping a shot recommendation in filter mode opens historical breakdown data for that shot.
- Date-range stat filtering.
- Unified data visualization that intelligently combines real and manual values.
- Miss summary in Profile.
- Carry vs total.
- Bulk shot data import.
- Button to export/copy to a Google Sheet.
- Import from a Google Sheet link.

## Proposed Module Sequence

1. V3.1 fix pass:
   - Lock Screen action card reliability.
   - Lock Screen action deep links to Distance tab.
2. Round shot-list expansion:
   - Completed-round shot list from `Total Tracked Shots`.
3. Data model altitude migration:
   - Shot altitude.
   - Profile home base.
   - Round altitude.
   - Default/migration values.
4. Altitude services and settings:
   - Home-base city entry.
   - Altitude calculation policy.
   - Profile and round toggles.
5. Altitude-adjusted calculations:
   - Normalize historical shot averages.
   - Adjust Distance tab during active high-altitude/low-altitude rounds.
6. Club analysis improvements:
   - Rough/deep rough modifiers.
   - Adopt real values into manual distances.
   - Swipe between clubs.
7. Profile strike chart:
   - Stacked bars by club and strike quality.
8. App Store readiness package:
   - Metadata.
   - Privacy copy.
   - Release checklist.
   - Screenshot capture plan.
9. Full V4 QA:
   - Simulator build/test.
   - Physical phone smoke pass.
   - Targeted altitude and rough/deep rough calculation tests.

## QA Focus

- Existing local data migration from V3.1 to V4.
- Existing shots with missing altitude.
- Profiles with and without home-base city.
- Altitude deltas below, equal to, and above `1000 ft`.
- Positive and negative altitude deltas.
- Distance tab clearly communicating altitude adjustment state.
- Rough/deep rough modifier calculations with partial data.
- Adopt-distance actions only touching the intended manual field.
- Lock Screen action card after fresh install/reinstall.
- App Store permission copy and privacy claims matching actual behavior.
