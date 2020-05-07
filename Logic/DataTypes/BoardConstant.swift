import Foundation

public struct BoardConstant {
    public static let cols: Int = 8
    public static let rows: Int = 8

    private static let xRange: Range<Int> = 0 ..< BoardConstant.cols
    private static let yRange: Range<Int> = 0 ..< BoardConstant.rows

    public static var coordinates: [Coordinate] {
        yRange.map { y in xRange.map { x in Coordinate(x: x, y: y) } }.flatMap { $0 }
    }

    public static func validCoordinate(_ coordinate: Coordinate) -> Bool {
        xRange.contains(coordinate.x) && yRange.contains(coordinate.y)
    }
}
