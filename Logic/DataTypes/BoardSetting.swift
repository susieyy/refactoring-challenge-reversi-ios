import Foundation

public struct BoardSetting: Equatable, Codable {
    public var cols: Int
    public var rows: Int

    private var xRange: Range<Int> { 0 ..< self.cols }
    private var yRange: Range<Int> { 0 ..< self.rows }

    public var coordinates: [Coordinate] {
        self.yRange.map { y in self.xRange.map { x in Coordinate(x: x, y: y) } }.flatMap { $0 }
    }

    public func validCoordinate(_ coordinate: Coordinate) -> Bool {
        self.xRange.contains(coordinate.x) && self.yRange.contains(coordinate.y)
    }

    init(cols: Int, rows: Int) {
        self.cols = cols
        self.rows = rows
    }
}
