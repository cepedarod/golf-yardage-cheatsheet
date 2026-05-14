# V2 Phase 2: Data Model & Migration Blueprint

## Status

Draft for approval. This blueprint defines the model and persistence changes before implementation begins.

## Goals

- Preserve existing V1 data.
- Move from one `shotType` per club entry to one club with multiple distance categories.
- Add recorded shot storage.
- Support Manual vs Real distance values.
- Keep putters visible in Distances and Analysis, but excluded from shot recording.
- Keep Codable file storage unless a later phase proves we need a different persistence backend.

## Model Changes

### Club

V2 `Club` should keep the same identity and profile fields, but replace V1's `shotType` and `swingDistances` as the primary app-facing model.

Recommended V2 fields:

- `id: UUID`
- `profileID: UUID`
- `nickname: String?`
- `clubType: ClubType`
- `wedgeLoft: Int?`
- `isActive: Bool`
- `normalDistances: SwingDistanceSet?`
- `lowTrajectoryDistances: LowTrajectoryDistanceSet?`
- `flopDistances: SwingDistanceSet?`
- `putterDistances: PutterDistanceSet?`
- `createdAt: Date`
- `updatedAt: Date`

Compatibility-only V1 fields should remain decodable during migration:

- `shotType: ShotType?`
- `swingDistances: SwingDistanceSet?`

After migration, new saves should write the V2 fields.

### SwingDistanceSet

Keep for Normal and Flop:

- `full`
- `threeQuarter`
- `half`
- `quarter`

Labels remain:

- `Full`
- `3/4`
- `Half`
- `Quarter`

### LowTrajectoryDistanceSet

Add a new distance set:

- `stinger`
- `punch`
- `softPunch`
- `chip`

Labels:

- `Stinger`
- `Punch`
- `Soft Punch`
- `Chip`

### ShotRecord

Add a new persisted model:

- `id: UUID`
- `profileID: UUID`
- `clubID: UUID`
- `category: ShotCategory`
- `power: ShotPower`
- `distance: Int?`
- `strikeQuality: StrikeQuality`
- `direction: ShotDirection`
- `createdAt: Date`

`distance` is optional. Records without distance count toward total shots, strike distribution, and direction distribution, but not average distance.

### GolfBagData

Add shot records to persisted data:

- `profiles: [GolferProfile]`
- `clubs: [Club]`
- `shotRecords: [ShotRecord]`
- `selectedProfileID: UUID?`
- `schemaVersion: Int`

Recommended schema version:

- V1 files with no `schemaVersion` are treated as version `1`.
- V2 files write `schemaVersion = 2`.

## Enum Changes

### ShotCategory

- `normal`
- `lowTrajectory`
- `flop`

### ShotPower

Use one Codable enum with cases for both category families:

- `full`
- `threeQuarter`
- `half`
- `quarter`
- `stinger`
- `punch`
- `softPunch`
- `chip`

This keeps shot recording and stats simpler than storing separate normal and low-trajectory power enums.

Validation should ensure the power belongs to the selected category.

### StrikeQuality

- `thin`
- `pure`
- `chunk`

### ShotDirection

- `hook`
- `draw`
- `straight`
- `fade`
- `slice`

## Migration Rules

### Exact Merge Key

Use this key to merge V1 Normal, Punch, and Flop entries:

- `profileID`
- `clubType`
- normalized `nickname`
- `wedgeLoft`

Normalize nickname by trimming whitespace and treating blank nicknames as `nil`.

### V1 Normal Entries

For V1 clubs where `shotType` is `.normal` or `nil`:

- Copy `swingDistances` to `normalDistances`.
- Copy `putterDistances` for putters.
- Preserve `id`, `createdAt`, `updatedAt`, and `isActive`.

### V1 Punch Entries

For V1 clubs where `shotType` is `.punch`:

