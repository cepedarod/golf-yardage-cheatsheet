# V3 Phase 1: Discovery & GPS Shot Tracking Design Gate

## Source Brief

This phase is based on `Golf app prompt V3.docx`.

## Recommended Git Workflow

- Keep `main` as the stable V2 line.
- Build V3 on `codex/v3-gps-shot-tracking`.
- Commit each approved V3 module separately.
- Keep GPS/location work isolated behind testable service abstractions so simulator tests can use deterministic coordinates.
- Validate GPS behavior on a physical iPhone before treating V3 as stable.
- Merge V3 back to `main` only after simulator tests and a physical phone smoke pass are complete.

## Confirmed V3 Direction

- Keep the same V1/V2 design philosophy: fast, readable, Apple-native, local-first, and built in gated modules.
- Rework shot tracking so recording a shot is faster in real play.
- Add GPS-assisted distance capture:
  - User taps once from the shot location.
  - User taps again where the ball lands.
  - App calculates straight-line distance in yards.
  - App pre-fills the shot distance with the GPS value.
  - User can still edit the distance before/after save.
  - User can abort the GPS flow.
  - User can fall back to manual distance entry.
- Replace the scroll-style club picker in the shot form with tappable active club tiles grouped by:
  - Woods: Driver, woods, hybrids.
  - Irons.
  - Wedges.
- Shot-form club tiles should show compact default club identity:
  - Woods and hybrids: default club number/name, such as `Driver`, `3W`, or `3H`.
  - Irons: default club number, such as `7`.
  - Wedges: wedge role, such as `Pitching`, `Gap`, `Sand`, `Lob`.
  - Wedges with loft: loft value instead, such as `54°`.
- Club nickname and wedge-loft edge cases need explicit tests because the compact shot-form tile label intentionally differs from the full display name used elsewhere.
- Add `Grass Type` to shot records:
  - `Fairway`
  - `Rough`
  - `Deep Rough`
- Existing V2 shot records should migrate with `Grass Type = Fairway`.
- Rework save behavior so the form can auto-submit once the required fields are complete.
- Keep Cancel and Save actions because distance remains optional and users need an explicit escape hatch.
- Add a third bottom tab titled `Profile`.
- V3 Profile tab starts with an `All Shots` view:
  - Shows every shot for the selected profile.
  - Includes all clubs.
  - Sorts newest first.
  - Allows deleting individual shots.
  - Includes a delete-all-shots action.
- Add a fourth bottom tab for the active round. Working title: `Round`.
  - User can Start/End a round.
  - Round is automatically named after the nearest golf course by GPS when possible.
  - Round name remains editable.
  - While a round is active and the app is open, the app keeps high-accuracy GPS updates warm.
  - Round mode tracks total shots recorded during the active round.
  - Tapping the round shot total opens the list of shots recorded during the round.
  - Round shots can be edited or removed from that list.

## GPS Feasibility Assessment

GPS-assisted shot distance is feasible on iPhone, but it should be treated as an assisted estimate rather than a guaranteed exact yardage. The right implementation is to use Core Location, request full-accuracy permission, record the best available start and end `CLLocation`, calculate the distance between the two coordinates, and show the location accuracy to the user when it is meaningful.

Core Location gives each location a `horizontalAccuracy` value, which is the uncertainty radius in meters for that coordinate. The app should use that value instead of assuming a fixed GPS accuracy.

### Practical Accuracy Expectations

The app should design around these bands:

| Reported horizontal accuracy per point | Likely combined distance uncertainty | UX behavior |
| --- | ---: | --- |
| `<= 5m` at both points | About 8 yards typical combined uncertainty; up to about 11 yards conservative | Good enough to auto-fill with a confidence label. |
| `6m-10m` at either point | About 10-16 yards typical combined uncertainty; up to about 22 yards conservative | Usable, but show a caution label and make manual edit prominent. |
| `11m-20m` at either point | Often too noisy for confident club yardage | Offer Retry or Manual Entry before saving. |
| `> 20m`, invalid, stale, or reduced accuracy | Not reliable for shot distance | Do not auto-use; route to manual fallback. |

