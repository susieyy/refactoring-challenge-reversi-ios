import Foundation

public struct OptionalDiskCoordinate: Equatable, Codable {
    public var disk: Disk?
    public var coordinate: Coordinate
}
