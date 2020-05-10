import Foundation

public struct BoardContainer: Equatable, Codable {
    public var diskCoordinates: [OptionalDiskCoordinate] { board.diskCoordinates }
    public var boardSetting: BoardSetting { board.boardSetting }
    public var changed: BoardChanged?
    var board: Board

    init(diskCoordinatesState: Board, changed: BoardChanged? = nil) {
        self.board = diskCoordinatesState
        self.changed = changed
    }
}

public struct BoardChanged: Equatable, Codable {
    public let placedDiskCoordinate: PlacedDiskCoordinate
    public let flippedDiskCoordinates: [PlacedDiskCoordinate]
    public var changedDiskCoordinate: [PlacedDiskCoordinate] { [placedDiskCoordinate] + flippedDiskCoordinates }
}

public struct Board: Equatable, Codable {
    public var diskCoordinates: [OptionalDiskCoordinate]
    public var boardSetting: BoardSetting

    subscript(coordinate: Coordinate) -> OptionalDiskCoordinate? {
        get {
            guard boardSetting.validCoordinate(coordinate) else { return nil }
            let index = coordinate.y * boardSetting.cols + coordinate.x
            return diskCoordinates[index]
        }
        set(newvalue) {
            guard let newvalue = newvalue else { return }
            guard boardSetting.validCoordinate(coordinate) else { return }
            let index = coordinate.y * boardSetting.cols + coordinate.x
            diskCoordinates[index] = newvalue
        }
    }

    init(boardSetting: BoardSetting) {
        self.boardSetting = boardSetting
        self.diskCoordinates = boardSetting.coordinates.map { OptionalDiskCoordinate(coordinate: $0) }
        let initalDiskCoordinates: [PlacedDiskCoordinate] = [
            .init(disk: .diskLight, coordinate: .init(x: boardSetting.cols / 2 - 1, y: boardSetting.rows / 2 - 1)),
            .init(disk: .diskDark, coordinate: .init(x: boardSetting.cols / 2, y: boardSetting.rows / 2 - 1)),
            .init(disk: .diskDark, coordinate: .init(x: boardSetting.cols / 2 - 1, y: boardSetting.rows / 2)),
            .init(disk: .diskLight, coordinate: .init(x: boardSetting.cols / 2, y: boardSetting.rows / 2)),
        ]
        initalDiskCoordinates.forEach { self[$0.optionalDiskCoordinate.coordinate] = $0.optionalDiskCoordinate }
    }
}

extension Board {
    func count(of disk: Disk) -> Int {
        diskCoordinates.reduce(0) { $0 + ($1.disk == disk ? 1 : 0) }
    }

    func sideWithMoreDisks() -> Side? {
        let darkCount = count(of: .diskDark)
        let lightCount = count(of: .diskLight)
        return darkCount == lightCount ? nil : (darkCount > lightCount ? .sideDark : .sideLight)
    }

    func validMoves(for side: Side) -> [PlacedDiskCoordinate] {
        func canPlaceDisk(_ placedDiskCoordinate: PlacedDiskCoordinate) -> Bool {
            !flippedDiskCoordinatesByPlacingDisk(placedDiskCoordinate).isEmpty
        }
        return diskCoordinates.map { PlacedDiskCoordinate(disk: side.disk, coordinate: $0.coordinate) }.filter(canPlaceDisk)
    }

    func flippedDiskCoordinatesByPlacingDisk(_ placedDiskCoordinate: PlacedDiskCoordinate) -> [PlacedDiskCoordinate] {
        let directions: [Coordinate] = [
            .init(x: -1, y: -1),
            .init(x:  0, y: -1),
            .init(x:  1, y: -1),
            .init(x:  1, y:  0),
            .init(x:  1, y:  1),
            .init(x:  0, y:  1),
            .init(x: -1, y:  0),
            .init(x: -1, y:  1),
        ]

        let disk = placedDiskCoordinate.disk
        let coordinate = placedDiskCoordinate.coordinate
        guard self[coordinate]?.disk == nil else { return [] }
        var coordinates: [Coordinate] = []
        for direction in directions {
            var tmpCoordinate = coordinate
            var diskCoordinatesInLine: [Coordinate] = []
            flipping: while true {
                tmpCoordinate = tmpCoordinate + direction
                switch (disk, self[tmpCoordinate]?.disk) { // Uses tuples to make patterns exhaustive
                case (.diskDark, .some(.diskDark)), (.diskLight, .some(.diskLight)):
                    coordinates.append(contentsOf: diskCoordinatesInLine)
                    break flipping
                case (.diskDark, .some(.diskLight)), (.diskLight, .some(.diskDark)):
                    diskCoordinatesInLine.append(tmpCoordinate)
                case (_, .none):
                    break flipping
                }
            }
        }
        return coordinates.map { PlacedDiskCoordinate(disk: disk, coordinate: $0) }
    }
}
