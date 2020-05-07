import Foundation

public struct Coordinate: Equatable, Codable {
    public var x: Int
    public var y: Int

    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
}

infix operator +: AdditionPrecedence
extension Coordinate {
    static func + (left: Coordinate, right: Coordinate) -> Coordinate {
        return Coordinate(x: left.x + right.x, y: left.y + right.y)
    }
}
