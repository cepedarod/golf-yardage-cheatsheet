import ActivityKit
import Foundation

struct RoundActivityAttributes: ActivityAttributes, Sendable {
    struct ContentState: Codable, Hashable, Sendable {
        var roundName: String
        var shotCount: Int
        var trackingMode: LiveActivityTrackingMode
        var trackingPhase: LiveActivityTrackingPhase
        var draft: LiveActivityShotDraft?
        var clubOptions: [LiveActivityClubOption]
        var startAnchor: LiveActivityLocationAnchor?

        var canStartShot: Bool {
            trackingMode == .gps && trackingPhase == .idle
        }

        var isAwaitingShotDetails: Bool {
            trackingMode == .gps && trackingPhase == .awaitingFinish
        }

        mutating func ensureDraft() {
            if draft == nil {
                draft = LiveActivityShotDraft.defaultDraft(clubOptions: clubOptions)
            }

            normalizeDraft()
        }

        mutating func cycle(_ field: LiveActivityDraftField) {
            ensureDraft()
            var currentDraft = draft ?? LiveActivityShotDraft.defaultDraft(clubOptions: clubOptions)

            switch field {
            case .club:
                currentDraft = cycledClubDraft(currentDraft)
            case .category:
                currentDraft.category = nextCategory(after: currentDraft.category, selectedClubID: currentDraft.clubID)
                currentDraft.power = LiveActivityShotPower.validPowers(for: currentDraft.category).first ?? .full
            case .power:
                currentDraft.power = nextPower(after: currentDraft.power, category: currentDraft.category)
            case .grass:
                currentDraft.grass = LiveActivityGrassType.next(after: currentDraft.grass)
            case .strike:
                currentDraft.strike = LiveActivityStrikeQuality.next(after: currentDraft.strike)
            case .direction:
                currentDraft.direction = LiveActivityShotDirection.next(after: currentDraft.direction)
            }

            draft = currentDraft
            normalizeDraft()
        }

        private func cycledClubDraft(_ draft: LiveActivityShotDraft) -> LiveActivityShotDraft {
            guard clubOptions.isEmpty == false else {
                return draft
            }

            var updatedDraft = draft
            let currentID = updatedDraft.clubID
            let currentIndex = clubOptions.firstIndex { $0.id == currentID } ?? -1
            let nextIndex = clubOptions.index(after: currentIndex)
            let option = clubOptions[nextIndex % clubOptions.count]
            updatedDraft.clubID = option.id
            updatedDraft.clubName = option.compactName
            return updatedDraft
        }

        private mutating func normalizeDraft() {
            guard var draft else {
                return
            }

            if let selectedOption = clubOptions.first(where: { $0.id == draft.clubID }) {
                draft.clubName = selectedOption.compactName
                if selectedOption.supportsFlop == false, draft.category == .flop {
                    draft.category = .normal
                    draft.power = .full
                }
            } else if let firstOption = clubOptions.first {
                draft.clubID = firstOption.id
                draft.clubName = firstOption.compactName
            }

            let validPowers = LiveActivityShotPower.validPowers(for: draft.category)
            if validPowers.contains(draft.power) == false {
                draft.power = validPowers.first ?? .full
            }

            self.draft = draft
        }

        private func nextCategory(
            after category: LiveActivityShotCategory,
            selectedClubID: String?
        ) -> LiveActivityShotCategory {
            let selectedClub = clubOptions.first { $0.id == selectedClubID }
            let categories: [LiveActivityShotCategory] = selectedClub?.supportsFlop == true
                ? [.normal, .lowTrajectory, .flop]
                : [.normal, .lowTrajectory]
            let currentIndex = categories.firstIndex(of: category) ?? -1
            return categories[categories.index(after: currentIndex) % categories.count]
        }

        private func nextPower(
            after power: LiveActivityShotPower,
            category: LiveActivityShotCategory
        ) -> LiveActivityShotPower {
            let powers = LiveActivityShotPower.validPowers(for: category)
            let currentIndex = powers.firstIndex(of: power) ?? -1
            return powers[powers.index(after: currentIndex) % powers.count]
        }
    }

    var roundID: String
    var profileID: String
    var profileName: String
}

enum LiveActivityTrackingMode: String, Codable, Hashable, Sendable {
    case gps
    case manual
}

enum LiveActivityTrackingPhase: String, Codable, Hashable, Sendable {
    case idle
    case measuringStart
    case awaitingFinish
    case measuringFinish
}

struct LiveActivityClubOption: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var name: String
    var compactName: String
    var supportsFlop: Bool
}

