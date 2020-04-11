import Foundation
import ReSwift

public struct Trigger: Equatable {
    let uuid: String = NSUUID().uuidString
}

public enum ComputerThinkingState: StateType, Equatable {
    case none
    case thinking(Disk)
}

public struct SquareStates: StateType, Equatable {
    public struct PlacedSquare: StateType, Equatable {
        public var disk: Disk
        public var x: Int
        public var y: Int
    }
    public let lastPlacedSquare: PlacedSquare?
    public let lastChangedSquares: [PlacedSquare]
    public let squareStates: [Square]
    public let animated: Bool
}

public struct PlayerState: StateType {
    private let boardState: BoardState
    public var side: Disk
    public var player: Player
    public var count: Int { boardState.count(of: side) }

    init(side: Disk, player: Player = .manual, boardState: BoardState) {
        self.side = side
        self.player = player
        self.boardState = boardState
    }
}

public struct AppState: StateType {
    var boardState: BoardState = .init()
    var side: Disk? = .dark
    var isStaring: Bool = false
    public var player1: PlayerState
    public var player2: PlayerState
    public var squareStates: SquareStates = .init(lastPlacedSquare: nil, lastChangedSquares: [], squareStates: [], animated: false)
    public var computerThinking: ComputerThinkingState = .none
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

    init() {
        self.player1 = .init(side: .dark, boardState: boardState)
        self.player2 = .init(side: .light, boardState: boardState)
    }

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

    if let action = action as? AppAction {
        switch action {
        case .placeDisk(let disk, let x, let y):
            let diskCoordinates = state.boardState.flippedDiskCoordinatesByPlacingDisk(disk, atX: x, y: y)
            if diskCoordinates.isEmpty {

            } else {
                let squares = [Square(disk: disk, x: x, y: y)] + diskCoordinates.map {
                    Square(disk: disk, x: $0.0, y: $0.1)
                }
                squares.forEach {
                    state.boardState.setDisk($0.disk, atX: $0.x, y: $0.y)
                }

                let lastSquareState = SquareStates.PlacedSquare(disk: disk, x: x, y: y)
                let lastChangedSquares = diskCoordinates.map {
                    SquareStates.PlacedSquare(disk: disk, x: $0.0, y: $0.1)
                }
                state.squareStates = .init(
                    lastPlacedSquare: lastSquareState,
                    lastChangedSquares: lastChangedSquares,
                    squareStates: state.boardState.squares,
                    animated: true)
            }
        case .changeSquares(let squares):
            squares.forEach {
                state.boardState.setDisk($0.disk, atX: $0.x, y: $0.y)
            }
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
            state.player1 = .init(side: .dark, player: loadData.player1, boardState: boardState)
            state.player2 = .init(side: .light, player: loadData.player2, boardState: boardState)
            state.squareStates = .init(
                lastPlacedSquare: nil,
                lastChangedSquares: [],
                squareStates: boardState.squares,
                animated: false)
            state.boardState = boardState
         case .finisedSaveGame:
            break
         case .resetAllState:
            let boardState = BoardState()
            for y in BoardConstant.yRange {
                for x in BoardConstant.xRange {
                    boardState.setDisk(nil, atX: x, y: y)
                }
            }
            boardState.setDisk(.light, atX: BoardConstant.width / 2 - 1, y: BoardConstant.height / 2 - 1)
            boardState.setDisk(.dark, atX: BoardConstant.width / 2, y: BoardConstant.height / 2 - 1)
            boardState.setDisk(.dark, atX: BoardConstant.width / 2 - 1, y: BoardConstant.height / 2)
            boardState.setDisk(.light, atX: BoardConstant.width / 2, y: BoardConstant.height / 2)

            state.isStaring = true
            state.side = .dark
            state.boardState = boardState
            state.player1 = .init(side: .dark, boardState: boardState)
            state.player2 = .init(side: .light, boardState: boardState)
            state.squareStates = .init(
                lastPlacedSquare: nil,
                lastChangedSquares: [],
                squareStates: boardState.squares,
                animated: false)
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
            if case .manual = player {
                dispatch(AppPrivateAction.endComputerThinking)
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
                store.dispatch(AppPrivateAction.startComputerThinking(side))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.0) {
                    guard let appState = getState() else { return }
                    guard case .thinking = appState.computerThinking else { return }
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
