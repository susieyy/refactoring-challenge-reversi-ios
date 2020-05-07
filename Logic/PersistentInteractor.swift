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

    func saveGame(_ appState: AppState) throws {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(appState)
            try repository.saveData(data)

//            print("------------------------------------------------------")
//            print(String(data: data, encoding: String.Encoding.utf8)!)
//            print("------------------------------------------------------")
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

extension ComputerThinking { /* Codable */
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try? container.decode(String.self, forKey: .none), value == CodingKeys.none.rawValue {
            self = .none
        } else if let value = try? container.decode(Side.self, forKey: .thinking) {
            self = .thinking(value)
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: container.codingPath, debugDescription: "Data doesn't match"))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .none: try container.encode(CodingKeys.none.rawValue, forKey: .none)
        case .thinking(let disk): try container.encode(disk, forKey: .thinking)
        }
    }

    enum CodingKeys: String, CodingKey {
        case none
        case thinking
    }
}

extension Coordinate { /* Codable */
    enum CodingKeys: String, CodingKey {
        case x
        case y
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .y)
        try container.encode(y, forKey: .x)
    }
}
