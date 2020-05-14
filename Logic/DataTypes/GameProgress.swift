import Foundation

public enum GameOver: Equatable {
    case won(Side)
    case tied
}

public enum GameProgress: Equatable {
    case initialing
    case turn(Progress, Side, Player)
    case gameOver(GameOver)
    case interrupt(Interrupt)
}

public enum Progress: Equatable {
    case start
    case progressing
}

public enum Interrupt: Equatable {
    case resetConfrmation(Alert)
    case cannotPlaceDisk(Alert)
}

public enum Alert: String, Equatable, Codable {
    case none
    case shouldShow
    case showing
}
