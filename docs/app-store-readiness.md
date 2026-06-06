# Caddie Cat App Store Readiness

## Official References Checked

- Apple App Store Connect app information reference, checked June 5, 2026.
- Apple App Privacy Details page, checked June 5, 2026.
- Apple App Review Guidelines, checked June 5, 2026.
- Apple privacy manifest and required reason API documentation, checked June 5, 2026.
- Apple Human Interface Guidelines for Live Activities, checked June 5, 2026.

## App Store Metadata Draft

### App Name

Caddie Cat

### Subtitle

Track your golf game like never before

### Promotional Text

Track real golf shots, compare swing lengths, and get fast club suggestions while you play.

### Description

Caddie Cat helps golfers learn their real club distances and make faster shot decisions on the course.

Track how far you hit each club across full, 3/4, half, quarter, flop, and low-trajectory shots. Record details like grass, strike quality, and shot direction so your yardages become more useful over time.

Use GPS tracking during a round, manually verify distances on a map, or enter distances yourself. Caddie Cat can suggest the closest shot for a target yardage, compare static values with app-calculated averages, and show common misses across your bag.

Built for golfers who want practical yardage knowledge beyond a basic club-distance chart.

### Keywords

golf,yardage,shot tracker,club distance,caddie,gps,golf swing,golf stats,golf analysis

### Category

Sports

### Support URL Plan

Recommended URL after GitHub Pages is enabled for the repository `docs/` folder:

`https://cepedarod.github.io/golf-yardage-cheatsheet/support.html`

### Marketing URL Decision

Optional for first release. Leave blank unless a polished Caddie Cat landing page exists before submission.

### Privacy Policy URL Plan

Recommended URL after GitHub Pages is enabled for the repository `docs/` folder:

`https://cepedarod.github.io/golf-yardage-cheatsheet/privacy-policy.html`

## Privacy And Data Disclosure Draft

### App Store Connect Privacy Summary

- Tracking: No.
- Data linked to user: No.
- Data used to track user: No.
- Data collected by developer: No, based on the current local-only implementation.

### Local Data Stored On Device

Caddie Cat stores profiles, clubs, static distances, rounds, recorded shots, GPS-derived shot measurements, altitude values, and Live Activity draft selections locally on the device. This data is used for app functionality and is not transmitted to the developer.

### Location Usage

Caddie Cat requests When In Use location access to measure shot start and finish points during a round, estimate shot distance, estimate altitude for distance adjustment, name rounds from nearby course context when available, and provide GPS confidence information. Location-derived shot data is stored locally with recorded shots and rounds.

### Third-Party Services

Caddie Cat uses Apple Maps features for audit maps. If a user updates home base city, Caddie Cat may use Open-Meteo geocoding and elevation services to estimate city location and altitude.

### Notifications

Caddie Cat uses local notifications to remind the user about an active round when the round may be stale, such as after a long duration or when the app detects the user may have left the round area.

### Live Activities

Caddie Cat uses Live Activities and Dynamic Island to keep the active round accessible and to let users prefill shot details while walking between shot locations.

### Privacy Policy Draft

See `docs/privacy-policy.md` for the public-ready privacy policy.

## Permission Copy Review

### Location

Current bundled copy: `Caddie Cat uses your location to measure golf shot distances during a round.`

Recommended final copy: `Caddie Cat uses your location while you play to measure shot distances, estimate altitude, and support active-round reminders.`

### Notifications

System prompt is requested when scheduling round reminders. App Review notes should explain notifications are local reminders for active rounds.

### Live Activities

No custom permission prompt copy is required, but App Review notes should explain Live Activities keep the active round accessible and allow shot-detail prefilling.

## Privacy Manifest

The app and Live Activity extension include `PrivacyInfo.xcprivacy` files declaring:

- No tracking.
- No collected data types.
- App-private `UserDefaults` access with reason `CA92.1`.

## Release Checklist

- Bundle ID: `com.cepedarod.GolfYardageCheatsheet`.
- Bundle ID should remain unchanged for first release to preserve continuity with existing on-device data.
- Display name: `Caddie Cat`.
- Version: `1.0`.
- Build: `1`.
- App icon: present in `AppIcon.appiconset`.
- Device family: iPhone only.
- Minimum iOS: 17.0.
- Signing team: configured in project settings.
- Location permission copy reviewed.
- Privacy policy hosted at a public URL.
- Support URL hosted at a public URL.
- App Store Connect privacy labels entered to match this document.
- App Store screenshots captured with real or realistic data.
- TestFlight build uploaded and installed on physical iPhone.
- Physical iPhone smoke test completed for distance recommendations, round start/end, GPS tracking, audit map, Live Activity, Dynamic Island, shot recording, and data persistence.

## Screenshot Capture Plan

- Distance tab with normal/manual and target recommendation results.
- Distance tab showing active altitude adjustment notice.
- Record Shot form with GPS distance and audit button.
- Audit map with start/end pins and recalculated distance.
- Current Round tab with active round controls.
- Round detail shot list.
- Analysis tab club detail with rough/deep rough modifiers and adopt actions.
- Profile tab with profile settings, strike chart, and rounds.

## App Review Notes Draft

Caddie Cat is a local-first golf shot tracking app. It uses When In Use location during active rounds to capture shot start and finish points, estimate shot distance, and estimate altitude for yardage adjustment. GPS data is stored locally on the device with the user’s shot records and is not sent to the developer.

The app uses local notifications to remind users when an active round may be stale. It uses Live Activities and Dynamic Island to keep the active round accessible and to let users prefill shot details while walking to their ball.

No account is required. The app does not track users across apps or websites.
