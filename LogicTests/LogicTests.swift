import XCTest
import ReSwift
@testable import Logic

class LogicTests: XCTestCase {
    let testSaveFileName: String = "test.json"
    var store: Store<AppState>!

    override func setUpWithError() throws {
        let repository: Repository = RepositoryImpl(fileName: testSaveFileName)
        let persistentInteractor: PersistentInteractor = PersistentInteractorImpl(repository: repository)
        let dependency: Dependency = DependencyImpl(persistentInteractor: persistentInteractor)
        let thunkTestMiddleware: Middleware<AppState> = createThunkMiddleware(dependency: dependency)

        self.store = Store<AppState>(
            reducer: reducer,
            state: AppState(),
            middleware: [thunkTestMiddleware, loggingMiddleware]
        )
    }

    override func tearDownWithError() throws {
        let repository: Repository = RepositoryImpl(fileName: testSaveFileName)
        try? repository.clear()
    }

    func testBoardSetting() throws {
        XCTAssertEqual(8, store.state.boardSetting.cols)
        XCTAssertEqual(8, store.state.boardSetting.rows)
        XCTAssertEqual(64, store.state.boardSetting.coordinates.count)

        // (0, 0) ~ (7, 7)
        (0..<8).forEach { x in
            (0..<8).forEach { y in
                XCTAssertEqual(true, store.state.boardSetting.validCoordinate(Coordinate(x: x, y: y)))
            }
        }

        XCTAssertEqual(false, store.state.boardSetting.validCoordinate(Coordinate(x: -1, y: 0)))
        XCTAssertEqual(false, store.state.boardSetting.validCoordinate(Coordinate(x: 0, y: -1)))
        XCTAssertEqual(false, store.state.boardSetting.validCoordinate(Coordinate(x: -1, y: -1)))

        XCTAssertEqual(false, store.state.boardSetting.validCoordinate(Coordinate(x: 8, y: 7)))
        XCTAssertEqual(false, store.state.boardSetting.validCoordinate(Coordinate(x: 7, y: 8)))
        XCTAssertEqual(false, store.state.boardSetting.validCoordinate(Coordinate(x: 8, y: 8)))
    }

    func testInitial() throws {
        XCTAssertEqual(true, store.state.isInitialing)
        XCTAssertEqual(false, store.state.isLoadedGame)
        XCTAssertEqual(.none, store.state.computerThinking)
        XCTAssertEqual(.sideDark, store.state.side)
        XCTAssertEqual(nil, store.state.shouldShowCannotPlaceDisk)
        XCTAssertEqual(false, store.state.isShowingRestConfrmation)
        XCTAssertEqual(CurrentTurn.initialing, store.state.currentTurn)

        XCTAssertEqual(PlayerSide(player: .manual, side: .sideDark, count: 0), store.state.playerDark)
        XCTAssertEqual(PlayerSide(player: .manual, side: .sideLight, count: 0), store.state.playerLight)

        XCTAssertEqual(nil, store.state.board.changed)
        XCTAssertEqual(nil, store.state.board.changed)

        let diskCoordinatesState = store.state.board.diskCoordinatesState
        XCTAssertEqual(nil, diskCoordinatesState.sideWithMoreDisks())
        XCTAssertEqual(2, diskCoordinatesState.count(of: .diskDark))
        XCTAssertEqual(2, diskCoordinatesState.count(of: .diskLight))

        XCTAssertEqual(false, diskCoordinatesState.validMoves(for: .sideDark).isEmpty)
        XCTAssertEqual(false, diskCoordinatesState.validMoves(for: .sideLight).isEmpty)

        let expectationInitialDiskCoordinatesState = """
        @01234567
        0--------
        1--------
        2--------
        3---ox---
        4---xo---
        5--------
        6--------
        7--------
        """
        XCTAssertEqual(expectationInitialDiskCoordinatesState, diskCoordinatesState.description)
    }
}

extension Optional where Wrapped == Disk {
    var symbol: String {
        switch self {
        case .some(.diskDark):
            return "x"
        case .some(.diskLight):
            return "o"
        case .none:
            return "-"
        }
    }
}

extension DiskCoordinatesState: CustomStringConvertible {
    public var description: String {
        var str = ""
        str.append("@")
        (0..<8).forEach { x in
            str.append(String(describing: x))
        }
        str.append("\n")

        (0..<8).forEach { y in
            str.append(String(describing: y))
            (0..<8).forEach { x in
                str.append(self[Coordinate(x: x, y: y)]!.disk.symbol)
           }
            str.append("\n")
        }
        return String(str.dropLast())
    }
}
