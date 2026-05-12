import Foundation

public enum GolfBagRepositoryError: Error, Equatable, Sendable {
    case profileNameRequired
    case profileNotFound
    case clubNotFound
    case clubDoesNotBelongToProfile
    case invalidClub([ClubValidationError])
}

public final class GolfBagRepository {
    private let store: GolfBagStore
    private let clubValidator: ClubValidator

    public init(store: GolfBagStore, clubValidator: ClubValidator = ClubValidator()) {
        self.store = store
        self.clubValidator = clubValidator
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
        try store.save(data)
    }
}

