import Foundation
import ReSwift

public struct AppState: StateType, Codable {
    public var player1: PlayerState = .init(side: .dark)
    public var player2: PlayerState = .init(side: .light)
    public var squaresState: SquaresState = .init()
    public var computerThinking: ComputerThinking = .none
    public var currentTurn: CurrentTurn {
        if isStaring {
            return CurrentTurn.start
        } else if let side = side {
            let player = self.player(at: side)
            return CurrentTurn.turn(Turn(side: side, player: player))
        } else {
            if let winner = boardState.sideWithMoreDisks() {
                let player = self.player(at: winner)
                return CurrentTurn.gameOverWon(Turn(side: winner, player: player))
            } else {
                return CurrentTurn.gameOverTied
            }
        }
    }
    public var shouldShowCannotPlaceDisk: Trigger?

    var id: String = NSUUID().uuidString
    var boardState: BoardState = .init()
    var side: Disk? = .dark
    var isStaring: Bool = false

    fileprivate func player(at side: Disk) -> Player {
        switch side {
        case .dark: return self.player1.player
        case .light: return self.player2.player
        }
    }
}

func reducer(action: Action, state: AppState?) -> AppState {
    var state = state ?? .init()
    state.isStaring = false

    let data = try! JSONEncoder().encode(state)
    print(String(data: data, encoding: String.Encoding.utf8)!)

    let decoded = try! JSONDecoder().decode(AppState.self, from: data)
    print(decoded)


    if let action = action as? AppAction {
        switch action {
        case .placeDisk(let disk, let x, let y):
            let diskCoordinates = state.boardState.flippedDiskCoordinatesByPlacingDisk(disk, atX: x, y: y)
            guard !diskCoordinates.isEmpty else { return state }
            let squares = [Square(disk: disk, x: x, y: y)] + diskCoordinates.map {
                Square(disk: disk, x: $0.0, y: $0.1)
            }
            state.boardState.updateByPartialSquares(squares)

            let placedSquare = PlacedSquare(disk: disk, x: x, y: y)
            let changedSquares = diskCoordinates.map {
                PlacedSquare(disk: disk, x: $0.0, y: $0.1)
            }
            state.squaresState = .init(
                placedSquare: placedSquare,
                changedSquares: changedSquares,
                squares: state.boardState.squares,
                animated: true)
            do {
                var player = state.player1
                player.count = state.boardState.count(of: .dark)
                state.player1 = player
            }
            do {
                var player = state.player2
                player.count = state.boardState.count(of: .light)
                state.player2 = player
            }
        case .changeSquares(let squares):
            state.boardState.updateByPartialSquares(squares)
        case .nextTurn:
            guard state.shouldShowCannotPlaceDisk == nil else { return state }
            guard let temp = state.side else { return state }
            let side = temp.flipped
            state.side = side
            if state.boardState.validMoves(for: side).isEmpty {
                if state.boardState.validMoves(for: side.flipped).isEmpty {
                    state.side = nil // GameOver
                } else {
                    state.shouldShowCannotPlaceDisk = .init()
                }
            }
        case .didShowCannotPlaceDisk:
            state.shouldShowCannotPlaceDisk = nil
        }
    }
    if let action = action as? AppPrivateAction {
         switch action {
         case .changePlayer(let side, let player):
            switch side {
            case .dark: state.player1.player = player
            case .light: state.player2.player = player
            }
         case .finisedLoadGame(let loadData):
            let boardState = BoardState(squares: loadData.squares.map { Square(disk: $0.disk, x: $0.x, y: $0.y) })
            state.isStaring = false
            state.side = loadData.side
            state.player1 = .init(side: .dark, player: loadData.player1, count: boardState.count(of: .dark))
            state.player2 = .init(side: .light, player: loadData.player2, count: boardState.count(of: .light))
            state.squaresState = .init(squares: boardState.squares)
            state.boardState = boardState
         case .finisedSaveGame:
            break
         case .resetAllState:
            var boardState = BoardState()
            let squares: [Square] = [
                .init(disk: .light, x: BoardConstant.width / 2 - 1, y: BoardConstant.height / 2 - 1),
                .init(disk: .dark, x: BoardConstant.width / 2, y: BoardConstant.height / 2 - 1),
                .init(disk: .dark, x: BoardConstant.width / 2 - 1, y: BoardConstant.height / 2),
                .init(disk: .light, x: BoardConstant.width / 2, y: BoardConstant.height / 2),
            ]
            boardState.updateByPartialSquares(squares)

            state.id = NSUUID().uuidString
            state.isStaring = true
            state.side = .dark
            state.boardState = boardState
            state.player1 = .init(side: .dark, count: boardState.count(of: .dark))
            state.player2 = .init(side: .light, count: boardState.count(of: .light))
            state.squaresState = .init(squares: boardState.squares)
            state.boardState = boardState
            state.computerThinking = .none
            state.shouldShowCannotPlaceDisk = nil
         case .startComputerThinking(let side):
            state.computerThinking = .thinking(side)
        case .endComputerThinking:
            state.computerThinking = .none
        }
    }
    return state
}

