import Foundation

public struct Turn: Equatable {
    public let side: Disk
    public let player: Player
}

public enum CurrentTurn: Equatable {
    case start
    case turn(Turn)
    case gameOverWon(Turn)
    case gameOverTied

    var isGameOver: Bool {
        switch self {
        case .gameOverWon, .gameOverTied:
            return true
        case .start, .turn:
            return false
        }
    }
}
