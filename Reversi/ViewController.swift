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
        messageDiskSize = messageDiskSizeConstraint.constant
        store.subscribe(self)
        store.subscribe(subscriberCurrentTurn) { appState in appState.select { $0.currentTurn }.skipRepeats() }
        store.subscribe(subscriberComputerThinking) { appState in appState.select { $0.computerThinking }.skipRepeats() }
        store.subscribe(subscriberShouldShowCannotPlaceDisk) { appState in appState.select { $0.shouldShowCannotPlaceDisk }.skipRepeats() }
        store.subscribe(subscriberSquareStates) { appState in appState.select { $0.boardState }.skipRepeats() }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadGame()
    }

    func newState(state: AppState) {
        updatePlayerControls(state.playerDark)
        updatePlayerControls(state.playerLight)
        updateCountLabels(state.playerDark)
        updateCountLabels(state.playerLight)
        updateMessageViews(currentTurn: state.currentTurn)
    }

    private lazy var subscriberCurrentTurn = BlockSubscriber<CurrentTurn>() { [unowned self] in
        switch $0 {
        case .initialing:
            self.animationState.cancelAll()
            self.start()
        case .turn:
            self.waitForPlayer()
        case .gameOverTied, .gameOverWon:
            break
        }
    }
    private lazy var subscriberSquareStates = BlockSubscriber<BoardState>() { [unowned self] in
        switch $0.changed {
        case .none:
            self.updateDisksForInitial($0.squares)
        case .some(let changed):
            self.updateDisks(
                changed.placedAt.disk,
                position: changed.placedAt.position,
                diskCoordinates: changed.changedSquares.map { $0.position },
                animated: true) { [weak self] _ in
                    self?.nextTurn()
            }
        }
    }
    private lazy var subscriberComputerThinking = BlockSubscriber<ComputerThinking>() { [unowned self] in
        self.updatePlayerActivityIndicators(computerThinking: $0)
    }
    private lazy var subscriberShouldShowCannotPlaceDisk = BlockSubscriber<Trigger?>() { [unowned self] in
        guard $0 != nil else { return }
        self.showCannotPlaceDiskAlert()
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

    func start() {
        store.dispatch(AppAction.start)
    }

    func nextTurn() {
        store.dispatch(AppAction.nextTurn())
    }

    func waitForPlayer() {
        store.dispatch(AppAction.waitForPlayer())
    }
    
    func placeDisk(disk: Disk, position: Position) {
        store.dispatch(AppAction.placeDisk(disk: disk, position: position))
    }

    func changePlayer(side: Side, player: Player) {
        store.dispatch(AppAction.changePlayer(side: side, player: player))
        animationState.cancel(at: side)
    }
}

// MARK: Views (State -> Views)

extension ViewController {
    /* Board */
    func updateDisksForInitial(_ squareStates: [Square]) {
        squareStates.forEach {
            boardView.updateDisk($0.disk, position: $0.position, animated: false)
        }
    }

    func updateDisks(_ disk: Disk, position: Position, diskCoordinates: [Position], animated isAnimated: Bool, completion: ((Bool) -> Void)? = nil) {
        if isAnimated {
            animationState.createAnimationCanceller()
            updateDisksWithAnimation(at: [position] + diskCoordinates, to: disk) { [weak self] finished in
                guard let self = self else { return }
                if self.animationState.isCancelled { return }
                self.animationState.cancel()

                completion?(finished)
                self.saveGame()
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.boardView.updateDisk(disk, position: position, animated: false)
                diskCoordinates.forEach {
                    self.boardView.updateDisk(disk, position: $0, animated: false)
                }
                completion?(true)
                self.saveGame()
            }
        }
    }

    private func updateDisksWithAnimation<C: Collection>(at coordinates: C, to disk: Disk, completion: @escaping (Bool) -> Void)
        where C.Element == Position
    {
        guard let position = coordinates.first else {
            completion(true)
            return
        }

        boardView.updateDisk(disk, position: position, animated: true) { [weak self] finished in
            guard let self = self else { return }
            if self.animationState.isCancelled { return }
            if finished {
                self.updateDisksWithAnimation(at: coordinates.dropFirst(), to: disk, completion: completion)
            } else {
                coordinates.forEach {
                    self.boardView.updateDisk(disk, position: $0, animated: false)
                }
                completion(false)
            }
        }
    }

    private func updatePlayerActivityIndicators(computerThinking: ComputerThinking) {
        switch computerThinking {
        case .thinking(let side):
            self.playerActivityIndicators[side.index].startAnimating()
        case .none:
            self.playerActivityIndicators.forEach { $0.stopAnimating() }
        }
    }

    /* Game */
    func updatePlayerControls(_ playerState: PlayerSide) {
        playerControls[playerState.side.index].selectedSegmentIndex = playerState.player.rawValue
    }

    func updateCountLabels(_ playerState: PlayerSide) {
        countLabels[playerState.side.index].text = "\(playerState.count)"
    }
    
    func updateMessageViews(currentTurn: CurrentTurn) {
        switch currentTurn {
        case .initialing:
            break
        case .turn(let side, _):
            messageDiskSizeConstraint.constant = messageDiskSize
            messageDiskView.disk = side.disk
            messageLabel.text = "'s turn"
        case .gameOverWon(let winner):
            messageDiskSizeConstraint.constant = messageDiskSize
            messageDiskView.disk = winner.disk
            messageLabel.text = " won"
        case .gameOverTied:
            messageDiskSizeConstraint.constant = 0
            messageLabel.text = "Tied"
        }
    }

    func showCannotPlaceDiskAlert() {
        let alertController = UIAlertController(
            title: "Pass",
            message: "Cannot place a disk.",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Dismiss", style: .default) { [weak self] _ in
            self?.store.dispatch(AppAction.didShowCannotPlaceDisk)
            self?.nextTurn()
        })
        present(alertController, animated: true)
    }
}

// MARK: User inputs

extension ViewController {
    @IBAction func pressResetButton(_ sender: UIButton) {
        store.dispatch(AppAction.showingConfirmation(true))
        let alertController = UIAlertController(
            title: "Confirmation",
            message: "Do you really want to reset the game?",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            guard let self = self else { return }
            self.store.dispatch(AppAction.showingConfirmation(false))
        })
        alertController.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            guard let self = self else { return }
            self.newGame()
        })
        present(alertController, animated: true)
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
    func boardView(_ boardView: BoardView, didSelectCellAt position: Position) {
        if animationState.isAnimating { return }
        guard case .turn(let side, let player) = store.state.currentTurn else { return }
        guard case .manual = player else { return }
        placeDisk(disk: side.disk, position: position)
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