The combined uncertainty can be estimated from the start and end points. A practical display value can use:

- Typical estimate: `sqrt(startAccuracy^2 + endAccuracy^2)`
- Conservative estimate: `startAccuracy + endAccuracy`

Then convert meters to yards with `meters * 1.09361`.

### Conditions That Can Degrade Results

- User has disabled Precise Location for the app.
- User grants reduced accuracy; Apple documents reduced accuracy as approximate city-scale data, not usable for shot distance.
- Phone is in a pocket, bag, cart, or blocked by body/trees.
- Heavy tree cover, buildings, bad weather, or poor satellite geometry.
- User taps before Core Location has produced a fresh enough reading.
- User marks the ball from somewhere other than the ball position.

### Recommended Product Rule

Use GPS distance only when:

- Location permission is granted.
- Accuracy authorization is full accuracy.
- Both start and end readings have positive `horizontalAccuracy`.
- Both readings meet the active confidence threshold.
- Readings are recent, recommended initial threshold: within `10s` of the tap.
- Each anchor capture window is capped at `2s` so the flow stays usable on-course.

When the threshold is not met, show:

- `Retry GPS`
- `Use Manual Distance`
- `Abort Shot`

## GPS Flow Proposal

### Entry Point

Keep a single `Record Shot` entry point. By default, tapping `Record Shot` starts the GPS measurement flow.

Manual entry is still available, but it is handled in the shot form:

- If GPS mode succeeds, the shot form opens with the calculated distance prefilled.
- The user can edit or clear the auto-calculated distance before saving.
- If the profile's `Shot Tracking Mode` is set to `Manual`, tapping `Record Shot` skips GPS and opens the shot form with optional distance entry.
- If GPS permission is missing, the GPS flow starts the permission request first.
- If permission is denied or reduced, the flow explains that GPS shot measurement needs Precise Location and opens the manual form.

### Measuring Flow

1. When shot tracking has not begun, the button reads `Track Shot (Start)`.
2. User taps `Track Shot (Start)`.
3. The bar shows a loading-style animation for `2s` while start-anchor readings are captured.
4. After the start anchor is measured, the button reads `Track Shot (Finish)`.
5. The user has an obvious option to abort the in-progress shot.
6. User taps `Track Shot (Finish)` where the ball landed.
7. The bar shows the same loading-style animation for `2s` while end-anchor readings are captured.
8. App calculates distance in yards.
9. App opens the shot form with prefilled shot distance and GPS confidence display.
10. User completes remaining fields or edits distance.

### Abort / Fallback

Always keep:

- `Cancel`
- `Manual Entry`
- `Retry Location`
- `Abort Shot`

The flow should not trap a user on-course while location stabilizes.

## Continuous GPS During A Round

Continuous GPS should be used to improve endpoint quality, not to calculate the shot path. Golfers will often walk to a cart, move around other players, or take a non-direct route to the ball, so shot distance must still be the straight-line distance between a stabilized start anchor and a stabilized end anchor.

Continuous GPS helps because it:

- Warms up Core Location before the user needs to mark the ball.
- Gives the app multiple candidate readings to choose from.
- Lets the app prefer the freshest, lowest-uncertainty point near each anchor tap.
- Lets the app detect unstable readings and steer the user to manual fallback.

Anchor capture rule:

- On `Start Shot`, collect readings for up to `2s`, then pick the best current anchor.
- On `Mark Ball`, collect readings for up to `2s`, then pick the best current anchor.
- Prefer a fresh reading with the lowest `horizontalAccuracy`.
- If multiple readings are close in quality, use a small stabilized median/weighted point from the best readings.
- Do not use the walking path length as shot distance.

## GPS Confidence Display

Auto-filled GPS distance should visibly communicate confidence. Recommended display: color the auto-entered distance and include a small confidence label such as `GPS +/- 5 yds`.

