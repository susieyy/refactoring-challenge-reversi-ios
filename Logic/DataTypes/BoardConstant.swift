import Foundation

public struct BoardConstant {
    public static let width: Int = 8
    public static let height: Int = 8

    public static let xRange: Range<Int> = 0 ..< BoardConstant.width
    public static let yRange: Range<Int> = 0 ..< BoardConstant.height

    public static var squaresCount: Int { width * height }
}

extension BoardConstant {
    public static func convertPositionToIndex(x: Int, y: Int) -> Int? {
        convertPositionToIndex(.init(x: x, y: y))
    }

    public static func convertPositionToIndex(_ position: Position) -> Int? {
        guard xRange.contains(position.x) && yRange.contains(position.y) else { return nil }
        return position.y * width + position.x
    }
}
