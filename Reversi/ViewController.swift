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
    private var lastChangedSquareStates: LastChangedSquareStates?

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
        loadGame()
    }
    
    private var viewHasAppeared: Bool = false
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if viewHasAppeared { return }
        viewHasAppeared = true
        waitForPlayer()
    }

    func newState(state: AppState) {
        updatePlayerControls(state.player1)
        updatePlayerControls(state.player2)
        updateCountLabels(state.player1)
        updateCountLabels(state.player2)
        updateMessageViews(currentTurn: state.currentTurn)

        if state.shouldShowCannotPlaceDisk != nil {
            showCannotPlaceDiskAlert()
            store.dispatch(AppAction.didShowCannotPlaceDisk)
        }

        switch store.state.currentTurn {
        case .initial(let squareStates):
            updateDisksForInitial(squareStates)
            store.dispatch(AppAction.gameStart)
        case .turn:
            guard let lastChangedSquareStates = state.lastChangedSquareStates else { return }
            updateLastChangedSquareStates(lastChangedSquareStates)
        case .gameOverTied, .gameOverWon:
            break
        }
    }

    func updateLastChangedSquareStates(_ lastChangedSquareStates: LastChangedSquareStates) {
        guard self.lastChangedSquareStates != lastChangedSquareStates else { return }
        let s = lastChangedSquareStates.lastPlacedSquare
        let diskCoordinates: [(Int, Int)] = lastChangedSquareStates.lastChangedSquares.map { ($0.x, $0.y) }
        updateDisks(s.disk, atX: s.x, y: s.y, diskCoordinates: diskCoordinates, animated: true) { [weak self] _ in
            self?.nextTurn()
        }
        self.lastChangedSquareStates = lastChangedSquareStates
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
        switch store.state.currentTurn {
        case .initial:
            break
        case .turn(let turn):
            switch turn.player {
            case .manual:
                break
            case .computer:
                playTurnOfComputer()
            }
        case .gameOverWon, .gameOverTied:
            gameOver()
        }
    }
    
    func playTurnOfComputer() {
//        switch store.state.currentTurn {
//        case .turn(let turn):
//            let candidates = reversiState.validMoves(for: turn)
//            if candidates.isEmpty {
//                nextTurn()
//                return
//            }
//            guard let (x, y) = candidates.randomElement() else { preconditionFailure() }
//            let side = turn.side
//            playerActivityIndicators[side.index].startAnimating()
//
//            let cleanUp: Canceller.CleanUp = { [weak self] in
//                self?.playerActivityIndicators[side.index].stopAnimating()
//            }
//            let canceller = animationState.createAnimationCanceller(at: side, cleanUp: cleanUp)
//            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
//                guard let self = self else { return }
//                if canceller.isCancelled { return }
//                canceller.cancel()
//                self.placeDisk(disk: side, atX: x, y: y, animated: true) { [weak self] _ in
//                    self?.nextTurn()
//                }
//            }
//        case .gameOverWon, .gameOverTied:
//            preconditionFailure()
//        }
    }

    func placeDisk(disk: Disk, atX x: Int, y: Int, animated isAnimated: Bool, completion: ((Bool) -> Void)? = nil) {
        store.dispatch(AppAction.placeDisk(disk: disk, x: x, y: y))
    }

    func changePlayer(side: Disk, player: Player) {
        store.dispatch(AppAction.changePlayer(side: side, player: player))
        animationState.cancel(at: side)

        // FIXME:
        // if !animationState.isAnimating && reversiState.canPlayTurnOfComputer(at: side) {
        //    playTurnOfComputer()
        //}
    }

    func gameOver() {
        store.dispatch(AppAction.gameOver)
    }
}

// MARK: Views

extension ViewController {
    /* Board */
    func updateDisksForInitial(_ squareStates: [SquareState]) {
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
    func updatePlayerControls(_ playerState: PlayerState) {
        playerControls[playerState.side.index].selectedSegmentIndex = playerState.player.rawValue
    }

    func updateCountLabels(_ playerState: PlayerState) {
        countLabels[playerState.side.index].text = "\(playerState.count)"
    }
    
    func updateMessageViews(currentTurn: CurrentTurn) {
        switch currentTurn {
        case .initial:
            break
        case .turn(let turn):
            messageDiskSizeConstraint.constant = messageDiskSize
            messageDiskView.disk = turn.side
            messageLabel.text = "'s turn"
        case .gameOverWon(let winner):
            messageDiskSizeConstraint.constant = messageDiskSize
            messageDiskView.disk = winner.side
            messageLabel.text = " won"
        case .gameOverTied:
            messageDiskSizeConstraint.constant = 0
            messageLabel.text = "Tied"
        }
    }

    func showAlter(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.newGame()
        })
        present(alertController, animated: true)
    }

    func showCannotPlaceDiskAlert() {
        let alertController = UIAlertController(
            title: "Pass",
            message: "Cannot place a disk.",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Dismiss", style: .default) { [weak self] _ in
            self?.nextTurn()
        })
        present(alertController, animated: true)
    }
}

// MARK: Inputs

extension ViewController {
    @IBAction func pressResetButton(_ sender: UIButton) {
        let alertController = UIAlertController(
            title: "Confirmation",
            message: "Do you really want to reset the game?",
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in })
        alertController.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            guard let self = self else { return }
            self.newGame()
            self.waitForPlayer()
        })
        present(alertController, animated: true)
    }
    
    @IBAction func changePlayerControlSegment(_ sender: UISegmentedControl) {
        guard let index = playerControls.firstIndex(of: sender) else { return }
        let side: Disk
        switch index {
        case 0: side = .dark
        case 1: side = .light
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
        placeDisk(disk: turn.side, atX: x, y: y, animated: true) { [weak self] _ in
            self?.nextTurn()
        }
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
        case .dark: return "dark"
        case .light: return "light"
        }
    }
}