Confidence thresholds:

| Confidence | Estimated distance uncertainty | Display |
| --- | ---: | --- |
| Green | `<= 3 yds` | High confidence; auto-fill normally. |
| Yellow | `4-7 yds` | Usable; make edit affordance clear. |
| Orange | `8-9 yds` | Caution; encourage audit or manual edit. |
| Red | `>= 10 yds` | Low confidence; prefer audit or manual fallback. |

## Current Round Tab Direction

Add a fourth bottom tab, likely titled `Round` to keep the tab bar compact. The user-facing title inside the screen can be `Current Round`.

Initial Round scope:

- Start Round / End Round.
- Keep high-accuracy GPS readings active while a round is active and the app is foregrounded.
- Use active-round GPS readings to make shot anchor capture faster and more accurate.
- Track shots recorded during the current round.
- Show a tappable total-shots card.
- Tapping the total-shots card opens the round shot list.
- Round shot list supports edit and delete.
- If the user taps `Track Shot` before starting a round, prompt them to start a round.
- If they decline to start a round, let them continue with manual/non-round shot tracking.
- If they accept, start the round and continue into the shot tracking flow.
- If an active round is in progress, show an `Abort Round` action.
- `Abort Round` ends the active round and discards the round record/data for it.
- Shots recorded during an aborted round should not remain linked to that discarded round.

### Round Completion Reminders

The app should help the user avoid leaving a round running accidentally.

Trigger a local notification asking whether the user wants to finish the round when:

- `8 hours` have passed since the round started.
- The user exits the cached/expected round area, if a round area is available.

Recommended behavior:

- Notification wording: `Still playing? Finish your current round?`
- Notification actions should include `Finish Round` and `Keep Playing`.
- If the user chooses `Finish Round` from the notification, end the round immediately and record its `endedAt` time.
- If the user taps the notification body instead of an action, open the `Round` tab.
- The Round tab still offers `Finish Round` and `Keep Playing`.
- If location permission does not allow background/geofence behavior, rely on the 8-hour reminder and foreground checks.
- If map area caching is limited to opportunistic MapKit cache, treat "exits cached area" as "exits the expected round area" instead of pretending the app can inspect Apple map tile cache.

Open technical note:

- iOS can schedule an 8-hour local notification when a round starts.
- iOS notification categories/actions can support a direct `Finish Round` action.
- Area-exit reminders should use a geofence/region around the round start or selected course area rather than trying to detect whether Apple map tiles are cached.

Persisted round model:

- Add a persisted `Round` model in V3:
  - `id`
  - `profileID`
  - `name`
  - `startedAt`
  - `endedAt`
  - `courseName`
  - `nameWasEdited`
- Add `ShotRecord.roundID: UUID?`.
- The Profile tab should count completed rounds only.
- A round should appear in the Profile > Rounds list when the user ends it.
- Active rounds live in the Round tab until ended.
- Aborted rounds should be discarded and should not appear in Profile > Rounds.
- V2 shot records decode with `roundID = nil`.

### Round Naming

When a round starts, use GPS to look up the nearest golf course and prefill the round name.

Recommended behavior:

- Use the round start coordinate.
- Search nearby points of interest for golf courses.
- Choose the closest credible golf result.
- If a golf course is found, name the round after that course.
- If no course is found or the app is being tested away from a course, use a fallback such as `Round May 18`.
- Let the user edit the round name at any time.
- If the user edits the name, do not overwrite it with a later GPS/course lookup.

Technical note:

- MapKit supports local point-of-interest search and includes a golf POI category. This likely requires network access and is best-effort, so naming must stay editable.

### Map Caching Caveat

Apple MapKit is not a good fit for deliberate offline satellite pre-caching of an entire course. Apple Maps terms say Map Data may not be cached, pre-fetched, or stored except on a temporary and limited basis as necessary for permitted use/performance, and then it must be deleted. That means the app should not bulk-download or persist Apple satellite tiles for a whole golf course.

Practical options:

