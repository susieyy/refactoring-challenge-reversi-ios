import Foundation

public enum CurrentTurn: Equatable {
    case start
    case turn(PlayerSide)
    case gameOverWon(PlayerSide)
    case gameOverTied
}
