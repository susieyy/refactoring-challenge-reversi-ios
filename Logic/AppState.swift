import Foundation
import ReSwift

public struct AppState: StateType, Codable {
    public var boardContainer: BoardContainer
    public var playerDark: PlayerSide = .init(side: .sideDark)
    public var playerLight: PlayerSide = .init(side: .sideLight)
    public var computerThinking: ComputerThinking = .none
    public var shouldShowCannotPlaceDisk: Trigger?
    public var isShowingRestConfrmation: Bool = false
    public var currentTurn: CurrentTurn {
        if isInitialing {
            return .initialing
        } else if let side = side {
            switch side {
            case .sideDark: return .turn(side, playerDark.player)
            case .sideLight: return .turn(side, playerLight.player)
            }
        } else if let winnerSide = boardContainer.board.sideWithMoreDisks() {
            return .gameOverWon(winnerSide)
        } else {
            return .gameOverTied
        }
    }

    var id: String = NSUUID().uuidString // prevent override uing reseted state
    var side: Side? = .sideDark
    var isInitialing: Bool = true
    var isLoadedGame: Bool = false // prevent duplicate load game calls

    init(boardSetting: BoardSetting = .init(cols: 8, rows: 8)) {
        self.boardContainer = .init(diskCoordinatesState: Board(boardSetting: boardSetting))
    }
}

