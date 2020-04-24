import Foundation
import ReSwift

public struct AppState: StateType, Codable {
    public var playerDark: PlayerSide = .init(side: .sideDark)
    public var playerLight: PlayerSide = .init(side: .sideLight)
    public var boardState: BoardState = .init()
    public var computerThinking: ComputerThinking = .none
    public var currentTurn: CurrentTurn {
        if isStaring {
            return CurrentTurn.start
        } else if let side = side {
            switch side {
            case .sideDark: return CurrentTurn.turn(playerDark)
            case .sideLight: return CurrentTurn.turn(playerLight)
            }
        } else if let winnerSide = boardState.squaresState.sideWithMoreDisks() {
            switch winnerSide {
            case .sideDark: return CurrentTurn.gameOverWon(playerDark)
            case .sideLight: return CurrentTurn.gameOverWon(playerLight)
            }
        } else {
            return CurrentTurn.gameOverTied
        }
    }
    public var shouldShowCannotPlaceDisk: Trigger?
    public var isShowingRestConfrmation: Bool = false

    var id: String = NSUUID().uuidString
    var side: Side? = .sideDark
    var isStaring: Bool = false
}

func reducer(action: Action, state: AppState?) -> AppState {
    var state = state ?? .init()
    state.isStaring = false

//    let data = try! JSONEncoder().encode(state)
//    print(String(data: data, encoding: String.Encoding.utf8)!)
//
//    let decoded = try! JSONDecoder().decode(AppState.self, from: data)
//    print(decoded)


    if let action = action as? AppAction {
        switch action {
        case .placeDisk(let disk, let x, let y):
            let diskCoordinates = state.boardState.squaresState.flippedDiskCoordinatesByPlacingDisk(disk, atX: x, y: y)
            guard !diskCoordinates.isEmpty else { return state }
            let changedSquares = diskCoordinates.map { PlacedSquare(disk: disk, x: $0.0, y: $0.1) }
            var squaresState = state.boardState.squaresState
            let squares = [Square(disk: disk, x: x, y: y)] + diskCoordinates.map { Square(disk: disk, x: $0.0, y: $0.1) }
            squaresState.updateByPartialSquares(squares)
            state.boardState = .init(squaresState: squaresState, placedSquare: PlacedSquare(disk: disk, x: x, y: y), changedSquares: changedSquares, animated: true)
            state.playerDark.count = state.boardState.squaresState.count(of: .diskDark)
            state.playerLight.count = state.boardState.squaresState.count(of: .diskLight)
        case .changeSquares(let squares):
            state.boardState.squaresState.updateByPartialSquares(squares)
        case .nextTurn:
            guard state.shouldShowCannotPlaceDisk == nil else { return state }
            guard state.isShowingRestConfrmation == false else { return state }
            guard let temp = state.side else { return state }
            let side = temp.flipped
            state.side = side
            if state.boardState.squaresState.validMoves(for: side).isEmpty {
                if state.boardState.squaresState.validMoves(for: side.flipped).isEmpty {
                    state.side = nil // GameOver
                } else {
                    state.shouldShowCannotPlaceDisk = .init()
                }
            }
        case .didShowCannotPlaceDisk:
            state.shouldShowCannotPlaceDisk = nil
        case .showingConfirmation(let isShowing):
            state.isShowingRestConfrmation = isShowing
        }
    }
    if let action = action as? AppPrivateAction {
         switch action {
         case .changePlayer(let side, let player):
            switch side {
            case .sideDark: state.playerDark.player = player
            case .sideLight: state.playerLight.player = player
            }
         case .resetAllState:
            var newState = AppState()
            newState.isStaring = true
            newState.boardState = .init()
            newState.playerDark = .init(side: .sideDark, count: newState.boardState.squaresState.count(of: .diskDark))
            newState.playerLight = .init(side: .sideLight, count: newState.boardState.squaresState.count(of: .diskLight))
            return newState
         case .finisedLoadGame(let loadData):
            var newState = AppState()
            newState.side = loadData.side
            newState.boardState = .init(squaresState: SquaresState(squares: loadData.squares.map { Square(disk: $0.disk, x: $0.x, y: $0.y) }))
            newState.playerDark = .init(player: loadData.player1, side: .sideDark, count: newState.boardState.squaresState.count(of: .diskDark))
            newState.playerLight = .init(player: loadData.player2, side: .sideLight, count: newState.boardState.squaresState.count(of: .diskLight))
            return newState
         case .finisedSaveGame:
            break
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
    case thinking(Side)
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

public struct PlayerSide: StateType, Equatable, Codable {
    public var player: Player = .manual
    public var side: Side
    public var count: Int = 0
}

let boardStateInital: [Square] = [
    .init(disk: .diskLight, x: BoardConstant.width / 2 - 1, y: BoardConstant.height / 2 - 1),
    .init(disk: .diskDark, x: BoardConstant.width / 2, y: BoardConstant.height / 2 - 1),
    .init(disk: .diskDark, x: BoardConstant.width / 2 - 1, y: BoardConstant.height / 2),
    .init(disk: .diskLight, x: BoardConstant.width / 2, y: BoardConstant.height / 2),
]

public struct BoardState: StateType, Equatable, Codable {
    var squaresState: SquaresState
    public var squares: [Square] { squaresState.squares }
    public var placedSquare: PlacedSquare?
    public var changedSquares: [PlacedSquare]
    public var animated: Bool

    init(squaresState: SquaresState = .init(), placedSquare: PlacedSquare? = nil, changedSquares: [PlacedSquare] = [], animated: Bool = false) {
        self.squaresState = squaresState
        self.placedSquare = placedSquare
        self.animated = animated
        self.changedSquares = changedSquares
    }
}

public struct SquaresState: StateType, Equatable, Codable {
    public var squares: [Square]

    init(squares: [Square] = boardStateInital) {
        var temp: [Square] = (0 ..< BoardConstant.squaresCount).map {
            Square(x: $0 % BoardConstant.width, y: Int($0 / BoardConstant.width))
        }
        squares.forEach { temp[$0.index] = $0 }
        self.squares = temp
    }
}

extension SquaresState {
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

extension SquaresState {
    func sideWithMoreDisks() -> Side? {
        let darkCount = count(of: .diskDark)
        let lightCount = count(of: .diskLight)
        if darkCount == lightCount {
            return nil
        } else {
            return darkCount > lightCount ? .sideDark : .sideLight
        }
    }

    private func canPlaceDisk(_ disk: Disk, atX x: Int, y: Int) -> Bool {
        !flippedDiskCoordinatesByPlacingDisk(disk, atX: x, y: y).isEmpty
    }

    func validMoves(for side: Side) -> [(x: Int, y: Int)] {
        var coordinates: [(Int, Int)] = []
        for y in BoardConstant.yRange {
            for x in BoardConstant.xRange {
                if canPlaceDisk(side.disk, atX: x, y: y) {
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
                case (.diskDark, .some(.diskDark)), (.diskLight, .some(.diskLight)):
                    diskCoordinates.append(contentsOf: diskCoordinatesInLine)
                    break flipping
                case (.diskDark, .some(.diskLight)), (.diskLight, .some(.diskDark)):
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
    case showingConfirmation(Bool)
}

enum AppPrivateAction: Action {
    case changePlayer(side: Side, player: Player)
    case resetAllState
    case finisedLoadGame(LoadData)
    case startComputerThinking(Side)
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
                    player1: state.playerDark,
                    player2: state.playerLight,
                    squaresState: state.boardState.squaresState)
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

    public static func changePlayer(side: Side, player: Player) -> Thunk<AppState> {
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
                let candidates = state.boardState.squaresState.validMoves(for: turn.side)
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
                    dispatch(AppAction.placeDisk(disk: side.disk, x: x, y: y))
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