public struct Trigger: Equatable, Codable {
    let uuid: String = NSUUID().uuidString
}

public enum ComputerThinking: Equatable, Codable {
    case none
    case thinking(Disk)
}

public struct PlacedSquare: Equatable, Codable {
    public var disk: Disk
    public var x: Int
    public var y: Int
}

public struct Square: Equatable, Codable {
    public var disk: Disk?
    public var x: Int
    public var y: Int
    var index: Int { y * BoardConstant.width + x }
}

public struct SquaresState: StateType, Equatable, Codable {
    public var placedSquare: PlacedSquare? = nil
    public var changedSquares: [PlacedSquare] = []
    public var squares: [Square] = []
    public var animated: Bool = false
}

public struct PlayerState: StateType, Equatable, Codable {
    public var side: Disk
    public var player: Player = .manual
    public var count: Int = 0
}

struct BoardState: StateType, Equatable, Codable {
    var squares: [Square]

    init(squares: [Square]? = nil) {
        if let squares = squares {
            self.squares = squares
        } else {
            self.squares = (0 ..< BoardConstant.squaresCount).map {
                Square(x: $0 % BoardConstant.width, y: Int($0 / BoardConstant.width))
            }
        }
    }

    mutating func updateByPartialSquares(_ partialSquares: [Square]) {
        var origin = self.squares
        partialSquares.forEach { origin[$0.index] = $0 }
        self.squares = origin
    }

    func count(of disk: Disk) -> Int {
        var count = 0
        for y in BoardConstant.yRange {
            for x in BoardConstant.xRange {
                if squareAt(x: x, y: y)?.disk == disk {
                    count +=  1
                }
            }
        }
        return count
    }

    func squareAt(x: Int, y: Int) -> Square? {
        guard BoardConstant.xRange.contains(x) && BoardConstant.yRange.contains(y) else { return nil }
        return squares[y * BoardConstant.width + x]
    }
}

extension BoardState {
    func sideWithMoreDisks() -> Disk? {
        let darkCount = count(of: .dark)
        let lightCount = count(of: .light)
        if darkCount == lightCount {
            return nil
        } else {
            return darkCount > lightCount ? .dark : .light
        }
    }

    private func canPlaceDisk(_ disk: Disk, atX x: Int, y: Int) -> Bool {
        !flippedDiskCoordinatesByPlacingDisk(disk, atX: x, y: y).isEmpty
    }

    func validMoves(for side: Disk) -> [(x: Int, y: Int)] {
        var coordinates: [(Int, Int)] = []
        for y in BoardConstant.yRange {
            for x in BoardConstant.xRange {
                if canPlaceDisk(side, atX: x, y: y) {
                    coordinates.append((x, y))
                }
            }
        }
        return coordinates
    }

    func flippedDiskCoordinatesByPlacingDisk(_ disk: Disk, atX x: Int, y: Int) -> [(Int, Int)] {
        let directions = [
            (x: -1, y: -1),
            (x:  0, y: -1),
            (x:  1, y: -1),
            (x:  1, y:  0),
            (x:  1, y:  1),
            (x:  0, y:  1),
            (x: -1, y:  0),
            (x: -1, y:  1),
        ]

        guard squareAt(x: x, y: y)?.disk == nil else {
            return []
        }

        var diskCoordinates: [(Int, Int)] = []

        for direction in directions {
            var x = x
            var y = y

            var diskCoordinatesInLine: [(Int, Int)] = []
            flipping: while true {
                x += direction.x
                y += direction.y

                switch (disk, squareAt(x: x, y: y)?.disk) { // Uses tuples to make patterns exhaustive
                case (.dark, .some(.dark)), (.light, .some(.light)):
                    diskCoordinates.append(contentsOf: diskCoordinatesInLine)
                    break flipping
                case (.dark, .some(.light)), (.light, .some(.dark)):
                    diskCoordinatesInLine.append((x, y))
                case (_, .none):
                    break flipping
                }
            }
        }

        return diskCoordinates
    }
}

public let store = Store<AppState>(
    reducer: reducer,
    state: AppState(),
    middleware: [thunkMiddleware, loggingMiddleware]
)

struct ErrorAction: Action {
    let error: Error
    let title: String
    let message: String
}

public enum AppAction: Action {
    case placeDisk(disk: Disk, x: Int, y: Int)
    case changeSquares([Square])
    case nextTurn
    case didShowCannotPlaceDisk
}

enum AppPrivateAction: Action {
    case changePlayer(side: Disk, player: Player)
    case resetAllState
    case finisedLoadGame(LoadData)
    case startComputerThinking(Disk)
    case endComputerThinking
    case finisedSaveGame
}