func reducer(action: Action, state: AppState?) -> AppState {
    var state = state ?? .init()

    if let action = action as? AppAction {
        switch action {
        case .start:
            state.isInitialing = false
        case .placeDisk(let placedDiskCoordinate):
            let flippedDiskCoordinates = state.boardContainer.board.flippedDiskCoordinatesByPlacingDisk(placedDiskCoordinate)
            guard !flippedDiskCoordinates.isEmpty else { return state }

            let changed: BoardChanged = .init(placedDiskCoordinate: placedDiskCoordinate, flippedDiskCoordinates: flippedDiskCoordinates)
            changed.changedDiskCoordinate.forEach { state.boardContainer.board[$0.coordinate] = $0.optionalDiskCoordinate }
            state.boardContainer.changed = changed
            state.playerDark.count = state.boardContainer.board.count(of: .diskDark)
            state.playerLight.count = state.boardContainer.board.count(of: .diskLight)
        case .didShowCannotPlaceDisk:
            state.shouldShowCannotPlaceDisk = nil
        case .showingConfirmation(let isShowing):
            state.isShowingRestConfrmation = isShowing
        }
    }
    if let action = action as? AppPrivateAction {
         switch action {
         case .nextTurn:
             guard state.shouldShowCannotPlaceDisk == nil else { return state }
             guard state.isShowingRestConfrmation == false else { return state }
             guard let temp = state.side else { return state }
             let side = temp.flipped
             state.side = side
             guard state.boardContainer.board.validMoves(for: side).isEmpty else { return state }
             if state.boardContainer.board.validMoves(for: side.flipped).isEmpty {
                 state.side = nil // GameOver
             } else {
                 state.shouldShowCannotPlaceDisk = .init()
             }
         case .changePlayer(let side, let player):
            switch side {
            case .sideDark: state.playerDark.player = player
            case .sideLight: state.playerLight.player = player
            }
         case .resetAllState:
            var newState = AppState()
            newState.playerDark = .init(side: .sideDark, count: newState.boardContainer.board.count(of: .diskDark))
            newState.playerLight = .init(side: .sideLight, count: newState.boardContainer.board.count(of: .diskLight))
            return newState
         case .finisedLoadGame(let loadedAppState):
            return loadedAppState
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
    case start
    case placeDisk(PlacedDiskCoordinate)
    case didShowCannotPlaceDisk
    case showingConfirmation(Bool)
}

enum AppPrivateAction: Action {
    case nextTurn
    case changePlayer(side: Side, player: Player)
    case resetAllState
    case finisedLoadGame(AppState)
    case startComputerThinking(Side)
    case endComputerThinking
    case finisedSaveGame
}

extension AppAction {
    public static func newGame() -> Thunk<AppState> {
        return Thunk<AppState> { dispatch, getState, dependency in
            print("- Logic.AppAction.newGame() START")
            dispatch(AppPrivateAction.resetAllState)
            dispatch(AppAction.saveGame())
            print("- Logic.AppAction.newGame() END")
        }
    }

    public static func saveGame() -> Thunk<AppState> {
        return Thunk<AppState> { dispatch, getState, dependency in
            print("- Logic.AppAction.saveGame() START")
            do {
                guard var state = getState() else { return }
                state.isInitialing = true
                state.boardContainer.changed = nil
                state.computerThinking = .none
                state.isShowingRestConfrmation = false
                try dependency.persistentInteractor.saveGame(state)
                dispatch(AppPrivateAction.finisedSaveGame)
            } catch let error {
                dump(error)
                let title = "Error occurred."
                let message = "Cannot save games."
                dispatch(ErrorAction(error: error, title: title, message: message))
            }
            print("- Logic.AppAction.saveGame() END")
        }
    }

    public static func loadGame() -> Thunk<AppState> {
        return Thunk<AppState> { dispatch, getState, dependency in
            guard getState()?.isLoadedGame == false else { return }
            print("- Logic.AppAction.loadGame() START")
            do {
                dispatch(AppPrivateAction.resetAllState)
                let loadData = try dependency.persistentInteractor.loadGame()
                dispatch(AppPrivateAction.finisedLoadGame(loadData))
            } catch let error {
                dump(error)
                dispatch(AppAction.newGame())
            }
            print("- Logic.AppAction.loadGame() END")
        }
    }

    public static func nextTurn() -> Thunk<AppState> {
        return Thunk<AppState> { dispatch, getState, dependency in
            guard let appSate = getState() else { return }
            if case .turn(let side, _) = appSate.currentTurn {
                print("- Logic.AppAction.nextTurn() from: \(side) to: \(side.flipped)")
            }
            dispatch(AppPrivateAction.nextTurn)
        }
    }

    public static func changePlayer(side: Side, player: Player) -> Thunk<AppState> {
        return Thunk<AppState> { dispatch, getState, dependency in
            print("- Logic.AppAction.changePlayer(side: \(side), player: \(player)) START")
            guard let appSate = getState() else { return }
            if case .manual = player {
                guard case .turn(let currentSide, _) = appSate.currentTurn else { return }
                if side == currentSide {
                    dispatch(AppPrivateAction.endComputerThinking)
                }
            }
            dispatch(AppPrivateAction.changePlayer(side: side, player: player))
            dispatch(AppAction.saveGame())
            print("- Logic.AppAction.changePlayer(side: \(side), player: \(player)) END")
        }
    }

    public static func waitForPlayer() -> Thunk<AppState> {
        return Thunk<AppState> { dispatch, getState, dependency in
            print("- Logic.AppAction.waitForPlayer() START")
            guard let state = getState() else { return }
            switch state.currentTurn {
            case .initialing:
                break
            case .turn(_, let player):
                switch player {
                case .manual:
                    break
                case .computer:
                    dispatch(AppAction.playTurnOfComputer())
                }
            case .gameOverWon, .gameOverTied:
                preconditionFailure()
            }
            print("- Logic.AppAction.waitForPlayer() END")
        }
    }

    private static func playTurnOfComputer() -> Thunk<AppState> {
        return Thunk<AppState> { dispatch, getState, dependencye in
            print("- Logic.AppAction.playTurnOfComputer() START")
            guard let state = getState() else { return }
            if case .thinking = state.computerThinking {
                return
            }

            switch state.currentTurn {
            case .initialing:
                break
            case .turn(let side, _):
                let candidates = state.boardContainer.board.validMoves(for: side)
                switch candidates.isEmpty {
                case true:
                    dispatch(AppAction.nextTurn())
                case false:
                    guard let candidate = candidates.randomElement() else { preconditionFailure() }
                    let id = state.id
                    store.dispatch(AppPrivateAction.startComputerThinking(side))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        defer {
                            dispatch(AppPrivateAction.endComputerThinking)
                        }
                        guard let appState = getState() else { return }
                        guard case .thinking = appState.computerThinking else { return }
                        guard id == appState.id else { return }
                        dispatch(AppAction.placeDisk(candidate))
                    }
                }
            case .gameOverWon, .gameOverTied:
                preconditionFailure()
            }
            print("- Logic.AppAction.playTurnOfComputer() END")
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
