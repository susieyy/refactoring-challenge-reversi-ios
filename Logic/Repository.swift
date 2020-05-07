import Foundation

protocol Repository {
    func saveData(_ data: Data) throws /* FileIOError */
    func loadData() throws -> Data /* FileIOError */
}

struct RepositoryImpl: Repository {
    enum FileIOError: Error {
        case write(cause: Error?)
        case read(cause: Error?)
    }

    private func createFileURL() throws -> URL {
        try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("appstate.json")
    }

    func saveData(_ data: Data) throws {
        do {
            let fileURL = try createFileURL()
            try data.write(to: fileURL, options: [])
        } catch let error {
            throw FileIOError.read(cause: error)
        }
    }

    func loadData() throws -> Data {
        do {
            let fileURL = try createFileURL()
            return try Data(contentsOf: fileURL)
        } catch let error {
            throw FileIOError.write(cause: error)
        }
    }
}
