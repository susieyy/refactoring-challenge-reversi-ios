import Foundation

public enum CurrentTurn: Equatable {
    case initialing
    case turn(Side, Player)
    case gameOverWon(Side)
    case gameOverTied
}
