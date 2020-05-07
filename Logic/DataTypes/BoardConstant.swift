import Foundation

public struct BoardConstant {
    public static let width: Int = 8
    public static let height: Int = 8

    public static let xRange: Range<Int> = 0 ..< BoardConstant.width
    public static let yRange: Range<Int> = 0 ..< BoardConstant.height

    public static var coordinateCount: Int { width * height }
}

extension BoardConstant {
    public static func convertCoordinateToIndex(x: Int, y: Int) -> Int? {
        convertCoordinateToIndex(.init(x: x, y: y))
    }

    public static func convertCoordinateToIndex(_ coordinate: Coordinate) -> Int? {
        guard xRange.contains(coordinate.x) && yRange.contains(coordinate.y) else { return nil }
        return coordinate.y * width + coordinate.x
    }
}