extension AppAction {
    public static func newGame() -> Thunk<AppState> {
        return Thunk<AppState> { dispatch, getState, dependency in
            dispatch(AppPrivateAction.resetAllState)
            dispatch(AppAction.saveGame())
        }
    }

    public static func saveGame() -> Thunk<AppState> {
        return Thunk<AppState> { dispatch, getState, dependency in
            do {
                guard let state = getState() else { return }
                try dependency.persistentInteractor.saveGame(
                    side: state.side,
                    player1: state.player1,
                    player2: state.player2,
                    boardState: state.boardState)
                dispatch(AppPrivateAction.finisedSaveGame)
            } catch let error {
                dump(error)
                let title = "Error occurred."
                let message = "Cannot save games."
                dispatch(ErrorAction(error: error, title: title, message: message))
            }
        }
    }

    public static func loadGame() -> Thunk<AppState> {
        return Thunk<AppState> { dispatch, getState, dependency in
            do {
                dispatch(AppPrivateAction.resetAllState)
                let loadData = try dependency.persistentInteractor.loadGame()
                dispatch(AppPrivateAction.finisedLoadGame(loadData))
            } catch let error {
                dump(error)
                dispatch(AppAction.newGame())
            }
        }
    }

    public static func changePlayer(side: Disk, player: Player) -> Thunk<AppState> {
        return Thunk<AppState> { dispatch, getState, dependency in
            guard let appSate = getState() else { return }
            if case .manual = player {
                guard case .turn(let turn) = appSate.currentTurn else { return }
                if side == turn.side {
                    dispatch(AppPrivateAction.endComputerThinking)
                }
            }
            dispatch(AppPrivateAction.changePlayer(side: side, player: player))
            dispatch(AppAction.saveGame())
        }
    }

    public static func waitForPlayer() -> Thunk<AppState> {
        return Thunk<AppState> { dispatch, getState, dependency in
            guard let state = getState() else { return }
            switch state.currentTurn {
            case .start:
                break
            case .turn(let turn):
                switch turn.player {
                case .manual:
                    break
                case .computer:
                    dispatch(AppAction.playTurnOfComputer())
                }
            case .gameOverWon, .gameOverTied:
                break
            }
        }
    }

    private static func playTurnOfComputer() -> Thunk<AppState> {
        return Thunk<AppState> { dispatch, getState, dependencye in
            guard let state = getState() else { return }
            switch state.currentTurn {
            case .start:
                break
            case .turn(let turn):
                let candidates = state.boardState.validMoves(for: turn.side)
                if candidates.isEmpty {
                    dispatch(AppAction.nextTurn)
                    return
                }
                guard let (x, y) = candidates.randomElement() else { preconditionFailure() }
                let side = turn.side
                let id = state.id
                store.dispatch(AppPrivateAction.startComputerThinking(side))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.0) {
                    guard let appState = getState() else { return }
                    guard case .thinking = appState.computerThinking else { return }
                    guard id == appState.id else { return }
                    dispatch(AppAction.placeDisk(disk: side, x: x, y: y))
                    dispatch(AppPrivateAction.endComputerThinking)
                }
            case .gameOverWon, .gameOverTied:
                preconditionFailure()
            }
        }
    }
}

protocol Dependency {
    var persistentInteractor: PersistentInteractor { get }
}

struct DependencyImpl: Dependency {
    let persistentInteractor: PersistentInteractor

    init(persistentInteractor: PersistentInteractor = PersistentInteractorImpl()) {
        self.persistentInteractor = persistentInteractor
    }
}

let thunkMiddleware: Middleware<AppState> = createThunkMiddleware()

public struct Thunk<State>: Action {
    let body: (_ dispatch: @escaping DispatchFunction, _ getState: @escaping () -> State?, _ dependency: Dependency) -> Void
    init(body: @escaping (
        _ dispatch: @escaping DispatchFunction,
        _ getState: @escaping () -> State?,
        _ dependency: Dependency) -> Void) {
        self.body = body
    }
}

func createThunkMiddleware<State>(dependency: Dependency = DependencyImpl()) -> Middleware<State> {
    return { dispatch, getState in
        return { next in
            return { action in
                switch action {
                case let thunk as Thunk<State>:
                    thunk.body(dispatch, getState, dependency)
                default:
                    next(action)
                }
            }
        }
    }
}

let loggingMiddleware: Middleware<AppState> = { dispatch, getState in
    return { next in
        return { action in
            dump(action)
            return next(action)
        }
    }
}

extension ComputerThinking {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let value = try? container.decode(String.self, forKey: .none), value == CodingKeys.none.rawValue {
            self = .none
        } else if let value = try? container.decode(Disk.self, forKey: .thinking) {
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
