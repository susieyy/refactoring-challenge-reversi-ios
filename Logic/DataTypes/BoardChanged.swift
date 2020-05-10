import Foundation

public struct BoardChanged: Equatable, Codable {
    public let placedDiskCoordinate: PlacedDiskCoordinate
    public let flippedDiskCoordinates: [PlacedDiskCoordinate]
    public var changedDiskCoordinate: [PlacedDiskCoordinate] { [placedDiskCoordinate] + flippedDiskCoordinates }
}
