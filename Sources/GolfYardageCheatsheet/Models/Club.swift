import Foundation

public struct Club: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var profileID: UUID
    public var nickname: String?
    public var clubType: ClubType
    public var wedgeLoft: Int?
    public var shotType: ShotType?
    public var isActive: Bool
    public var swingDistances: SwingDistanceSet?
    public var putterDistances: PutterDistanceSet?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        profileID: UUID,
        nickname: String? = nil,
        clubType: ClubType,
        wedgeLoft: Int? = nil,
        shotType: ShotType? = .normal,
        isActive: Bool = true,
        swingDistances: SwingDistanceSet? = nil,
        putterDistances: PutterDistanceSet? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.profileID = profileID
        self.nickname = nickname
        self.clubType = clubType
        self.wedgeLoft = wedgeLoft
        self.shotType = clubType == .putter ? nil : shotType
        self.isActive = isActive
        self.swingDistances = swingDistances
        self.putterDistances = putterDistances
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

