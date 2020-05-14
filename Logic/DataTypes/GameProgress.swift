import Foundation

public enum GameProgress: Equatable {
    case initialing
    case turn(Progress, Side, Player, ComputerThinking)
    case gameOver(GameOver)
    case interrupt(Interrupt)
}

public enum ComputerThinking: String, Equatable, Codable {
    case none
    case thinking
}

public enum Progress: Equatable {
    case start
    case progressing
}

public enum GameOver: Equatable {
    case won(Side)
    case tied
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
