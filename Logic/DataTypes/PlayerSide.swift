import Foundation

public struct PlayerSide: Equatable, Codable {
    public var player: Player = .manual
    public var side: Side
    public var count: Int = 0
}
