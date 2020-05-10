import Foundation

extension Optional where Wrapped == Disk {
    public var debugDescription: String {
        switch self {
        case .some(.diskDark):
            return "x"
        case .some(.diskLight):
            return "o"
        case .none:
            return "-"
        }
    }
}

extension Board: CustomDebugStringConvertible {
    public var debugDescription: String {
        var str = ""
        str.append("@")
        (0..<8).forEach { x in
            str.append(String(describing: x))
        }
        str.append("\n")

        (0..<8).forEach { y in
            str.append(String(describing: y))
            (0..<8).forEach { x in
                str.append(self[Coordinate(x: x, y: y)]!.disk.debugDescription)
           }
            str.append("\n")
        }
        return String(str.dropLast())
    }
}
