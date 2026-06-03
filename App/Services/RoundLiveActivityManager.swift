import ActivityKit
import CaddieCatLiveActivityShared
import Foundation

extension Notification.Name {
    static let liveActivityRequestedStartShot = Notification.Name("liveActivityRequestedStartShot")
    static let liveActivityRequestedFinishShot = Notification.Name("liveActivityRequestedFinishShot")
}

final class RoundLiveActivityManager: @unchecked Sendable {
    static let shared = RoundLiveActivityManager()

    private init() {}

    func sync(
        activeRound: GolfRound?,
        profile: GolferProfile,
        shotCount: Int,
        clubs: [Club],
        trackingPhase: LiveActivityTrackingPhase? = nil
    ) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        guard let activeRound else {
            await endActivities(forProfileID: profile.id.uuidString)
            return
        }

        await endOtherActivities(activeRoundID: activeRound.id.uuidString, profileID: profile.id.uuidString)

        let currentActivity = activity(forRoundID: activeRound.id.uuidString)
        let currentState = currentActivity?.content.state
        var state = RoundActivityAttributes.ContentState(
            roundName: activeRound.name,
            shotCount: shotCount,
            trackingMode: liveActivityTrackingMode(from: profile.shotTrackingMode),
            trackingPhase: trackingPhase ?? currentState?.trackingPhase ?? .idle,
            draft: currentState?.draft,
            draftStep: currentState?.draftStep ?? .club,
            clubOptions: clubOptions(from: clubs),
            startAnchor: currentState?.startAnchor
        )
        state.ensureDraft()

