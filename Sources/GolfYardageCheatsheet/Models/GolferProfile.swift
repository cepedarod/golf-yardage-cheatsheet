import Foundation

public struct GolferProfile: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var shotTrackingMode: ShotTrackingMode
    public var createdAt: Date
    public var updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case shotTrackingMode
        case createdAt
        case updatedAt
    }

    public init(
        id: UUID = UUID(),
        name: String,
        shotTrackingMode: ShotTrackingMode = .gps,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.shotTrackingMode = shotTrackingMode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        shotTrackingMode = try container.decodeIfPresent(ShotTrackingMode.self, forKey: .shotTrackingMode) ?? .gps
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

public enum ShotTrackingMode: String, CaseIterable, Codable, Equatable, Sendable {
    case gps
    case manual

    public var displayName: String {
        switch self {
        case .gps:
            "GPS"
        case .manual:
            "Manual"
        }
    }
}

public struct GolfRound: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var profileID: UUID
    public var name: String
    public var startedAt: Date
    public var endedAt: Date?
    public var courseName: String?
    public var nameWasEdited: Bool

    public init(
        id: UUID = UUID(),
        profileID: UUID,
        name: String,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        courseName: String? = nil,
        nameWasEdited: Bool = false
    ) {
        self.id = id
        self.profileID = profileID
        self.name = name
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.courseName = courseName
        self.nameWasEdited = nameWasEdited
    }

    public var isCompleted: Bool {
        endedAt != nil
    }
}
