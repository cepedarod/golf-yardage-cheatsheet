# V2 Phase 1: Discovery & Build Plan

## Source Brief

This phase is based on `Golf app prompt V2.docx`.

## Recommended Git Workflow

- Keep `main` as the stable V1 line.
- Build V2 on `codex/v2-beta`.
- Commit each approved V2 module separately.
- Keep simulator and physical-device validation checkpoints after each risky module.
- Merge V2 back to `main` only after the beta branch passes simulator tests and a physical phone smoke pass.

## Confirmed V2 Direction

- Keep the same V1 design philosophy: fast, readable, Apple-native, local-first, and built in gated modules.
- Rename the Punch category to `Low Trajectory`.
- Low Trajectory distances use four labels:
  - `Stinger`
  - `Punch`
  - `Soft Punch`
  - `Chip`
- Clubs should store Normal, Low Trajectory, and when eligible Flop distances under one club instead of as separate club entries.
- Flop distances should display as a second row for wedge clubs when present.
- Low Trajectory distances should display as their own row when present.
- Add/Edit Club should keep one form, with a shot-category switcher that does not clear values from other categories.
- Add shot tracking through a `Record Shot` action from the Distance page.
- Shot recording should exclude putter support in V2.
- Shot recording should capture club, distance, shot category/power, strike quality, and shot direction.
- Distance page should support Manual vs Real Values.
- Real Values should supplement missing real values with manual values and visually mark supplemented manual values.
- Add a bottom navigation menu with `Distances` and `Analysis`.
- Analysis should list active clubs first and inactive clubs afterward.
- Analysis should show per-club stats by Normal, Low Trajectory, and Flop where applicable.
- Filtered target results should display club type first, with nickname muted in parentheses.

## Proposed Data Model Direction

### Club

Keep `Club` as the main bag entity, but replace V1's single `shotType` plus `swingDistances` shape with nested distance groups:

- `normalDistances: SwingDistanceSet`
- `lowTrajectoryDistances: LowTrajectoryDistanceSet`
- `flopDistances: SwingDistanceSet`
- `putterDistances: PutterDistanceSet`

For compatibility, the V2 decoder should migrate existing V1 data:

- V1 Normal club entries become `normalDistances`.
- V1 Punch club entries become `lowTrajectoryDistances`.
- V1 Flop wedge entries become `flopDistances`.
- V1 putter entries keep `putterDistances`.

### Shot Records

Add a new `ShotRecord` model:

- `id`
- `profileID`
- `clubID`
- `category`
- `power`
- `distance`
- `strikeQuality`
- `direction`
- `createdAt`

Recommended enums:

- `ShotCategory`: `normal`, `lowTrajectory`, `flop`
- `NormalShotPower`: `full`, `threeQuarter`, `half`, `quarter`
- `LowTrajectoryShotPower`: `stinger`, `punch`, `softPunch`, `chip`
- `StrikeQuality`: `thin`, `pure`, `chunk`
- `ShotDirection`: `hook`, `draw`, `straight`, `fade`, `slice`

### Recorded Stats

Shot records are the source of truth. The app should calculate per-club summaries from records, and may cache summary values later if performance ever becomes a real issue.

For V2, calculated stats should include:

- Total recorded shots.
- Average recorded distance by category and power.
- Strike-quality percentages.
- Direction percentages.

## Proposed Screens

### Distances

The current Distance dashboard remains the primary fast-use screen.

Additions:

- Bottom `Record Shot` button.
- Manual / Real segmented control.
- Category filter should use `All` and `Low Trajectory`.
- Target mode should use the selected value source.
- Target mode should exclude Low Trajectory values when filter is `All`, and include only Low Trajectory values when filter is `Low Trajectory`.
- Club rows should support up to three distance rows:
  - Normal
  - Flop, wedges only and only when entered
  - Low Trajectory, only when entered

### Add/Edit Club

Use one form with category switching:

- Normal distances for all non-putters.
- Low Trajectory distances for all non-putters.
- Flop distances for wedges.
- Putter distances remain a separate putter-only section.

Switching categories must preserve values already entered in other categories.

### Record Shot

The form should include:

- Active club picker, excluding putters.
- Distance input with number pad.
- Two-row shot power picker:
  - Normal row: Full, 3/4, Half, Quarter
  - Low Trajectory row: Stinger, Punch, Soft Punch, Chip
- Third Flop row for wedge clubs.
- Strike quality picker: Thin, Pure, Chunk.
- Direction picker with arrow icons for hook, draw, straight, fade, and slice.
- Obvious cancel/abort action.

### Analysis

Add a second bottom tab:

- Club list with active clubs first, inactive clubs after.
- Club detail screen with category selector.
- Manual vs average recorded distance by power.
- Strike quality distribution visualization.
- Direction distribution visualization.

The analysis visualizations should be treated as a design gate before implementation.

## Proposed Module Gates

1. **V2 Data Model & Migration Blueprint**
   - Finalize model names, migrations, and Codable compatibility.
   - No UI changes.

2. **Club Distance Categories**
   - Add Normal / Low Trajectory / Flop distance storage.
   - Rework Add/Edit Club.
   - Rework Distance rows.
   - Preserve V1 data.

3. **Distance Filtering & Real/Manual Values**
   - Rename Punch filter to Low Trajectory.
   - Add Manual / Real selector.
   - Update target matching.
   - Add filtered-result display naming.

4. **Shot Recording**
   - Add `ShotRecord`.
   - Add Record Shot form.
   - Persist shot records locally.
   - Add basic stats calculations.

5. **Analysis Navigation & Club Stats**
   - Add bottom tab navigation.
   - Add Analysis list and club detail screen.
   - Show calculated stats with simple, readable placeholders.

6. **Analysis Visual Design Gate**
   - Present visual options for direction and strike distributions.
   - Present optional manual-to-average conversion UI options.
   - Implement the selected visuals after approval.

7. **V2 Validation & Physical Beta Pass**
   - Unit tests.
   - Simulator UI smoke tests.
   - Physical iPhone install and smoke test.

## Open Questions For Approval

1. Existing V1 Punch and Flop entries: should the V2 migration automatically merge them into matching base clubs when club type, wedge loft, and nickname line up, or should we keep them as separate clubs until the user edits them?
2. For Real Values, should average distance include every recorded shot, or only `Pure` shots?
3. For Manual fallback in Real mode, do you prefer an asterisk such as `145*` with a small note, or parentheses such as `(145)`?
4. Should putters remain visible in Distances and Analysis while only being excluded from shot recording?
5. Should Low Trajectory be available for wedges in addition to Normal and Flop?
6. In target mode, should Manual vs Real affect the target matching math, not just the displayed values?