        if let currentActivity {
            await currentActivity.update(ActivityContent(state: state, staleDate: nil))
        } else {
            await startActivity(round: activeRound, profile: profile, state: state)
        }
    }

    func updateTrackingPhase(
        _ trackingPhase: LiveActivityTrackingPhase,
        roundID: UUID?,
        profile: GolferProfile,
        shotCount: Int,
        clubs: [Club],
        startAnchor: ShotLocationAnchor? = nil
    ) async {
        guard let roundID,
              let activity = activity(forRoundID: roundID.uuidString) else {
            return
        }

        var state = activity.content.state
        state.shotCount = shotCount
        state.trackingMode = liveActivityTrackingMode(from: profile.shotTrackingMode)
        state.trackingPhase = trackingPhase
        state.clubOptions = clubOptions(from: clubs)

        if trackingPhase == .awaitingFinish {
            if let startAnchor {
                state.startAnchor = liveActivityLocationAnchor(from: startAnchor)
            }
            state.ensureDraft()
        } else if trackingPhase == .idle {
            state.draft = LiveActivityShotDraft.defaultDraft(clubOptions: state.clubOptions)
            state.draftStep = .club
            state.startAnchor = nil
            LiveActivityDraftBufferStore.clear(roundID: roundID.uuidString)
        }

        await activity.update(ActivityContent(state: state, staleDate: nil))
    }

    func pendingShotDraft(roundID: UUID?) -> LiveActivityShotDraft? {
        guard let roundID else {
            return nil
        }

        if let activityDraft = activity(forRoundID: roundID.uuidString)?.content.state.draft {
            return activityDraft
        }

        if let bufferedDraft = LiveActivityDraftBufferStore.draft(roundID: roundID.uuidString) {
            return bufferedDraft
        }

        return nil
    }

    func defaultShotDraft(clubs: [Club]) -> LiveActivityShotDraft {
        LiveActivityShotDraft.defaultDraft(clubOptions: clubOptions(from: clubs))
    }

    func updatePendingShotDraft(
        _ draft: LiveActivityShotDraft,
        roundID: UUID?,
        profile: GolferProfile,
        shotCount: Int,
        clubs: [Club],
        draftStep: LiveActivityDraftStep? = nil
    ) async {
        guard let roundID else {
            return
        }

        let resolvedDraftStep = draftStep ?? LiveActivityDraftStep.firstIncompleteStep(completedFields: draft.completedFields)
        LiveActivityDraftBufferStore.save(draft: draft, step: resolvedDraftStep, roundID: roundID.uuidString)

        guard let activity = activity(forRoundID: roundID.uuidString) else {
            return
        }

        var state = activity.content.state
        state.shotCount = shotCount
        state.trackingMode = liveActivityTrackingMode(from: profile.shotTrackingMode)
        state.clubOptions = clubOptions(from: clubs)
        state.setDraft(draft, step: resolvedDraftStep)
        await activity.update(ActivityContent(state: state, staleDate: nil))
    }

    func pendingStartAnchor(roundID: UUID?) -> ShotLocationAnchor? {
        guard let roundID,
              let anchor = activity(forRoundID: roundID.uuidString)?.content.state.startAnchor else {
            return nil
        }

        return ShotLocationAnchor(
            latitude: anchor.latitude,
            longitude: anchor.longitude,
            horizontalAccuracyMeters: anchor.horizontalAccuracyMeters,
            altitudeFeet: anchor.altitudeFeet,
            capturedAt: anchor.capturedAt
        )
    }

    func endRoundActivity(roundID: UUID) async {
        guard let activity = activity(forRoundID: roundID.uuidString) else {
            return
        }

        await activity.end(
            ActivityContent(state: activity.content.state, staleDate: Date()),
            dismissalPolicy: .immediate
        )
        LiveActivityDraftBufferStore.clear(roundID: roundID.uuidString)
    }

    private func startActivity(
        round: GolfRound,
        profile: GolferProfile,
        state: RoundActivityAttributes.ContentState
    ) async {
        let attributes = RoundActivityAttributes(
            roundID: round.id.uuidString,
            profileID: profile.id.uuidString,
            profileName: profile.name
        )

        do {
            _ = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            return
        }
    }

    private func activity(forRoundID roundID: String) -> Activity<RoundActivityAttributes>? {
        Activity<RoundActivityAttributes>.activities.first {
            $0.attributes.roundID == roundID && $0.activityState.isUsableForUpdates
        }
    }

    private func endActivities(forProfileID profileID: String) async {
        for activity in Activity<RoundActivityAttributes>.activities where activity.attributes.profileID == profileID {
            await activity.end(
                ActivityContent(state: activity.content.state, staleDate: Date()),
                dismissalPolicy: .immediate
            )
            LiveActivityDraftBufferStore.clear(roundID: activity.attributes.roundID)
        }
    }

    private func endOtherActivities(activeRoundID: String, profileID: String) async {
        for activity in Activity<RoundActivityAttributes>.activities
            where activity.attributes.profileID == profileID && activity.attributes.roundID != activeRoundID {
            await activity.end(
                ActivityContent(state: activity.content.state, staleDate: Date()),
                dismissalPolicy: .immediate
            )
            LiveActivityDraftBufferStore.clear(roundID: activity.attributes.roundID)
        }
    }

    private func clubOptions(from clubs: [Club]) -> [LiveActivityClubOption] {
        clubs.map { club in
            LiveActivityClubOption(
                id: club.id.uuidString,
                compactName: compactClubName(for: club),
                supportsFlop: club.clubType.isWedge
            )
        }
    }

    private func liveActivityLocationAnchor(from anchor: ShotLocationAnchor) -> LiveActivityLocationAnchor {
        LiveActivityLocationAnchor(
            latitude: anchor.latitude,
            longitude: anchor.longitude,
            horizontalAccuracyMeters: anchor.horizontalAccuracyMeters,
            altitudeFeet: anchor.altitudeFeet,
            capturedAt: anchor.capturedAt
        )
    }

    private func compactClubName(for club: Club) -> String {
        if club.clubType.isWedge, let wedgeLoft = club.wedgeLoft {
            return "\(wedgeLoft)\u{00B0}"
        }

        switch club.clubType {
        case .driver:
            return "Driver"
        case .threeWood:
            return "3W"
        case .fiveWood:
            return "5W"
        case .sevenWood:
            return "7W"
        case .twoHybrid:
            return "2H"
        case .threeHybrid:
            return "3H"
        case .fourHybrid:
            return "4H"
        case .fiveHybrid:
            return "5H"
        case .twoIron:
            return "2I"
        case .threeIron:
            return "3I"
        case .fourIron:
            return "4I"
        case .fiveIron:
            return "5I"
        case .sixIron:
            return "6I"
        case .sevenIron:
            return "7I"
        case .eightIron:
            return "8I"
        case .nineIron:
            return "9I"
        case .pitchingWedge:
            return "PW"
        case .gapWedge:
            return "GW"
        case .sandWedge:
            return "SW"
        case .lobWedge:
            return "LW"
        case .putter:
            return "Putter"
        }
    }

    private func liveActivityTrackingMode(from mode: ShotTrackingMode) -> LiveActivityTrackingMode {
        switch mode {
        case .gps:
            .gps
        case .manual:
            .manual
        }
    }
}

private extension ActivityState {
    var isUsableForUpdates: Bool {
        switch self {
        case .active, .pending, .stale:
            true
        case .dismissed, .ended:
            false
        @unknown default:
            false
        }
    }
}
