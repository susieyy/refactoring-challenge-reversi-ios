import Foundation

public struct Turn: Equatable, Codable {
    public let side: Disk
    public let player: Player
}

public enum CurrentTurn: Equatable {
    case start
    case turn(Turn)
    case gameOverWon(Turn)
    case gameOverTied
}
