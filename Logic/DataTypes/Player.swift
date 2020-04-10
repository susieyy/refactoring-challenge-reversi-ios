import Foundation

public enum Player {
    case manual
    case computer

    init?(index: Int) {
        switch index {
        case 0: self = .manual
        case 1: self = .computer
        default: return nil
        }
    }

    public var index: Int {
        switch self {
        case .manual: return 0
        case .computer: return 1
        }
    }
}
