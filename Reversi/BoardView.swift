import UIKit
import Logic

private let lineWidth: CGFloat = 2

public class BoardView: UIView {
    private var cellViews: [CellView] = []
    private var actions: [CellSelectionAction] = []
    weak var delegate: BoardViewDelegate?
    var boardSetting: BoardSetting?

    subscript(coordinate: Coordinate) -> CellView {
        get {
            guard let boardSetting = boardSetting else { preconditionFailure() }
            let index = coordinate.y * boardSetting.rows + coordinate.x
            return cellViews[index]
        }
        set(newvalue) {
            guard let boardSetting = boardSetting else { preconditionFailure() }
            let index = coordinate.y * boardSetting.rows + coordinate.x
            cellViews[index] = newvalue
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    func setUp(boardSetting: BoardSetting) {
        self.boardSetting = boardSetting

        backgroundColor = UIColor(named: "DarkColor")!
        
        let cellViews: [CellView] = boardSetting.coordinates.map { _ in
            let cellView = CellView()
            cellView.translatesAutoresizingMaskIntoConstraints = false
            return cellView
        }
        self.cellViews = cellViews
        
        cellViews.forEach(addSubview(_:))
        for i in cellViews.indices.dropFirst() {
            NSLayoutConstraint.activate([
                cellViews[0].widthAnchor.constraint(equalTo: cellViews[i].widthAnchor),
                cellViews[0].heightAnchor.constraint(equalTo: cellViews[i].heightAnchor),
            ])
        }
        
        NSLayoutConstraint.activate([
            cellViews[0].widthAnchor.constraint(equalTo: cellViews[0].heightAnchor),
        ])

        boardSetting.coordinates.forEach {
            let topNeighborAnchor: NSLayoutYAxisAnchor
            do {
                let coordinate: Coordinate = .init(x: $0.x, y: $0.y - 1)
                if boardSetting.validCoordinate(coordinate) {
                    topNeighborAnchor = self[coordinate].bottomAnchor
                } else {
                    topNeighborAnchor = topAnchor
                }
            }

            let leftNeighborAnchor: NSLayoutXAxisAnchor
            do {
                let coordinate: Coordinate = .init(x: $0.x - 1, y: $0.y)
                if boardSetting.validCoordinate(coordinate) {
                    leftNeighborAnchor = self[coordinate].rightAnchor
                } else {
                    leftNeighborAnchor = leftAnchor
                }
            }

            let cellView = self[$0]
            NSLayoutConstraint.activate([
                cellView.topAnchor.constraint(equalTo: topNeighborAnchor, constant: lineWidth),
                cellView.leftAnchor.constraint(equalTo: leftNeighborAnchor, constant: lineWidth),
            ])

            if $0.y == boardSetting.rows - 1 {
                NSLayoutConstraint.activate([
                    bottomAnchor.constraint(equalTo: cellView.bottomAnchor, constant: lineWidth),
                ])
            }
            if $0.x == boardSetting.rows - 1 {
                NSLayoutConstraint.activate([
                    rightAnchor.constraint(equalTo: cellView.rightAnchor, constant: lineWidth),
                ])
            }

        }

        boardSetting.coordinates.forEach {
            let action = CellSelectionAction(boardView: self, coordinate: $0)
            actions.append(action) // To retain the `action`
            let cellView: CellView = self[$0]
            cellView.addTarget(action, action: #selector(action.selectCell), for: .touchUpInside)
        }
    }

    func updateDisk(_ disk: Disk?, coordinate: Coordinate, animated: Bool, completion: ((Bool) -> Void)? = nil) {
        self[coordinate].setDisk(disk, animated: animated, completion: completion)
    }
}

protocol BoardViewDelegate: AnyObject {
    func boardView(_ boardView: BoardView, didSelectCellAt coordinate: Coordinate)
}

private class CellSelectionAction: NSObject {
    private weak var boardView: BoardView?
    let coordinate: Coordinate

    init(boardView: BoardView, coordinate: Coordinate) {
        self.boardView = boardView
        self.coordinate = coordinate
    }
    
    @objc func selectCell() {
        guard let boardView = boardView else { return }
        boardView.delegate?.boardView(boardView, didSelectCellAt: coordinate)
    }
}