struct LiveActivityLocationAnchor: Codable, Hashable, Sendable {
    var latitude: Double
    var longitude: Double
    var horizontalAccuracyMeters: Double
    var capturedAt: Date
}

struct LiveActivityShotDraft: Codable, Hashable, Sendable {
    var clubID: String?
    var clubName: String
    var category: LiveActivityShotCategory
    var power: LiveActivityShotPower
    var grass: LiveActivityGrassType
    var strike: LiveActivityStrikeQuality
    var direction: LiveActivityShotDirection

    static func defaultDraft(clubOptions: [LiveActivityClubOption]) -> LiveActivityShotDraft {
        let club = clubOptions.first

        return LiveActivityShotDraft(
            clubID: club?.id,
            clubName: club?.compactName ?? "Club",
            category: .normal,
            power: .full,
            grass: .fairway,
            strike: .pure,
            direction: .straight
        )
    }
}

enum LiveActivityDraftField: String, Codable, CaseIterable, Hashable, Sendable {
    case club
    case category
    case power
    case grass
    case strike
    case direction
}

enum LiveActivityShotCategory: String, Codable, CaseIterable, Hashable, Sendable {
    case normal
    case lowTrajectory
    case flop

    var displayName: String {
        switch self {
        case .normal:
            "Normal"
        case .lowTrajectory:
            "Low"
        case .flop:
            "Flop"
        }
    }
}

enum LiveActivityShotPower: String, Codable, CaseIterable, Hashable, Sendable {
    case full
    case threeQuarter
    case half
    case quarter
    case stinger
    case punch
    case softPunch
    case chip

    var displayName: String {
        switch self {
        case .full:
            "Full"
        case .threeQuarter:
            "3/4"
        case .half:
            "Half"
        case .quarter:
            "Quarter"
        case .stinger:
            "Stinger"
        case .punch:
            "Punch"
        case .softPunch:
            "Soft"
        case .chip:
            "Chip"
        }
    }

    static func validPowers(for category: LiveActivityShotCategory) -> [LiveActivityShotPower] {
        switch category {
        case .normal, .flop:
            [.full, .threeQuarter, .half, .quarter]
        case .lowTrajectory:
            [.stinger, .punch, .softPunch, .chip]
        }
    }
}

enum LiveActivityGrassType: String, Codable, CaseIterable, Hashable, Sendable {
    case fairway
    case rough
    case deepRough

    var displayName: String {
        switch self {
        case .fairway:
            "Fairway"
        case .rough:
            "Rough"
        case .deepRough:
            "Deep"
        }
    }

    static func next(after value: LiveActivityGrassType) -> LiveActivityGrassType {
        nextValue(value, in: allCases)
    }
}

enum LiveActivityStrikeQuality: String, Codable, CaseIterable, Hashable, Sendable {
    case thin
    case pure
    case chunk

    var displayName: String {
        switch self {
        case .thin:
            "Thin"
        case .pure:
            "Pure"
        case .chunk:
            "Chunk"
        }
    }

    static func next(after value: LiveActivityStrikeQuality) -> LiveActivityStrikeQuality {
        nextValue(value, in: allCases)
    }
}

enum LiveActivityShotDirection: String, Codable, CaseIterable, Hashable, Sendable {
    case hook
    case draw
    case straight
    case fade
    case slice

    var displayName: String {
        switch self {
        case .hook:
            "Hook"
        case .draw:
            "Draw"
        case .straight:
            "Straight"
        case .fade:
            "Fade"
        case .slice:
            "Slice"
        }
    }

    static func next(after value: LiveActivityShotDirection) -> LiveActivityShotDirection {
        nextValue(value, in: allCases)
    }
}

enum CaddieCatLiveActivityDeepLink {
    case openRound
    case startShot
    case openFinish

    func url(roundID: String) -> URL {
        var components = URLComponents()
        components.scheme = "caddiecat"

        switch self {
        case .openRound:
            components.host = "round"
        case .startShot:
            components.host = "track-shot-start"
        case .openFinish:
            components.host = "track-shot-finish"
        }

        components.queryItems = [URLQueryItem(name: "roundID", value: roundID)]
        return components.url ?? URL(string: "caddiecat://round")!
    }
}

private func nextValue<Value: Equatable>(_ value: Value, in values: [Value]) -> Value {
    guard values.isEmpty == false else {
        return value
    }

    let currentIndex = values.firstIndex(of: value) ?? -1
    return values[values.index(after: currentIndex) % values.count]
}