- Convert `swingDistances.full` to `lowTrajectoryDistances.stinger`.
- Convert `swingDistances.threeQuarter` to `lowTrajectoryDistances.punch`.
- Convert `swingDistances.half` to `lowTrajectoryDistances.softPunch`.
- Convert `swingDistances.quarter` to `lowTrajectoryDistances.chip`.
- Merge into an exact base club when possible.
- If there is no exact base club, preserve it as its own club with `lowTrajectoryDistances`.

### V1 Flop Entries

For V1 clubs where `shotType` is `.flop`:

- Copy `swingDistances` to `flopDistances`.
- Merge into an exact base club when possible.
- If there is no exact base club, preserve it as its own club with `flopDistances`.

### Merge Conflicts

If multiple V1 entries map to the same field:

- Prefer the entry with the newest `updatedAt`.
- Preserve the earliest `createdAt` across merged entries.
- Set merged `isActive` to true if any merged entry is active.

## Validation Rules

### Club Validation

- Putters require at least one `putterDistances` value.
- Non-putters require at least one distance across Normal, Low Trajectory, or Flop.
- Flop distances are only allowed for wedges.
- Low Trajectory distances are allowed for wedges and non-wedge non-putters.
- Wedge loft remains optional and must be a whole number from 30 to 80 if present.
- Distance values must be positive whole numbers.

### Shot Record Validation

- Record must belong to an existing profile.
- Record must point to an existing active club.
- Putter clubs are not valid for shot recording.
- `distance`, when present, must be positive.
- `category` must be valid for the club:
  - Normal: every non-putter.
  - Low Trajectory: every non-putter.
  - Flop: wedges only.
- `power` must match the selected category:
  - Normal and Flop: Full, 3/4, Half, Quarter.
  - Low Trajectory: Stinger, Punch, Soft Punch, Chip.

## Manual vs Real Distance Values

### Manual Mode

- Display manual distances.
- If no manual distance exists, display the calculated real value in parentheses.
- Target mode first selects the two closest manual-distance matches.
- After the two primary manual matches are selected, target mode may show one supplemental calculated-real match for a slot with no manual value.
- The supplemental match is shown only when it is closer to the target than both primary manual matches.

### Real Mode

- Calculate average distance from recorded shots where:
  - `strikeQuality == .pure`
  - `distance != nil`
  - club/category/power match the slot.
- If no calculated average exists, display the manual value in parentheses.
- Target mode first selects the two closest calculated-real matches.
- After the two primary real matches are selected, target mode may show one supplemental manual match for a slot with no calculated real value.
- The supplemental match is shown only when it is closer to the target than both primary real matches.

### Supplemental Target Result Rules

- The primary two target results always come from the selected mode.
- A supplemental result never replaces either primary result.
- At most one supplemental result is shown.
- Supplemental values are visually marked in parentheses.
- "Closer" means a strictly smaller absolute difference from the target yardage than both primary results.

## Stats Contracts

### Total Shots

Total recorded shots count all shot records for the club/category, including shots with no distance.

### Average Distance

Average distance uses Pure shots with a recorded distance only.

### Strike Distribution

Percentages use all recorded shots for the selected club/category.

### Direction Distribution

Percentages use all recorded shots for the selected club/category.

## First Implementation Module

The first code module should include:

- New model types and enums.
- Codable migration from V1 to V2.
- Repository methods for shot record persistence.
- Unit tests for migration, validation, and Real average calculation.
- Unit tests for Manual and Real target matching with optional supplemental third results.
- No UI changes beyond whatever is needed to keep existing V1 screens compiling.

## Implementation Assumptions

- Exact V1 merge matching includes normalized nickname, as well as profile, club type, and wedge loft.
- If no exact merge match exists, preserve the V1 entry as its own club with the relevant V2 category filled.
- For duplicate merged distance fields, newest `updatedAt` wins.
- In target mode, fallback values are eligible only as an optional supplemental third result, never as part of the primary two selected-mode results.
