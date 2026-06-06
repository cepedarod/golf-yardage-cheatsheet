# Caddie Cat App Store Handoff

This is the handoff checklist for uploading Caddie Cat to App Store Connect.

## Keep This Bundle ID

Use the existing bundle ID:

`com.cepedarod.GolfYardageCheatsheet`

Do not change the bundle ID for the first App Store release. The current on-device data is tied to this bundle ID, and changing it would cause iOS to treat the App Store build as a different app.

## App Identity

- App name: `Caddie Cat`
- Bundle ID: `com.cepedarod.GolfYardageCheatsheet`
- Primary category: `Sports`
- Age rating target: All ages
- Current app icon: use the icon already included in the project

## App Store Metadata

### Subtitle

Track your golf game like never before

### Description

Caddie Cat helps golfers learn their real club distances and make faster shot decisions on the course.

Track how far you hit each club across full, 3/4, half, quarter, flop, and low-trajectory shots. Record details like grass, strike quality, and shot direction so your yardages become more useful over time.

Use GPS tracking during a round, manually verify distances on a map, or enter distances yourself. Caddie Cat can suggest the closest shot for a target yardage, compare static values with app-calculated averages, and show common misses across your bag.

Built for golfers who want practical yardage knowledge beyond a basic club-distance chart.

### Keywords

golf,yardage,shot tracker,club distance,caddie,gps,golf swing,golf stats,golf analysis

### Promotional Text

Track real golf shots, compare swing lengths, and get fast club suggestions while you play.

## Public URLs

Recommended GitHub Pages URLs after publishing this repository's `docs/` folder:

- Privacy policy: `https://cepedarod.github.io/golf-yardage-cheatsheet/privacy-policy.html`
- Support URL: `https://cepedarod.github.io/golf-yardage-cheatsheet/support.html`
- Support email: `cepedarod@gmail.com`

If GitHub Pages is not enabled yet, set Pages source to the repository's `docs/` folder on the release branch or default branch.

## Privacy Nutrition Label Draft

Use this as the App Store Connect privacy questionnaire draft. The uploader should verify each answer in App Store Connect before submission.

- Tracking: No
- Data used to track the user: No
- Data linked to the user: No
- Data collected by the developer: No, based on the current local-only implementation
- Contact info: Not collected
- Health and fitness: Not collected
- Financial info: Not collected
- Location: Used for app functionality on device; not collected by the developer
- User content: Not collected by the developer
- Identifiers: Not collected
- Usage data: Not collected
- Diagnostics: Not collected
- Other data: Not collected

Privacy notes:

- Shot, round, club, profile, GPS measurement, and altitude data are stored locally on the iPhone.
- The app uses Apple Maps features for audit maps.
- Home base city lookup may use Open-Meteo geocoding and elevation services.
- The app does not have accounts, ads, third-party tracking, or analytics.

## App Review Notes

Caddie Cat is a local-first golf shot tracking app. It uses When In Use location during active rounds to capture shot start and finish points, estimate shot distance, estimate altitude for yardage adjustment, and support distance audit maps. GPS-derived shot data is stored locally on the device with the user's shot records and is not sent to the developer.

The app uses local notifications to remind users when an active round may be stale. It uses Live Activities and Dynamic Island to keep the active round accessible and to let users prefill shot details while walking to their ball.

No account is required. The app does not track users across apps or websites.

## Upload Steps For Developer Account Owner

1. Clone or download the repository.
2. Open `GolfYardageCheatsheet.xcodeproj` in Xcode.
3. Select the developer team for both the main app target and Live Activity extension.
4. Register or assign the bundle ID `com.cepedarod.GolfYardageCheatsheet`.
5. Confirm signing works for the main app and Live Activity extension.
6. Archive the app from Xcode.
7. Upload the archive to App Store Connect.
8. Create the App Store Connect app record if needed.
9. Enter the metadata, privacy details, age rating, support URL, and privacy policy URL.
10. Add App Store screenshots.
11. Add Rodrigo as a TestFlight tester if possible.
12. Run a TestFlight smoke test on the uploaded build.
13. Submit for App Review.

## TestFlight Smoke Test

Before App Review, verify the TestFlight build can:

- Launch without developer mode.
- Show existing or newly created profiles.
- Add and edit a club.
- Search a target distance.
- Start and finish a round.
- Track a GPS shot.
- Audit GPS distance on the map.
- Save a shot.
- Show recorded shots in analysis.
- Show Live Activity and Dynamic Island entry points during an active round.
- Persist data after closing and reopening the app.

## Screenshots To Prepare

Prepared screenshots are in `docs/app-store-screenshots/`.

- Format: PNG
- Size: 1320 x 2868
- Slot: large iPhone portrait screenshot set

Recommended upload order:

1. `01-distance-target-recommendations.png`
2. `02-distance-bag-yardages.png`
3. `03-current-round.png`
4. `04-record-shot-gps.png`
5. `05-audit-distance-map.png`
6. `06-analysis-overall.png`
7. `07-analysis-club-list.png`
8. `08-club-analysis-detail.png`
9. `09-recorded-shots.png`
10. `10-profile-settings.png`
