import Foundation

protocol PersistentInteractor {
    func saveGame(_ appState: AppState) throws /* PersistentError */
    func loadGame() throws -> AppState /*  PersistentError */
}

struct PersistentInteractorImpl: PersistentInteractor {
    enum PersistentError: Error {
        case write(cause: Error?)
        case read(cause: Error?)
    }

    private let repository: Repository

    init(repository: Repository = RepositoryImpl()) {
        self.repository = repository
    }

    func encode(_ appState: AppState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(appState)
    }

    func saveGame(_ appState: AppState) throws {
        do {
            let data = try encode(appState)
            try repository.saveData(data)
        } catch let error {
            throw PersistentError.read(cause: error)
        }
    }

    func loadGame() throws -> AppState {
        do {
            let data = try repository.loadData()
            return try JSONDecoder().decode(AppState.self, from: data)
        } catch let error {
            throw PersistentError.write(cause: error)
        }
    }
}

extension Coordinate { /* Codable */
    enum CodingKeys: String, CodingKey {
        case x
        case y
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
    }
}