1. **V3 practical path:** Use live MapKit satellite/imagery for audit when connectivity is available. Let the system's temporary cache help opportunistically, but do not promise offline satellite audit.
2. **Testing fallback:** When not at a golf course, use the user's current area for round/GPS testing and make the audit map region based on the shot anchors rather than a known course boundary.
3. **Future offline path:** If true offline satellite audit becomes critical, evaluate a third-party map SDK/provider with explicit offline tile licensing. This is likely heavier than V3 needs.

### Course Area Selection

If we are not using true offline satellite caching, we can still choose intelligent regions for audit display:

- Pre-round: use the current GPS location and a generous visible map radius to orient the user.
- Per-shot audit: crop the map to include start/end anchors plus a reasonable margin.
- If course data is added later, use course boundary/hole geometry instead of a fixed large radius.
- For V3 testing away from a course, the same current-location and shot-anchor region logic works.

## Data Model Direction

### ShotRecord

Add `grassType` and optional GPS measurement metadata.

Recommended V3 shape:

- `grassType: GrassType`
- `distanceSource: ShotDistanceSource`
- `gpsMeasurement: ShotGPSMeasurement?`
- `roundID: UUID?`, if the Round module is included in V3 data model work.

Recommended enums/structs:

- `GrassType`: `fairway`, `rough`, `deepRough`
- `ShotDistanceSource`: `manual`, `gps`, `editedGPS`
- `ShotGPSMeasurement`
  - `measuredDistanceYards`
  - `estimatedUncertaintyYards`
  - `confidence`
  - `startHorizontalAccuracyMeters`
  - `endHorizontalAccuracyMeters`
  - `capturedAt`

### Profile Preferences

Add lightweight profile-level preferences:

- `shotTrackingMode: ShotTrackingMode`

Recommended enum:

- `ShotTrackingMode`: `gps`, `manual`

Migration rule:

- Existing profiles decode with `shotTrackingMode = .gps`.

Privacy recommendation: do not persist raw latitude/longitude in V3 unless we decide saved/post-save audit requires it. The app can use coordinates in memory to calculate distance, then store distance and accuracy metadata only. This keeps the app local-first while avoiding unnecessary sensitive location history.

### Round

Add a persisted `Round` model:

- `id`
- `profileID`
- `name`
- `startedAt`
- `endedAt`
- `courseName`
- `nameWasEdited`

Round rules:

- A started round can exist before it appears in Profile history.
- A round appears in Profile > Rounds only after `endedAt` is set.
- Ending a round should finalize its `endedAt` timestamp and keep its recorded shots linked by `roundID`.
- Deleting a round should not automatically delete its shots unless we later add a separate destructive option. In V3, deleting a round should unlink those shots from the round or remove only the round history entry.
- Number of Rounds counts completed rounds for the selected profile.

### Migration

- Bump data schema from V2 to V3.
- Existing shot records decode with:
  - `grassType = .fairway`
  - `distanceSource = .manual`
  - `gpsMeasurement = nil`
  - `roundID = nil`, if round IDs are added.
- All existing V2 manual/real distance behavior remains intact.

### Repository

Add:

- `shotRecords(for profileID:)` already exists and can power Profile > All Shots.
- `deleteAllShotRecords(for profileID:)` for Profile > All Shots delete-all.
- `shotRecords(for profileID:, roundID:)` if the Round module adds persisted rounds.
- `startRound(profileID:, name:, courseName:, startedAt:)`
- `endRound(id:, endedAt:)`
- `updateRoundName(id:, name:)`
- `rounds(for profileID:, includeActive:)`
- `deleteRound(id:)`
- Keep individual `deleteShotRecord(id:)`.

## Shot Form Direction

### Club Picker

Use tile sections instead of a wheel/scroll picker:

- Woods
- Irons
- Wedges

Recommended tile content:

- Large compact identity: `Driver`, `3W`, `3H`, `7`, `54°`, `Sand`
- Optional smaller subtitle only if needed for ambiguity, such as nickname or full club type.

