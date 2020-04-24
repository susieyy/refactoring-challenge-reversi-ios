public enum Disk: String, Codable {
    case dark
    case light
}

extension Disk: Hashable {}

extension Disk {
    /// `Disk` のすべての値を列挙した `Array` 、 `[.dark, .light]` を返します。
    public static var sides: [Disk] {
        [.dark, .light]
    }
}

extension Disk {
    init(index: Int) {
        for side in Disk.sides {
            if index == side.index {
                self = side
                return
            }
        }
        preconditionFailure("Illegal index: \(index)")
    }

    public var index: Int {
        switch self {
        case .dark: return 0
        case .light: return 1
        }
    }

    var flipped: Disk {
        switch self {
        case .dark: return .light
        case .light: return .dark
        }
    }
}
