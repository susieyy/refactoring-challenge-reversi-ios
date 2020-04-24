import UIKit
import Logic
import ReSwift
import ReSwift_Thunk

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

    override func viewDidLoad() {
        super.viewDidLoad()
        boardView.delegate = self
        messageDiskSize = messageDiskSizeConstraint.constant
        store.subscribe(self)
        store.subscribe(subscriberCurrentTurn) { appState in appState.select { $0.currentTurn }.skipRepeats() }
        store.subscribe(subscriberComputerThinking) { appState in appState.select { $0.computerThinking }.skipRepeats() }
        store.subscribe(subscriberShouldShowCannotPlaceDisk) { appState in appState.select { $0.shouldShowCannotPlaceDisk }.skipRepeats() }
        store.subscribe(subscriberSquareStates) { appState in appState.select { $0.boardState }.skipRepeats() }
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
        case .start:
            self.animationState.cancelAll()
            self.waitForPlayer()
        case .turn:
            self.waitForPlayer()
        case .gameOverTied, .gameOverWon:
            break
        }
    }
    private lazy var subscriberSquareStates = BlockSubscriber<BoardState>() { [unowned self] in
        switch $0.animated {
        case false:
            self.updateDisksForInitial($0.squares)
        case true:
            guard let s = $0.placedSquare else { return }
            let diskCoordinates: [(Int, Int)] = $0.changedSquares.map { ($0.x, $0.y) }
            self.updateDisks(s.disk, atX: s.x, y: s.y, diskCoordinates: diskCoordinates, animated: true) { [weak self] _ in
                self?.nextTurn()
            }
        }
    }
    private lazy var subscriberComputerThinking = BlockSubscriber<ComputerThinking>() { [unowned self] in
        switch $0 {
        case .thinking(let side):
            self.playerActivityIndicators[side.index].startAnimating()
        case .none:
            self.playerActivityIndicators.forEach { $0.stopAnimating() }
        }
    }
    private lazy var subscriberShouldShowCannotPlaceDisk = BlockSubscriber<Trigger?>() { [unowned self] in
        if $0 == nil { return }
        self.showCannotPlaceDiskAlert()
    }
}

// MARK: Game management

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

    func nextTurn() {
        store.dispatch(AppAction.nextTurn)
    }

    func waitForPlayer() {
        store.dispatch(AppAction.waitForPlayer())
    }
    
    func placeDisk(disk: Disk, atX x: Int, y: Int) {
        store.dispatch(AppAction.placeDisk(disk: disk, x: x, y: y))
    }

    func changePlayer(side: Side, player: Player) {
        store.dispatch(AppAction.changePlayer(side: side, player: player))
        animationState.cancel(at: side)
    }
}

// MARK: Views

extension ViewController {
    /* Board */
    func updateDisksForInitial(_ squareStates: [Square]) {
        squareStates.forEach {
            boardView.updateDisk($0.disk, atX: $0.x, y: $0.y, animated: false)
        }
    }

    func updateDisks(_ disk: Disk, atX x: Int, y: Int, diskCoordinates: [(Int, Int)], animated isAnimated: Bool, completion: ((Bool) -> Void)? = nil) {
        if isAnimated {
            animationState.createAnimationCanceller()
            updateDisksWithAnimation(at: [(x, y)] + diskCoordinates, to: disk) { [weak self] finished in
                guard let self = self else { return }
                if self.animationState.isCancelled { return }
                self.animationState.cancel()

                completion?(finished)
                self.saveGame()
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.boardView.updateDisk(disk, atX: x, y: y, animated: false)
                for (x, y) in diskCoordinates {
                    self.boardView.updateDisk(disk, atX: x, y: y, animated: false)
                }
                completion?(true)
                self.saveGame()
            }
        }
    }

    private func updateDisksWithAnimation<C: Collection>(at coordinates: C, to disk: Disk, completion: @escaping (Bool) -> Void)
        where C.Element == (Int, Int)
    {
        guard let (x, y) = coordinates.first else {
            completion(true)
            return
        }

        boardView.updateDisk(disk, atX: x, y: y, animated: true) { [weak self] finished in
            guard let self = self else { return }
            if self.animationState.isCancelled { return }
            if finished {
                self.updateDisksWithAnimation(at: coordinates.dropFirst(), to: disk, completion: completion)
            } else {
                for (x, y) in coordinates {
                    self.boardView.updateDisk(disk, atX: x, y: y, animated: false)
                }
                completion(false)
            }
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
        case .start:
            break
        case .turn(let turn):
            messageDiskSizeConstraint.constant = messageDiskSize
            messageDiskView.disk = turn.side.disk
            messageLabel.text = "'s turn"
        case .gameOverWon(let winner):
            messageDiskSizeConstraint.constant = messageDiskSize
            messageDiskView.disk = winner.side.disk
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

// MARK: Inputs

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
            self.waitForPlayer()
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
    func boardView(_ boardView: BoardView, didSelectCellAtX x: Int, y: Int) {
        guard case .turn(let turn) = store.state.currentTurn else { return }
        if animationState.isAnimating { return }
        guard case .manual = turn.player else { return }
        placeDisk(disk: turn.side.disk, atX: x, y: y)
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

public class BlockSubscriber<S>: StoreSubscriber {
    public typealias StoreSubscriberStateType = S
    private let block: (S) -> Void

    public init(_ block: @escaping (S) -> Void) {
        self.block = block
    }

    public func newState(state: S) {
        self.block(state)
    }
}
