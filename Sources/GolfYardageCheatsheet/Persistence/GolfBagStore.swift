import Foundation

public protocol GolfBagStore {
    func load() throws -> GolfBagData
    func save(_ data: GolfBagData) throws
}

