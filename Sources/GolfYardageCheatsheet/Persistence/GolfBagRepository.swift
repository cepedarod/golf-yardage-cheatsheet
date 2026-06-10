import Foundation

public enum GolfBagRepositoryError: Error, Equatable, Sendable {
    case profileNameRequired
    case homeBaseCityRequired
    case profileNotFound
    case clubNotFound
    case clubDoesNotBelongToProfile
    case roundNameRequired
    case roundNotFound
    case roundDoesNotBelongToProfile
    case shotRecordNotFound
    case invalidClub([ClubValidationError])
    case invalidShotRecord([ShotRecordValidationError])
}

public final class GolfBagRepository {
    private let store: GolfBagStore
    private let clubValidator: ClubValidator
    private let shotRecordValidator: ShotRecordValidator

    public init(
        store: GolfBagStore,
        clubValidator: ClubValidator = ClubValidator(),
        shotRecordValidator: ShotRecordValidator = ShotRecordValidator()
    ) {
        self.store = store
        self.clubValidator = clubValidator
        self.shotRecordValidator = shotRecordValidator
    }

    public func loadData() throws -> GolfBagData {
        try store.load()
    }

    @discardableResult
    public func createProfile(name: String, now: Date = Date()) throws -> GolferProfile {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedName.isEmpty == false else {
            throw GolfBagRepositoryError.profileNameRequired
        }

        var data = try store.load()
        let profile = GolferProfile(name: trimmedName, createdAt: now, updatedAt: now)

        data.profiles.append(profile)
        data.selectedProfileID = profile.id

        try store.save(data)
        return profile
    }

    public func selectProfile(id profileID: UUID) throws {
        var data = try store.load()

        guard data.profiles.contains(where: { $0.id == profileID }) else {
            throw GolfBagRepositoryError.profileNotFound
        }

        data.selectedProfileID = profileID
        try store.save(data)
    }

    public func updateProfileShotTrackingMode(profileID: UUID, mode: ShotTrackingMode, now: Date = Date()) throws {
        var data = try store.load()

        guard let index = data.profiles.firstIndex(where: { $0.id == profileID }) else {
            throw GolfBagRepositoryError.profileNotFound
        }

        data.profiles[index].shotTrackingMode = mode
        data.profiles[index].updatedAt = now
        try store.save(data)
    }

    public func updateProfileAnalysisDateRange(
        profileID: UUID,
        analysisDateRange: AnalysisDateRange,
        now: Date = Date()
    ) throws {
        var data = try store.load()

        guard let index = data.profiles.firstIndex(where: { $0.id == profileID }) else {
            throw GolfBagRepositoryError.profileNotFound
        }

        data.profiles[index].analysisDateRange = analysisDateRange
        data.profiles[index].updatedAt = now
        try store.save(data)
    }

    public func updateProfileAverageDistanceGrassTypes(
        profileID: UUID,
        grassTypes: Set<GrassType>,
        now: Date = Date()
    ) throws {
        var data = try store.load()

        guard let index = data.profiles.firstIndex(where: { $0.id == profileID }) else {
            throw GolfBagRepositoryError.profileNotFound
        }

        data.profiles[index].averageDistanceGrassTypes = grassTypes.isEmpty
            ? GolferProfile.defaultAverageDistanceGrassTypes
            : grassTypes
        data.profiles[index].updatedAt = now
        try store.save(data)
    }

    public func acknowledgeProfileOnboardingGuide(
        profileID: UUID,
        guide: ProfileOnboardingGuide,
        now: Date = Date()
    ) throws {
        var data = try store.load()

        guard let index = data.profiles.firstIndex(where: { $0.id == profileID }) else {
            throw GolfBagRepositoryError.profileNotFound
        }

        data.profiles[index].acknowledgedOnboardingGuides.insert(guide)
        data.profiles[index].updatedAt = now
        try store.save(data)
    }

    public func updateProfileAltitudeSettings(
        profileID: UUID,
        homeBaseCity: String,
        homeBaseAltitudeFeet: Double,
        altitudeCalculationMode: AltitudeCalculationMode,
        now: Date = Date()
    ) throws {
        let trimmedCity = homeBaseCity.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedCity.isEmpty == false else {
            throw GolfBagRepositoryError.homeBaseCityRequired
        }

        var data = try store.load()

        guard let index = data.profiles.firstIndex(where: { $0.id == profileID }) else {
            throw GolfBagRepositoryError.profileNotFound
        }

        data.profiles[index].homeBaseCity = trimmedCity
        data.profiles[index].homeBaseAltitudeFeet = homeBaseAltitudeFeet
        data.profiles[index].altitudeCalculationMode = altitudeCalculationMode
        data.profiles[index].updatedAt = now
        try store.save(data)
    }