Test cases:

- Nicknamed driver still records the correct club while tile reads `Driver` or `D`.
- Nicknamed wedge with loft shows `54°` and saves against the correct full club display name.
- Multiple wedges of the same role but different loft remain distinguishable.
- Multiple clubs with same compact tile label need a disambiguation subtitle.

### Required Fields And Auto-Submit

The prompt asks for auto-submit once all fields are filled, while keeping Cancel/Save because some fields are optional. The key design risk is that V2 has several default selections; if every field has a default, the form can save before the user intentionally confirms the shot.

Recommended rule:

- Distance remains optional.
- Club is required.
- Shot category/power is required.
- Strike quality is required.
- Direction is required.
- Grass type is required, defaulting visually to `Fairway` but requiring either confirmation or first user interaction before auto-submit.

Recommended UX:

- Present fields as large tap groups.
- Start with the measured/manual distance already filled when available.
- Use helpful defaults, but mark the form as auto-submittable only after the user has made or confirmed required choices.
- When auto-submit happens, show a brief saved confirmation with haptic feedback.
- Keep `Save` visible so the user can submit when distance is blank or when auto-submit does not trigger.

Resolved decision: `Fairway`, `Pure`, and `Straight` can be visible defaults, but auto-submit should still require user confirmation or interaction to avoid accidental records.

## Profile Tab Direction

Add a third bottom tab:

- `Distances`
- `Analysis`
- `Profile`

Initial Profile tab scope:

- Header with selected profile name and Switch Profile action.
- `Shot Tracking Mode` selector.
  - Defaults to `GPS`.
  - `GPS` uses the `Track Shot (Start)` / `Track Shot (Finish)` measurement flow.
  - `Manual` disables the GPS measurement workflow and opens the shot form directly.
  - In Manual mode, distance remains optional and editable.
- Summary box for `All Shots`.
- Summary box for `Number of Rounds`.
- Tapping `All Shots` opens the all-shots list.
- Tapping `Number of Rounds` opens the rounds list.
- All Shots list sorted newest first.
- Rounds list sorted newest first.
- Tapping a round opens a round detail screen.
- Row fields:
  - Date/time
  - Club display name
  - Shot label
  - Grass type
  - Strike icon
  - Direction icon
  - Distance, using `- yds` when blank
- Swipe delete individual shot.
- Destructive `Delete All Shots` action with confirmation.
- Rounds can be deleted from the rounds list.

Initial round detail scope:

- Round name.
- Start/end date.
- Total tracked shots.
- Keep the screen intentionally simple in V3 so it can expand later.

## Proposed V3 Module Gates

1. **V3 Discovery & GPS Design Gate**
   - Capture GPS feasibility and product rules.
   - Confirm auto-submit behavior.
   - Confirm raw-coordinate persistence decision.

2. **V3 Data Model & Migration**
   - Add `GrassType`.
   - Add distance source / GPS metadata.
   - Migrate existing shots to Fairway/manual.
   - Add repository delete-all shots.
   - Unit tests only.

3. **Profile Tab & All Shots**
   - Add bottom Profile tab.
   - Add Shot Tracking Mode selector.
   - Add All Shots list.
   - Add individual delete and delete-all.
   - Add Number of Rounds summary box.
   - Add completed rounds list.
   - Add simple round detail screen with total tracked shots.
   - Add round delete.
   - UI tests for newest-first sorting and destructive confirmation.

4. **Fast Shot Form Redesign**
   - Replace club picker with grouped active club tiles.
   - Add Grass Type.
   - Preserve manual distance entry and editability.
   - Add auto-submit behavior requiring user confirmation/interaction before auto-submit.
   - Add tests for club labels, wedge lofts, nicknames, and same-label disambiguation.

5. **GPS Measurement Service**
   - Add Core Location service abstraction.
   - Add permission and full/reduced accuracy handling.
   - Add deterministic test doubles.
   - Add unit tests for distance conversion and accuracy gating.
   - Add a 2-second anchor capture window.

