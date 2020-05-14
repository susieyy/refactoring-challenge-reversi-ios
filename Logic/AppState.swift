import Foundation
import ReSwift

public struct AppState: StateType, Codable {
    public var boardContainer: BoardContainer
    public var playerDark: PlayerSide = .init(side: .sideDark)
    public var playerLight: PlayerSide = .init(side: .sideLight)
    public var gameProgress: GameProgress {
        if isInitialing {
            return .initialing
        } else if cannotPlaceDiskAlert != .none {
            return .interrupt(.cannotPlaceDisk(cannotPlaceDiskAlert))
        } else if resetConfrmationAlert != .none {
            return .interrupt(.resetConfrmation(resetConfrmationAlert))
        } else if let side = side {
            let progress: Progress = turnStart ? .start : .progressing
            let player: Player
            switch side {
            case .sideDark: player = playerDark.player
            case .sideLight: player = playerLight.player
            }
            return .turn(progress, side, player, computerThinking)
        } else if let winnerSide = boardContainer.board.sideWithMoreDisks() {
            return .gameOver(.won(winnerSide))
        } else {
            return .gameOver(.tied)
        }
    }

    var id: String = NSUUID().uuidString // prevent override uing reseted state
    var side: Side? = .sideDark
    var turnStart: Bool = false
    var isInitialing: Bool = true
    var isLoadedGame: Bool = false // prevent duplicate load game calls
    var computerThinking: ComputerThinking = .none
    var cannotPlaceDiskAlert: Alert = .none
    var resetConfrmationAlert: Alert = .none

    init(boardSetting: BoardSetting = .init(cols: 8, rows: 8)) {
        self.boardContainer = .init(diskCoordinatesState: Board(boardSetting: boardSetting))
    }
}

