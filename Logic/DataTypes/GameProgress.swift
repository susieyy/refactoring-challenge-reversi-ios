import Foundation

public enum GameOver: Equatable {
    case won(Side)
    case tied
}

public enum GameProgress: Equatable {
    case initialing
    case turn(Side, Player)
    case gameOver(GameOver)
}
