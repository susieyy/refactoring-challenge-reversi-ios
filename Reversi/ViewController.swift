import UIKit
import Logic
import ReSwift

class ViewController: UIViewController, StoreSubscriber {
    @IBOutlet private var boardView: BoardView!
    @IBOutlet private var messageDiskView: DiskView!
    @IBOutlet private var messageLabel: UILabel!
    @IBOutlet private var messageDiskSizeConstraint: NSLayoutConstraint!
    @IBOutlet private var playerControls: [UISegmentedControl]!
    @IBOutlet private var countLabels: [UILabel]!
    @IBOutlet private var playerActivityIndicators: [UIActivityIndicatorView]!
    private var messageDiskSize: CGFloat! // to store the size designated in the storyboard
    private let animationState: AnimationState = .init()
    private let store: Store<AppState>

    init(store: Store<AppState> = Logic.store) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: State handling (State -> State, or Views)

    override func viewDidLoad() {
        super.viewDidLoad()
        boardView.delegate = self
        boardView.setUp(boardSetting: store.state.boardContainer.boardSetting)
        messageDiskSize = messageDiskSizeConstraint.constant
        store.subscribe(self)
        store.subscribe(subscriberGameProgress) { appState in appState.select { $0.gameProgress }.skipRepeats() }
        store.subscribe(subscriberBoardContainer) { appState in appState.select { $0.boardContainer }.skipRepeats() }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadGame()
    }

    func newState(state: AppState) {
        updatePlayerControls(state.gameProgress, playerSide: state.playerDark)
        updatePlayerControls(state.gameProgress, playerSide: state.playerLight)
        updateCountLabels(state.playerDark)
        updateCountLabels(state.playerLight)
        updateMessageViews(state.gameProgress)
    }

    private lazy var subscriberGameProgress = BlockSubscriber<GameProgress>() { [unowned self] in
        switch $0 {
        case .initialing:
            self.animationState.cancelAll()
            self.startGame()
        case .turn(let progress, let side, _, let computerThinking):
            self.updatePlayerActivityIndicators(side: side, computerThinking: computerThinking)
            switch progress {
            case .start:
                self.waitForPlayer()
            case .progressing:
                break
            }
        case .gameOver:
            break
        case .interrupt(let interrupt):
            switch interrupt {
            case .cannotPlaceDisk(let alert):
                switch alert {
                case .shouldShow:
                    self.showCannotPlaceDiskAlert()
                case .none, .showing:
                    break
                }
            case .resetConfirmation(let alert):
                switch alert {
                case .shouldShow:
                    self.showRestConfirmationAlert()
                case .none, .showing:
                    break
                }
            }
        }
    }
    private lazy var subscriberBoardContainer = BlockSubscriber<BoardContainer>() { [unowned self] in
        switch $0.changed {
        case .none:
            self.updateDisksForInitial($0.diskCoordinates)
        case .some(let changed):
            self.updateDisks(changed: changed, animated: true) { [weak self] _ in
                self?.nextTurn()
            }
        }
    }
}

// MARK: Game management (Views -> State)

extension ViewController {
    func saveGame() {
        store.dispatch(AppAction.saveGame())
    }

    func loadGame() {
        store.dispatch(AppAction.loadGame())
    }

    func newGame() {
        animationState.cancelAll()
        store.dispatch(AppAction.newGame())
    }

    func startGame() {
        store.dispatch(AppAction.startGame)
    }

    func nextTurn() {
        store.dispatch(AppAction.nextTurn())
    }

    func waitForPlayer() {
        store.dispatch(AppAction.waitForPlayer())
    }
    
    func placeDisk(_ placedDiskCoordinate: PlacedDiskCoordinate) {
        store.dispatch(AppAction.placeDisk(placedDiskCoordinate))
    }

    func changePlayer(side: Side, player: Player) {
        store.dispatch(AppAction.changePlayer(side: side, player: player))
        animationState.cancel(at: side)
    }

    func cannotPlaceDisk(alert: Alert) {
        store.dispatch(AppAction.cannotPlaceDisk(alert))
    }

    func resetConfirmation(alert: Alert) {
        store.dispatch(AppAction.resetConfirmation(alert))
    }
}

// MARK: Views (State -> Views)

extension ViewController {
    /* Board */
    func updateDisksForInitial(_ diskCoordinates: [OptionalDiskCoordinate]) {
        diskCoordinates.forEach {
            boardView.updateDisk($0.disk, coordinate: $0.coordinate, animated: false)
        }
    }

    func updateDisks(changed: BoardChanged, animated isAnimated: Bool, completion: ((Bool) -> Void)? = nil) {
        let disk = changed.placedDiskCoordinate.disk
        let placedCoordinate = changed.placedDiskCoordinate.coordinate
        let flippedCoordinates = changed.flippedDiskCoordinates.map { $0.coordinate }

        if isAnimated {
            animationState.createAnimationCanceller()
            updateDisksWithAnimation(at: [placedCoordinate] + flippedCoordinates, to: disk) { [weak self] finished in
                guard let self = self else { return }
                if self.animationState.isCancelled { return }
                self.animationState.cancel()

                completion?(finished)
                self.saveGame()
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.boardView.updateDisk(disk, coordinate: placedCoordinate, animated: false)
                flippedCoordinates.forEach {
                    self.boardView.updateDisk(disk, coordinate: $0, animated: false)
                }
                completion?(true)
                self.saveGame()
            }
        }
    }

