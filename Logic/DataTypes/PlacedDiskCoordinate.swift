import Foundation

public struct PlacedDiskCoordinate: Equatable, Codable {
    public var disk: Disk
    public var coordinate: Coordinate

    public init(disk: Disk, coordinate: Coordinate) {
        self.disk = disk
        self.coordinate = coordinate
    }
}

extension PlacedDiskCoordinate {
    var optionalDiskCoordinate: OptionalDiskCoordinate { OptionalDiskCoordinate(disk: disk, coordinate: coordinate) }
}
