import Foundation

public struct Turn {
    public let side: Disk
    public let player: Player
}

public enum CurrentTurn {
    case initial([SquareState])
    case turn(Turn)
    case gameOverWon(Turn)
    case gameOverTied

    var isGameOver: Bool {
        switch self {
        case .gameOverWon, .gameOverTied:
            return true
        case .initial, .turn:
            return false
        }
    }
}