    private func updateDisksWithAnimation<C: Collection>(at coordinates: C, to disk: Disk, completion: @escaping (Bool) -> Void)
        where C.Element == Coordinate
    {
        guard let coordinate = coordinates.first else {
            completion(true)
            return
        }

        boardView.updateDisk(disk, coordinate: coordinate, animated: true) { [weak self] finished in
            guard let self = self else { return }
            if self.animationState.isCancelled { return }
            if finished {
                self.updateDisksWithAnimation(at: coordinates.dropFirst(), to: disk, completion: completion)
            } else {
                coordinates.forEach {
                    self.boardView.updateDisk(disk, coordinate: $0, animated: false)
                }
                completion(false)
            }
        }
    }

    private func updatePlayerActivityIndicators(side: Side, computerThinking: ComputerThinking) {
        switch computerThinking {
        case .thinking:
            self.playerActivityIndicators[side.index].startAnimating()
        case .none:
            self.playerActivityIndicators.forEach { $0.stopAnimating() }
        }
    }

    /* Game */
    func updatePlayerControls(_ gameProgress: GameProgress, playerSide: PlayerSide) {
        playerControls[playerSide.side.index].selectedSegmentIndex = playerSide.player.rawValue
        playerControls.forEach {
            switch gameProgress {
            case .turn:
                $0.isEnabled = true
            case .initialing, .interrupt, .gameOver:
                $0.isEnabled = false
            }
        }
    }

    func updateCountLabels(_ playerSide: PlayerSide) {
        countLabels[playerSide.side.index].text = "\(playerSide.count)"
    }
    
    func updateMessageViews(_ gameProgress: GameProgress) {
        switch gameProgress {
        case .initialing, .interrupt:
            break
        case .turn(_, let side, _, _):
            messageDiskSizeConstraint.constant = messageDiskSize
            messageDiskView.disk = side.disk
            messageLabel.text = "'s turn"
        case .gameOver(let gameOver):
            switch gameOver {
            case .won(let winner):
                messageDiskSizeConstraint.constant = messageDiskSize
                messageDiskView.disk = winner.disk
                messageLabel.text = " won"
            case .tied:
                messageDiskSizeConstraint.constant = 0
                messageLabel.text = "Tied"
            }
        }
    }

    func showCannotPlaceDiskAlert() {
        cannotPlaceDisk(alert: .showing)
        let alertController = UIAlertController(
            title: "Pass",
            message: "Cannot place a disk.",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Dismiss", style: .default) { [weak self] _ in
            self?.cannotPlaceDisk(alert: .none)
            self?.nextTurn()
        })
        present(alertController, animated: true)
    }

    func showRestConfirmationAlert() {
        resetConfirmation(alert: .showing)
        let alertController = UIAlertController(
            title: "Confirmation",
            message: "Do you really want to reset the game?",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.resetConfirmation(alert: .none)
            self?.waitForPlayer()
        })
        alertController.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.newGame()
        })
        present(alertController, animated: true)
    }
}

// MARK: User inputs

extension ViewController {
    @IBAction func pressResetButton(_ sender: UIButton) {
        resetConfirmation(alert: .shouldShow)
    }
    
    @IBAction func changePlayerControlSegment(_ sender: UISegmentedControl) {
        guard let index = playerControls.firstIndex(of: sender) else { return }
        let side: Side
        switch index {
        case 0: side = .sideDark
        case 1: side = .sideLight
        default: preconditionFailure()
        }
        changePlayer(side: side, player: sender.convertToPlayer)
    }
}

extension ViewController: BoardViewDelegate {
    func boardView(_ boardView: BoardView, didSelectCellAt coordinate: Coordinate) {
        if animationState.isAnimating { return }
        guard case .turn(_, let side, let player, _) = store.state.gameProgress else { return }
        guard case .manual = player else { return }
        placeDisk(PlacedDiskCoordinate(disk: side.disk, coordinate: coordinate))
    }
}

// MARK: Additional types

extension UISegmentedControl {
    fileprivate var convertToPlayer: Player {
        switch selectedSegmentIndex {
        case 0: return .manual
        case 1: return .computer
        default: preconditionFailure()
        }
    }
}

extension Disk {
    var name: String {
        switch self {
        case .diskDark: return "dark"
        case .diskLight: return "light"
        }
    }
}

// MARK: Additional for ReSwift's subscriber

class BlockSubscriber<S>: StoreSubscriber {
    typealias StoreSubscriberStateType = S
    private let block: (S) -> Void

    init(_ block: @escaping (S) -> Void) {
        self.block = block
    }

    func newState(state: S) {
        self.block(state)
    }
}
