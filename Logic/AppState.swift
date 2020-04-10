import Foundation
import ReSwift
import ReSwift_Thunk

public struct Trigger: Equatable {
    let uuid: String = NSUUID().uuidString
}

public struct SquareStates: StateType, Equatable {
    public struct LastSquare: StateType, Equatable {
        public var disk: Disk
        public var x: Int
        public var y: Int
    }
    public let lastPlacedSquare: LastSquare?
    public let lastChangedSquares: [LastSquare]
    public let squareStates: [SquareState]
    public let animated: Bool
}


public struct PlayerState: StateType {
    private let boardState: BoardState

    public var side: Disk
    public var player: Player
    public var count: Int {
        boardState.count(of: side)
    }
    // var canPlayTurnOfComputer: Bool

    init(side: Disk, boardState: BoardState) {
        self.side = side
        self.player = .manual
        self.boardState = boardState
    }
}

public struct AppState: StateType {
    let persistentInteractor: PersistentInteractor
    var boardState: BoardState = .init()
    var side: Disk? = .dark
    var initial: Bool = false
    public var player1: PlayerState
    public var player2: PlayerState
    public var squareStates: SquareStates = .init(lastPlacedSquare: nil, lastChangedSquares: [], squareStates: [], animated: false)
    public var isComputerThinking: Bool = false
    public var currentTurn: CurrentTurn {
        if initial && !squareStates.squareStates.isEmpty {
            return CurrentTurn.initial(squareStates.squareStates)
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

    init(persistentInteractor: PersistentInteractor = PersistentInteractorImpl()) {
        self.persistentInteractor = persistentInteractor
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

    if let action = action as? AppAction {
        switch action {
        case .placeDisk(let disk, let x, let y):
            let diskCoordinates = state.boardState.flippedDiskCoordinatesByPlacingDisk(disk, atX: x, y: y)
            if diskCoordinates.isEmpty {

            } else {
                let squares = [SquareState(disk: disk, x: x, y: y)] + diskCoordinates.map {
                    SquareState(disk: disk, x: $0.0, y: $0.1)
                }
                squares.forEach {
                    state.boardState.setDisk($0.disk, atX: $0.x, y: $0.y)
                }

                let lastSquareState = SquareStates.LastSquare(disk: disk, x: x, y: y)
                let lastChangedSquares = diskCoordinates.map {
                    SquareStates.LastSquare(disk: disk, x: $0.0, y: $0.1)
                }
                state.squareStates = SquareStates(
                    lastPlacedSquare: lastSquareState,
                    lastChangedSquares: lastChangedSquares,
                    squareStates: state.boardState.squareStates,
                    animated: true)
            }
        case .changeSquares(let squares):
            squares.forEach {
                state.boardState.setDisk($0.disk, atX: $0.x, y: $0.y)
            }
        case .nextTurn:
            guard let temp = state.side else { return state }
            let side = temp.flipped
            state.side = side

            if state.boardState.validMoves(for: side).isEmpty {
                if state.boardState.validMoves(for: side.flipped).isEmpty {
                    // GameOver
                    state.side = nil
                } else {
                    state.shouldShowCannotPlaceDisk = .init()
                }
            } else {
                // FIXME:
                // waitForPlayer()
            }
        case .didShowCannotPlaceDisk:
            state.shouldShowCannotPlaceDisk = nil
        case .gameStart:
            state.initial = false
        case .gameOver:
            state.side = nil
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
             state.side = .dark
         case .finisedSaveGame:
             break
         case .resetAllState:
            let boardState = BoardState.reducer(action: action, state: state.boardState)
            state.side = .dark
            state.boardState = boardState
            state.player1 = .init(side: .dark, boardState: boardState)
            state.player2 = .init(side: .light, boardState: boardState)
            state.initial = true
            state.squareStates = SquareStates(
                lastPlacedSquare: nil,
                lastChangedSquares: [],
                squareStates: state.boardState.squareStates,
                animated: false)

        case .startComputerThinking:
            state.isComputerThinking = true
        case .endComputerThinking:
           state.isComputerThinking = false
        }
    }
    return state
}

extension BoardState {
    static func reducer(action: Action, state: BoardState) -> BoardState {
        var state = state

        if let action = action as? AppPrivateAction {
             switch action {
             case .finisedLoadGame(let loadData):
                break
             case .finisedSaveGame:
                break
             case .resetAllState:
                for y in BoardConstant.yRange {
                    for x in BoardConstant.xRange {
                        state.setDisk(nil, atX: x, y: y)
                    }
                }
                state.setDisk(.light, atX: BoardConstant.width / 2 - 1, y: BoardConstant.height / 2 - 1)
                state.setDisk(.dark, atX: BoardConstant.width / 2, y: BoardConstant.height / 2 - 1)
                state.setDisk(.dark, atX: BoardConstant.width / 2 - 1, y: BoardConstant.height / 2)
                state.setDisk(.light, atX: BoardConstant.width / 2, y: BoardConstant.height / 2)
             case .changePlayer:
                break
            case .startComputerThinking:
                break
            case .endComputerThinking:
                break
            }
        }
        return state
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
    case changeSquares([SquareState])
    case nextTurn
    case gameStart
    case gameOver
    case didShowCannotPlaceDisk
}

enum AppPrivateAction: Action {
    case changePlayer(side: Disk, player: Player)
    case resetAllState
    case finisedLoadGame(LoadData)
    case startComputerThinking
    case endComputerThinking
    case finisedSaveGame
}

extension AppAction {
    public static func newGame() -> Thunk<AppState> {
        return Thunk<AppState> { dispatch, getState in
            dispatch(AppPrivateAction.resetAllState)
            dispatch(AppAction.saveGame())
        }
    }

    public static func saveGame() -> Thunk<AppState> {
        return Thunk<AppState> { dispatch, getState in
            do {
                guard let state = getState() else { return }
                // FIXME:
                // try state.persistentInteractor.saveGame(side: state.side, playersState: state.playersState, boardState: state.boardState)
                dispatch(AppPrivateAction.finisedSaveGame)
            } catch let error {
                let title = "Error occurred."
                let message = "Cannot save games."
                dispatch(ErrorAction(error: error, title: title, message: message))
            }
        }
    }

    public static func loadGame() -> Thunk<AppState> {
        return Thunk<AppState> { dispatch, getState in
            do {
                guard let state = getState() else { return }
                dispatch(AppPrivateAction.resetAllState)
                let loadData = try state.persistentInteractor.loadGame()
                dispatch(AppPrivateAction.finisedLoadGame(loadData))
            } catch let error {
                dump(error)
                dispatch(AppAction.newGame())
            }
        }
    }

    public static func changePlayer(side: Disk, player: Player) -> Thunk<AppState> {
        return Thunk<AppState> { dispatch, getState in
            dispatch(AppPrivateAction.changePlayer(side: side, player: player))
            dispatch(AppAction.saveGame())
        }
    }

    public static func playTurnOfComputer() -> Thunk<AppState> {
        return Thunk<AppState> { dispatch, getState in
            guard let state = getState() else { return }
            switch state.currentTurn {
            case .turn(let turn):
                let candidates = state.boardState.validMoves(for: turn.side)
                if candidates.isEmpty {
                    dispatch(AppAction.nextTurn)
                    return
                }
                guard let (x, y) = candidates.randomElement() else { preconditionFailure() }
                let side = turn.side
//                let cleanUp: Canceller.CleanUp = { [weak self] in
//                    self?.playerActivityIndicators[side.index].stopAnimating()
//                }
///                let canceller = animationState.createAnimationCanceller(at: side, cleanUp: cleanUp)
                store.dispatch(AppPrivateAction.startComputerThinking)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
//                    if canceller.isCancelled { return }
//                    canceller.cancel()

                    store.dispatch(AppPrivateAction.endComputerThinking) // FIXME:
                    store.dispatch(AppAction.placeDisk(disk: side, x: x, y: y))
                }
            case .initial, .gameOverWon, .gameOverTied:
                preconditionFailure()
            }
        }
    }
}

let thunkMiddleware: Middleware<AppState> = createThunkMiddleware()

let loggingMiddleware: Middleware<AppState> = { dispatch, getState in
    return { next in
        return { action in
            dump(action)
            return next(action)
        }
    }
}

extension Disk {
    var flipped: Disk {
        switch self {
        case .dark: return .light
        case .light: return .dark
        }
    }
}
