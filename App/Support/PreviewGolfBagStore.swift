import Foundation

final class PreviewGolfBagStore: GolfBagStore {
    private var data: GolfBagData

    init(data: GolfBagData = .empty) {
        self.data = data
    }

    func load() throws -> GolfBagData {
        data
    }

    func save(_ data: GolfBagData) throws {
        self.data = data
    }
}

