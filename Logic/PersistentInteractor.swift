import Foundation

public struct LoadData {
    let side: Disk?
    let player1: Player
    let player2: Player
    let squares: [(disk: Disk?, x: Int, y: Int)]
}

protocol PersistentInteractor {
    func saveGame(side: Disk?, player1: PlayerState, player2: PlayerState, boardState: BoardState) throws /* FileIOError */
    func loadGame() throws -> LoadData /* FileIOError, PersistentError */
}

private let defaultPath = (NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first! as NSString).appendingPathComponent("Game")

struct PersistentInteractorImpl: PersistentInteractor {
    enum PersistentError: Error {
        case parse(path: String, cause: Error?)
    }

    private let repository: Repository
    private let path: String

    init(path: String = defaultPath, repository: Repository = RepositoryImpl()) {
        self.path = path
        self.repository = repository
    }

    func saveGame(side: Disk?, player1: PlayerState, player2: PlayerState, boardState: BoardState) throws {
        let data = createSaveData(side: side, player1: player1, player2: player2, boardState: boardState)
        try repository.saveData(path: path, data: data)
    }

    func loadGame() throws -> LoadData {
        let lines: ArraySlice<Substring> = try repository.loadData(path: path)
        return try parseLoadData(lines: lines)
    }

    func createSaveData(side: Disk?, player1: PlayerState, player2: PlayerState, boardState: BoardState) -> String {
        var output: String = ""
        output += side.symbol
        output += player1.player.index.description
        output += player2.player.index.description
        output += "\n"

        for y in BoardConstant.yRange {
            for x in BoardConstant.xRange {
                let disk: Disk? = boardState.squareAt(x: x, y: y)?.disk
                output += disk.symbol
            }
            output += "\n"
        }
        return output
    }

    func parseLoadData(lines: ArraySlice<Substring>) throws -> LoadData {
        var lines = lines

        guard var line = lines.popFirst() else {
            throw PersistentError.parse(path: path, cause: nil)
        }

        // side
        let side: Disk?
        do {
            guard
                let diskSymbol = line.popFirst(),
                let disk = Optional<Disk>(symbol: diskSymbol.description)
            else {
                throw PersistentError.parse(path: path, cause: nil)
            }
            side = disk
        }

        // players
        let players: [Player] = try Disk.sides.map { _ in
            guard
                let playerSymbol = line.popFirst(),
                let playerNumber = Int(playerSymbol.description),
                let player = Player(index: playerNumber)
            else {
                throw PersistentError.parse(path: path, cause: nil)
            }
            return player
        }

        // board
        var squares: [(disk: Disk?, x: Int, y: Int)] = []
        do {
            guard lines.count == BoardConstant.height else {
                throw PersistentError.parse(path: path, cause: nil)
            }

            var y = 0
            while let line = lines.popFirst() {
                var x = 0
                for character in line {
                    let disk = Disk?(symbol: "\(character)").flatMap { $0 }
                    squares.append((disk: disk, x: x, y: y))
                    x += 1
                }
                guard x == BoardConstant.width else {
                    throw PersistentError.parse(path: path, cause: nil)
                }
                y += 1
            }
            guard y == BoardConstant.height else {
                throw PersistentError.parse(path: path, cause: nil)
            }
        }

        return LoadData(side: side, player1: players[0], player2: players[1], squares: squares)
    }
}


extension Optional where Wrapped == Disk {
    fileprivate init?<S: StringProtocol>(symbol: S) {
        switch symbol {
        case "x":
            self = .some(.dark)
        case "o":
            self = .some(.light)
        case "-":
            self = .none
        default:
            return nil
        }
    }

    fileprivate var symbol: String {
        switch self {
        case .some(.dark):
            return "x"
        case .some(.light):
            return "o"
        case .none:
            return "-"
        }
    }
}