    public func deleteProfile(id profileID: UUID) throws {
        var data = try store.load()

        guard data.profiles.contains(where: { $0.id == profileID }) else {
            throw GolfBagRepositoryError.profileNotFound
        }

        let removedClubIDs = Set(data.clubs.filter { $0.profileID == profileID }.map(\.id))

        data.profiles.removeAll { $0.id == profileID }
        data.clubs.removeAll { $0.profileID == profileID }
        data.shotRecords.removeAll { $0.profileID == profileID || removedClubIDs.contains($0.clubID) }
        data.rounds.removeAll { $0.profileID == profileID }

        if data.selectedProfileID == profileID {
            data.selectedProfileID = data.profiles.first?.id
        }

        try store.save(data)
    }

    public func profiles() throws -> [GolferProfile] {
        try store.load().profiles.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    public func clubs(for profileID: UUID, includeInactive: Bool = true) throws -> [Club] {
        let data = try store.load()

        guard data.profiles.contains(where: { $0.id == profileID }) else {
            throw GolfBagRepositoryError.profileNotFound
        }

        let profileClubs = data.clubs(for: profileID)

        if includeInactive {
            return profileClubs
        }

        return profileClubs.filter { $0.isActive }
    }

    @discardableResult
    public func saveClub(_ club: Club) throws -> Club {
        let validationErrors = clubValidator.validate(club)

        guard validationErrors.isEmpty else {
            throw GolfBagRepositoryError.invalidClub(validationErrors)
        }

        var data = try store.load()

        guard data.profiles.contains(where: { $0.id == club.profileID }) else {
            throw GolfBagRepositoryError.profileNotFound
        }

        if let existingIndex = data.clubs.firstIndex(where: { $0.id == club.id }) {
            guard data.clubs[existingIndex].profileID == club.profileID else {
                throw GolfBagRepositoryError.clubDoesNotBelongToProfile
            }

            data.clubs[existingIndex] = club
        } else {
            data.clubs.append(club)
        }

        try store.save(data)
        return club
    }

    @discardableResult
    public func saveShotRecord(_ record: ShotRecord) throws -> ShotRecord {
        var data = try store.load()

        guard data.profiles.contains(where: { $0.id == record.profileID }) else {
            throw GolfBagRepositoryError.profileNotFound
        }

        guard let club = data.clubs.first(where: { $0.id == record.clubID }) else {
            throw GolfBagRepositoryError.clubNotFound
        }

        guard club.profileID == record.profileID else {
            throw GolfBagRepositoryError.clubDoesNotBelongToProfile
        }

        if let roundID = record.roundID {
            guard let round = data.rounds.first(where: { $0.id == roundID }) else {
                throw GolfBagRepositoryError.roundNotFound
            }

            guard round.profileID == record.profileID else {
                throw GolfBagRepositoryError.roundDoesNotBelongToProfile
            }
        }

        let validationErrors = shotRecordValidator.validate(record, club: club)

        guard validationErrors.isEmpty else {
            throw GolfBagRepositoryError.invalidShotRecord(validationErrors)
        }

        if let existingIndex = data.shotRecords.firstIndex(where: { $0.id == record.id }) {
            data.shotRecords[existingIndex] = record
        } else {
            data.shotRecords.append(record)
        }

        try store.save(data)
        return record
    }

    public func shotRecords(for profileID: UUID, clubID: UUID? = nil) throws -> [ShotRecord] {
        try shotRecords(for: profileID, clubID: clubID, roundID: nil)
    }

    public func shotRecords(for profileID: UUID, roundID: UUID) throws -> [ShotRecord] {
        try shotRecords(for: profileID, clubID: nil, roundID: roundID)
    }

    private func shotRecords(for profileID: UUID, clubID: UUID?, roundID: UUID?) throws -> [ShotRecord] {
        let data = try store.load()

        guard data.profiles.contains(where: { $0.id == profileID }) else {
            throw GolfBagRepositoryError.profileNotFound
        }

        if let roundID {
            guard let round = data.rounds.first(where: { $0.id == roundID }) else {
                throw GolfBagRepositoryError.roundNotFound
            }

            guard round.profileID == profileID else {
                throw GolfBagRepositoryError.roundDoesNotBelongToProfile
            }
        }

        return data.shotRecords
            .filter { record in
                record.profileID == profileID &&
                    (clubID == nil || record.clubID == clubID) &&
                    (roundID == nil || record.roundID == roundID)
            }
            .sorted { lhs, rhs in
                if lhs.createdAt != rhs.createdAt {
                    return lhs.createdAt < rhs.createdAt
                }

                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    public func deleteAllShotRecords(for profileID: UUID) throws {
        var data = try store.load()

        guard data.profiles.contains(where: { $0.id == profileID }) else {
            throw GolfBagRepositoryError.profileNotFound
        }

        data.shotRecords.removeAll { $0.profileID == profileID }
        try store.save(data)
    }

    public func deleteShotRecord(id recordID: UUID) throws {
        var data = try store.load()

        guard let index = data.shotRecords.firstIndex(where: { $0.id == recordID }) else {
            throw GolfBagRepositoryError.shotRecordNotFound
        }

        data.shotRecords.remove(at: index)
        try store.save(data)
    }

    @discardableResult
    public func startRound(
        profileID: UUID,
        name: String,
        courseName: String? = nil,
        altitudeFeet: Double? = nil,
        distanceTrackingMode: RoundDistanceTrackingMode = .accountForAltitude,
        startedAt: Date = Date()
    ) throws -> GolfRound {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedName.isEmpty == false else {
            throw GolfBagRepositoryError.roundNameRequired
        }

        var data = try store.load()

        guard data.profiles.contains(where: { $0.id == profileID }) else {
            throw GolfBagRepositoryError.profileNotFound
        }

        if let activeRound = data.rounds
            .filter({ $0.profileID == profileID && $0.isCompleted == false })
            .sorted(by: newestRoundFirst)
            .first {
            return activeRound
        }

        let round = GolfRound(
            profileID: profileID,
            name: trimmedName,
            startedAt: startedAt,
            courseName: courseName,
            nameWasEdited: false,
            altitudeFeet: altitudeFeet,
            distanceTrackingMode: distanceTrackingMode
        )

        data.rounds.append(round)
        try store.save(data)
        return round
    }

    @discardableResult
    public func endRound(id roundID: UUID, endedAt: Date = Date()) throws -> GolfRound {
        var data = try store.load()

        guard let index = data.rounds.firstIndex(where: { $0.id == roundID }) else {
            throw GolfBagRepositoryError.roundNotFound
        }

        data.rounds[index].endedAt = endedAt
        try store.save(data)
        return data.rounds[index]
    }

    @discardableResult
    public func updateRoundName(id roundID: UUID, name: String) throws -> GolfRound {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedName.isEmpty == false else {
            throw GolfBagRepositoryError.roundNameRequired
        }

        var data = try store.load()

        guard let index = data.rounds.firstIndex(where: { $0.id == roundID }) else {
            throw GolfBagRepositoryError.roundNotFound
        }

        data.rounds[index].name = trimmedName
        data.rounds[index].nameWasEdited = true
        try store.save(data)
        return data.rounds[index]
    }

    @discardableResult
    public func updateRoundDistanceTrackingMode(
        id roundID: UUID,
        mode: RoundDistanceTrackingMode
    ) throws -> GolfRound {
        var data = try store.load()

        guard let index = data.rounds.firstIndex(where: { $0.id == roundID }) else {
            throw GolfBagRepositoryError.roundNotFound
        }

        data.rounds[index].distanceTrackingMode = mode
        try store.save(data)
        return data.rounds[index]
    }

    public func rounds(for profileID: UUID, includeActive: Bool = true) throws -> [GolfRound] {
        let data = try store.load()

        guard data.profiles.contains(where: { $0.id == profileID }) else {
            throw GolfBagRepositoryError.profileNotFound
        }

        return data.rounds
            .filter { round in
                round.profileID == profileID && (includeActive || round.isCompleted)
            }
            .sorted { lhs, rhs in
                if lhs.startedAt != rhs.startedAt {
                    return lhs.startedAt > rhs.startedAt
                }

                return lhs.id.uuidString < rhs.id.uuidString
            }
    }

    public func activeRound(for profileID: UUID) throws -> GolfRound? {
        try rounds(for: profileID)
            .first { $0.isCompleted == false }
    }

    private func newestRoundFirst(_ lhs: GolfRound, _ rhs: GolfRound) -> Bool {
        if lhs.startedAt != rhs.startedAt {
            return lhs.startedAt > rhs.startedAt
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }

    public func deleteRound(id roundID: UUID) throws {
        var data = try store.load()

        guard let index = data.rounds.firstIndex(where: { $0.id == roundID }) else {
            throw GolfBagRepositoryError.roundNotFound
        }

        data.rounds.remove(at: index)
        for recordIndex in data.shotRecords.indices where data.shotRecords[recordIndex].roundID == roundID {
            data.shotRecords[recordIndex].roundID = nil
        }

        try store.save(data)
    }

    public func abortRound(id roundID: UUID) throws {
        var data = try store.load()

        guard let index = data.rounds.firstIndex(where: { $0.id == roundID }) else {
            throw GolfBagRepositoryError.roundNotFound
        }

        data.rounds.remove(at: index)
        data.shotRecords.removeAll { $0.roundID == roundID }

        try store.save(data)
    }

    public func setClubActive(_ isActive: Bool, clubID: UUID, now: Date = Date()) throws {
        var data = try store.load()

        guard let index = data.clubs.firstIndex(where: { $0.id == clubID }) else {
            throw GolfBagRepositoryError.clubNotFound
        }

        data.clubs[index].isActive = isActive
        data.clubs[index].updatedAt = now

        try store.save(data)
    }

    public func deleteClub(id clubID: UUID) throws {
        var data = try store.load()

        guard let index = data.clubs.firstIndex(where: { $0.id == clubID }) else {
            throw GolfBagRepositoryError.clubNotFound
        }

        data.clubs.remove(at: index)
        data.shotRecords.removeAll { $0.clubID == clubID }
        try store.save(data)
    }
}
