import Foundation
import ReSwift
import ReSwift_Thunk

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
    public var initial: Bool = true
    public var player1: PlayerState
    public var player2: PlayerState
    public var squareStates: [SquareState] { boardState.squareStates }
    public var nextTurn: Turn?
    public var currentTurn: CurrentTurn {
        if let side = side {
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
        case .nextTurn:
            if let temp = state.side {
                let side = temp.flipped
                state.side = side
                let player = state.player(at: side)
                state.nextTurn = Turn(side: side, player: player)
            }
        case .changePlayer(let side, let player):
            switch side {
            case .dark: state.player1.player = player
            case .light: state.player2.player = player
            }
        case .gameOver:
            state.side = nil
        }
    }
    if let action = action as? AppPrivateAction {
         switch action {
         case .loadGame(let loadData):
             state.side = .dark
         case .finisedSaveGame:
             break
         case .resetAllState:
            let boardState = BoardState.reducer(action: action, state: state.boardState)
            state.side = .dark
            state.boardState = boardState
            state.player1 = .init(side: .dark, boardState: boardState)
            state.player2 = .init(side: .light, boardState: boardState)
        }
    }
    return state
}

extension BoardState {
    static func reducer(action: Action, state: BoardState) -> BoardState {
        var state = state

        if let action = action as? AppPrivateAction {
             switch action {
             case .loadGame(let loadData):
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
    case nextTurn
    case changePlayer(side: Disk, player: Player)
    case gameOver
}

enum AppPrivateAction: Action {
    case resetAllState
    case loadGame(LoadData)
    case finisedSaveGame
}

extension AppAction {
    public static func newGame() -> Thunk<AppState> {
        return Thunk<AppState> { dispatch, getState in
            dispatch(AppPrivateAction.resetAllState)
            dispatch(AppAction.saveGame())
        }
    }

    public static func saveGame() -> Thunk<ReversiState> {
        return Thunk<ReversiState> { dispatch, getState in
            do {
                guard let state = getState() else { return }
                try state.persistentInteractor.saveGame(side: state.sideState.side, playersState: state.playersState, boardState: state.boardState)
                dispatch(AppPrivateAction.finisedSaveGame)
            } catch let error {
                let title = "Error occurred."
                let message = "Cannot save games."
                dispatch(ErrorAction(error: error, title: title, message: message))
            }
        }
    }

    public static func loadGame() -> Thunk<ReversiState> {
        return Thunk<ReversiState> { dispatch, getState in
            do {
                guard let state = getState() else { return }
                dispatch(AppPrivateAction.resetAllState)
                let loadData = try state.persistentInteractor.loadGame()
                dispatch(AppPrivateAction.loadGame(loadData))
            } catch let error {
                let title = "Error occurred."
                let message = "Cannot load games."
                dispatch(ErrorAction(error: error, title: title, message: message))
            }
        }
    }
}

let thunkMiddleware: Middleware<AppState> = createThunkMiddleware()

let loggingMiddleware: Middleware<AppState> = { dispatch, getState in
    return { next in
        return { action in
            // perform middleware logic
            print(action)
            // call next middleware
            return next(action)
        }
    }
}
