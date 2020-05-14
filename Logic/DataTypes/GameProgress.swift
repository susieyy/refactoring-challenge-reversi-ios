import Foundation

public enum GameProgress: Equatable {
    case initialing
    case turn(Side, Player)
    case gameOverWon(Side)
    case gameOverTied
}