6. **GPS Measurement UI**
   - Add `Track Shot (Start)` / `Track Shot (Finish)` flow.
   - Add 2-second loading animation during each anchor capture.
   - Add accuracy status, retry, manual fallback, and abort.
   - Prefill shot form with measured distance.
   - Add simulator UI tests with fake locations where feasible.

7. **Current Round**
   - Add Round tab.
   - Add start/end round state.
   - Add Abort Round, which discards the active round.
   - Add nearest-course naming with editable round name.
   - Keep GPS warm while round is active and app is open.
   - Prompt to start a round if the user tracks a shot with no active round.
   - Add stale-round notifications with `Finish Round` and `Keep Playing` actions.
   - Add round shot count and round shot list.
   - Support edit/delete from the round shot list.

8. **Pre-Save GPS Audit Map**
   - Add Audit button for GPS-filled distance.
   - Show satellite/imagery map around start/end anchors when connectivity is available.
   - Show start/end pins, line, confidence circles, and recalculated distance.
   - Orient the audit map so the origin/start anchor appears toward the bottom of the screen and the end anchor appears toward the top.
   - Let user drag either anchor before saving.
   - Keep raw coordinates in memory only unless post-save audit is later approved.

9. **V3 Validation & Physical Beta Pass**
   - Unit tests.
   - Simulator UI suite.
   - Physical iPhone install.
   - Physical GPS smoke pass in open-sky conditions.

## Future Features To Track

Not in V3 implementation unless later approved:

- Clicking a filtered shot result to show historical breakdown data.
- Filter stats by date range.
- Unified visualization that intelligently incorporates Real and Manual data.
- Show miss summary in Profile.
- Carry vs total distance.
- Bulk shot data import.
- Button to send user to a copy of a Google Sheet.
- Import using a Google Sheet link.
- Profile tab expansion.
- Most used clubs.
- Most common misses.
- Default distance mode: Manual vs Calculated.

## Technical Sources

- Apple Developer Documentation: `CLLocation.horizontalAccuracy` describes the reported horizontal uncertainty value for a location: https://developer.apple.com/documentation/corelocation/cllocation/horizontalaccuracy
- Apple Developer Documentation: `CLLocationAccuracy` and desired accuracy constants, including nearest-ten-meters and best-for-navigation: https://developer.apple.com/documentation/corelocation/cllocationaccuracy
- Apple Developer Documentation: `CLLocationManager.desiredAccuracy` notes that requested accuracy is not guaranteed and full-accuracy authorization matters: https://developer.apple.com/documentation/CoreLocation/CLLocationManager/desiredAccuracy
- Apple Developer Documentation: `kCLLocationAccuracyReduced` describes reduced accuracy as approximate and usually far too coarse for shot distance: https://developer.apple.com/documentation/corelocation/kcllocationaccuracyreduced
- Apple Developer Documentation: MapKit local search can search points of interest near a coordinate: https://developer.apple.com/documentation/mapkit/mklocalsearch
- Apple Developer Documentation: local notifications can use action buttons through notification categories/actions: https://developer.apple.com/documentation/usernotifications/unnotificationaction
- Apple Developer Program License Agreement, Attachment 6, limits caching, pre-fetching, and storing Apple Maps Map Data except on a temporary and limited basis: https://developer.apple.com/support/terms/apple-developer-program-license-agreement/

## Resolved Product Decisions

- Store measured distance plus GPS accuracy/confidence metadata, not raw start/end coordinates.
- Use visible defaults for `Fairway`, `Pure`, and `Straight`, but require user confirmation/interaction before auto-submit to avoid accidental records.
- Keep one `Record Shot` entry point and default it to the GPS flow when profile shot tracking mode is `GPS`.
- Add profile-level `Shot Tracking Mode` with `GPS` as the default and `Manual` as an opt-out.
- When deleting a completed round, unlink its shots from that round and keep shot data unless the user deletes shots separately.

## Open Questions For Approval

No open discovery questions.
