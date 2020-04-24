import Foundation

public enum Side: String, Codable, CaseIterable {
    case sideDark
    case sideLight
}

extension Side: Hashable {}

extension Side {
    public var index: Int {
        switch self {
        case .sideDark: return 0
        case .sideLight: return 1
        }
    }

    public var disk: Disk {
        switch self {
        case .sideDark: return .diskDark
        case .sideLight: return .diskLight
        }
    }
}

extension Side {
    var flipped: Side {
        switch self {
        case .sideDark: return .sideLight
        case .sideLight: return .sideDark
        }
    }
}
