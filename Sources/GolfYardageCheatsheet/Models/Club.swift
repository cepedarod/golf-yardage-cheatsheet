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
    public var normalDistances: SwingDistanceSet?
    public var lowTrajectoryDistances: LowTrajectoryDistanceSet?
    public var flopDistances: SwingDistanceSet?
    public var putterDistances: PutterDistanceSet?
    public var createdAt: Date
    public var updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case profileID
        case nickname
        case clubType
        case wedgeLoft
        case shotType
        case isActive
        case swingDistances
        case normalDistances
        case lowTrajectoryDistances
        case flopDistances
        case putterDistances
        case createdAt
        case updatedAt
    }

    public init(
        id: UUID = UUID(),
        profileID: UUID,
        nickname: String? = nil,
        clubType: ClubType,
        wedgeLoft: Int? = nil,
        shotType: ShotType? = .normal,
        isActive: Bool = true,
        swingDistances: SwingDistanceSet? = nil,
        normalDistances: SwingDistanceSet? = nil,
        lowTrajectoryDistances: LowTrajectoryDistanceSet? = nil,
        flopDistances: SwingDistanceSet? = nil,
        putterDistances: PutterDistanceSet? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        let resolvedShotType = clubType == .putter ? nil : shotType
        var resolvedNormalDistances = normalDistances
        var resolvedLowTrajectoryDistances = lowTrajectoryDistances
        var resolvedFlopDistances = flopDistances

        if let swingDistances {
            switch resolvedShotType {
            case .punch:
                if resolvedLowTrajectoryDistances == nil {
                    resolvedLowTrajectoryDistances = LowTrajectoryDistanceSet(swingDistances: swingDistances)
                }
            case .flop:
                if resolvedFlopDistances == nil {
                    resolvedFlopDistances = swingDistances
                }
            case .normal, nil:
                if clubType != .putter, resolvedNormalDistances == nil {
                    resolvedNormalDistances = swingDistances
                }
            }
        }

        self.id = id
        self.profileID = profileID
        self.nickname = nickname
        self.clubType = clubType
        self.wedgeLoft = wedgeLoft
        self.shotType = resolvedShotType
        self.isActive = isActive
        self.swingDistances = swingDistances
        self.normalDistances = resolvedNormalDistances
        self.lowTrajectoryDistances = resolvedLowTrajectoryDistances
        self.flopDistances = resolvedFlopDistances
        self.putterDistances = putterDistances
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        refreshCompatibilityFields(preferredShotType: Self.preferredCompatibilityShotType(
            shotType: resolvedShotType,
            swingDistances: swingDistances
        ))
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let profileID = try container.decode(UUID.self, forKey: .profileID)
        let nickname = try container.decodeIfPresent(String.self, forKey: .nickname)
        let clubType = try container.decode(ClubType.self, forKey: .clubType)
        let wedgeLoft = try container.decodeIfPresent(Int.self, forKey: .wedgeLoft)
        let decodedShotType = try container.decodeIfPresent(ShotType.self, forKey: .shotType)
        let isActive = try container.decode(Bool.self, forKey: .isActive)
        let decodedSwingDistances = try container.decodeIfPresent(SwingDistanceSet.self, forKey: .swingDistances)
        var normalDistances = try container.decodeIfPresent(SwingDistanceSet.self, forKey: .normalDistances)
        var lowTrajectoryDistances = try container.decodeIfPresent(LowTrajectoryDistanceSet.self, forKey: .lowTrajectoryDistances)
        var flopDistances = try container.decodeIfPresent(SwingDistanceSet.self, forKey: .flopDistances)
        let putterDistances = try container.decodeIfPresent(PutterDistanceSet.self, forKey: .putterDistances)
        let createdAt = try container.decode(Date.self, forKey: .createdAt)
        let updatedAt = try container.decode(Date.self, forKey: .updatedAt)

        if let decodedSwingDistances,
           normalDistances == nil,
           lowTrajectoryDistances == nil,
           flopDistances == nil,
           clubType != .putter {
            switch decodedShotType {
            case .punch:
                lowTrajectoryDistances = LowTrajectoryDistanceSet(swingDistances: decodedSwingDistances)
            case .flop:
                flopDistances = decodedSwingDistances
            case .normal, nil:
                normalDistances = decodedSwingDistances
            }
        }

        self.id = id
        self.profileID = profileID
        self.nickname = nickname
        self.clubType = clubType
        self.wedgeLoft = wedgeLoft
        self.shotType = clubType == .putter ? nil : decodedShotType
        self.isActive = isActive
        self.swingDistances = decodedSwingDistances
        self.normalDistances = normalDistances
        self.lowTrajectoryDistances = lowTrajectoryDistances
        self.flopDistances = flopDistances
        self.putterDistances = putterDistances
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        refreshCompatibilityFields(preferredShotType: decodedShotType)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(profileID, forKey: .profileID)
        try container.encodeIfPresent(nickname, forKey: .nickname)
        try container.encode(clubType, forKey: .clubType)
        try container.encodeIfPresent(wedgeLoft, forKey: .wedgeLoft)
        try container.encode(isActive, forKey: .isActive)
        try container.encodeIfPresent(normalDistances, forKey: .normalDistances)
        try container.encodeIfPresent(lowTrajectoryDistances, forKey: .lowTrajectoryDistances)
        try container.encodeIfPresent(flopDistances, forKey: .flopDistances)
        try container.encodeIfPresent(putterDistances, forKey: .putterDistances)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }

    mutating func refreshCompatibilityFields(preferredShotType: ShotType? = nil) {
        shotType = Self.compatibilityShotType(
            clubType: clubType,
            preferredShotType: preferredShotType,
            normalDistances: normalDistances,
            lowTrajectoryDistances: lowTrajectoryDistances,
            flopDistances: flopDistances
        )
        swingDistances = Self.compatibilitySwingDistances(
            shotType: shotType,
            normalDistances: normalDistances,
            lowTrajectoryDistances: lowTrajectoryDistances,
            flopDistances: flopDistances
        )
    }

    private static func compatibilityShotType(
        clubType: ClubType,
        preferredShotType: ShotType?,
        normalDistances: SwingDistanceSet?,
        lowTrajectoryDistances: LowTrajectoryDistanceSet?,
        flopDistances: SwingDistanceSet?
    ) -> ShotType? {
        guard clubType != .putter else {
            return nil
        }

        if let preferredShotType {
            return preferredShotType
        }

        if normalDistances?.hasAtLeastOneDistance == true {
            return .normal
        }

        if flopDistances?.hasAtLeastOneDistance == true {
            return .flop
        }

        if lowTrajectoryDistances?.hasAtLeastOneDistance == true {
            return .punch
        }

        return .normal
    }

    private static func preferredCompatibilityShotType(
        shotType: ShotType?,
        swingDistances: SwingDistanceSet?
    ) -> ShotType? {
        if swingDistances != nil || shotType != .normal {
            return shotType
        }

        return nil
    }

    private static func compatibilitySwingDistances(
        shotType: ShotType?,
        normalDistances: SwingDistanceSet?,
        lowTrajectoryDistances: LowTrajectoryDistanceSet?,
        flopDistances: SwingDistanceSet?
    ) -> SwingDistanceSet? {
        switch shotType {
        case .punch:
            lowTrajectoryDistances?.asSwingDistanceSet() ?? normalDistances ?? flopDistances
        case .flop:
            flopDistances ?? normalDistances ?? lowTrajectoryDistances?.asSwingDistanceSet()
        case .normal, nil:
            normalDistances ?? flopDistances ?? lowTrajectoryDistances?.asSwingDistanceSet()
        }
    }
}