func reducer(action: Action, state: AppState?) -> AppState {
    var state = state ?? .init()

    if state.turnStart {
        state.turnStart = false
    }

    if let action = action as? AppAction {
        switch action {
        case .startGame:
            state.isInitialing = false
        case .placeDisk(let placedDiskCoordinate):
            let flippedDiskCoordinates = state.boardContainer.board.flippedDiskCoordinatesByPlacingDisk(placedDiskCoordinate)
            guard !flippedDiskCoordinates.isEmpty else { return state }

            let changed: BoardChanged = .init(placedDiskCoordinate: placedDiskCoordinate, flippedDiskCoordinates: flippedDiskCoordinates)
            changed.changedDiskCoordinate.forEach { state.boardContainer.board[$0.coordinate] = $0.optionalDiskCoordinate }
            state.boardContainer.changed = changed
            state.playerDark.count = state.boardContainer.board.count(of: .diskDark)
            state.playerLight.count = state.boardContainer.board.count(of: .diskLight)
        case .cannotPlaceDisk(let alert):
            state.cannotPlaceDiskAlert = alert
        case .resetConfirmation(let alert):
            state.resetConfrmationAlert = alert
        }
    }
    if let action = action as? AppPrivateAction {
        switch action {
        case .nextTurn:
            guard case .none = state.resetConfrmationAlert else { return state }
            guard let temp = state.side else { assertionFailure(); return state }
            state.cannotPlaceDiskAlert = .none
            let side = temp.flipped
            state.side = side
        case .validateTurn:
            guard let side = state.side else { return state }
            if state.boardContainer.board.validMoves(for: side).isEmpty {
                if state.boardContainer.board.validMoves(for: side.flipped).isEmpty {
                    state.side = nil // GameOver
                } else {
                    state.cannotPlaceDiskAlert = .shouldShow
                }
            } else {
                state.turnStart = true
            }
        case .changePlayer(let side, let player):
            switch side {
            case .sideDark: state.playerDark.player = player
            case .sideLight: state.playerLight.player = player
            }
            state.turnStart = true
            if side == state.side {
                state.computerThinking = .none
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
        case .startComputerThinking:
            state.computerThinking = .thinking
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
    case startGame
    case placeDisk(PlacedDiskCoordinate)
    case cannotPlaceDisk(Alert)
    case resetConfirmation(Alert)
}

enum AppPrivateAction: Action {
    case nextTurn
    case validateTurn
    case changePlayer(side: Side, player: Player)
    case resetAllState
    case finisedLoadGame(AppState)
    case startComputerThinking
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
                guard var state = getState() else { preconditionFailure() }
                state.isInitialing = true
                state.boardContainer.changed = nil
                state.computerThinking = .none
                state.resetConfrmationAlert = .none
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
            print("- Logic.AppAction.loadGame() START")
            do {
                guard let state = getState() else { preconditionFailure() }
                guard state.isLoadedGame == false else { return } // prevent duplicate load game calls
                dispatch(AppPrivateAction.resetAllState)
                let loadData = try dependency.persistentInteractor.loadGame()
                dispatch(AppPrivateAction.finisedLoadGame(loadData))
                dispatch(AppPrivateAction.validateTurn)
            } catch let error {
                dump(error)
                dispatch(AppAction.newGame())
            }
            print("- Logic.AppAction.loadGame() END")
        }
    }

    public static func nextTurn() -> Thunk<AppState> {
        return Thunk<AppState> { dispatch, getState, dependency in
            guard let state = getState() else { preconditionFailure() }
            if case .turn(_, let side, _, _) = state.gameProgress {
                print("- Logic.AppAction.nextTurn() from: \(side) to: \(side.flipped)")
            }
            dispatch(AppPrivateAction.nextTurn)
            dispatch(AppPrivateAction.validateTurn)
        }
    }

    public static func changePlayer(side: Side, player: Player) -> Thunk<AppState> {
        return Thunk<AppState> { dispatch, getState, dependency in
            print("- Logic.AppAction.changePlayer(side: \(side), player: \(player)) START")
            dispatch(AppPrivateAction.changePlayer(side: side, player: player))
            dispatch(AppAction.saveGame())
            print("- Logic.AppAction.changePlayer(side: \(side), player: \(player)) END")
        }
    }

    public static func waitForPlayer() -> Thunk<AppState> {
        return Thunk<AppState> { dispatch, getState, dependency in
            print("- Logic.AppAction.waitForPlayer() START")
            guard let state = getState() else { preconditionFailure() }
            switch state.gameProgress {
            case .turn(_, _, let player, _):
                switch player {
                case .manual:
                    break
                case .computer:
                    dispatch(AppAction.playTurnOfComputer())
                }
            case .initialing, .interrupt, .gameOver:
                assertionFailure()
            }
            print("- Logic.AppAction.waitForPlayer() END")
        }
    }

    private static func playTurnOfComputer() -> Thunk<AppState> {
        return Thunk<AppState> { dispatch, getState, dependency in
            print("- Logic.AppAction.playTurnOfComputer() START")
            guard let state = getState() else { preconditionFailure() }
            switch state.gameProgress {
            case .turn(_, let side, _, _):
                let candidates = state.boardContainer.board.validMoves(for: side)
                switch candidates.isEmpty {
                case true:
                    dispatch(AppAction.nextTurn())
                case false:
                    guard let candidate = candidates.randomElement() else { preconditionFailure() }
                    let id = state.id
                    store.dispatch(AppPrivateAction.startComputerThinking)
                    DispatchQueue.main.asyncAfter(deadline: .now() + dependency.computerThinkingTime) {
                        guard let state = getState() else { preconditionFailure() }
                        guard id == state.id else { return } // maybe reset game
                        guard case .turn(_, let sideEnd, _, let computerThinkingEnd) = state.gameProgress else { return }
                        guard case .thinking = computerThinkingEnd, side == sideEnd else { return } // maybe chaned to manual player
                        guard case .none = state.resetConfrmationAlert else { return }
                        dispatch(AppPrivateAction.endComputerThinking)
                        dispatch(AppAction.placeDisk(candidate))
                    }
                }
            case .initialing, .interrupt, .gameOver:
                assertionFailure()
            }
            print("- Logic.AppAction.playTurnOfComputer() END")
        }
    }
}

protocol Dependency {
    var persistentInteractor: PersistentInteractor { get }
    var computerThinkingTime: DispatchTimeInterval { get }
}

struct DependencyImpl: Dependency {
    let persistentInteractor: PersistentInteractor
    let computerThinkingTime: DispatchTimeInterval

    init(persistentInteractor: PersistentInteractor = PersistentInteractorImpl(), computerThinkingTime: DispatchTimeInterval = DispatchTimeInterval.milliseconds(1000)) {
        self.persistentInteractor = persistentInteractor
        self.computerThinkingTime = computerThinkingTime
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
            if case AppPrivateAction.validateTurn = action {
                print(getState()?.boardContainer.board.debugDescription ?? "N/A")
            }
            return next(action)
        }
    }
}
