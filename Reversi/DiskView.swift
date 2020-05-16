import UIKit
import Logic

public class DiskView: UIView {
    /// このビューが表示するディスクの色を決定します。
    public var disk: Disk = .diskDark {
        didSet { setNeedsDisplay() }
    }
    
    /// Interface Builder からディスクの色を設定するためのプロパティです。 `"dark"` か `"light"` の文字列を設定します。
    @IBInspectable public var name: String {
        get { disk.name }
        set { disk = .init(name: newValue) }
    }
    
    override public init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }
    
    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        setUp()
    }

    private func setUp() {
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    override public func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.setFillColor(disk.cgColor)
        context.fillEllipse(in: bounds)
    }
}

extension Disk {
    fileprivate var name: String {
        switch self {
        case .diskDark: return "dark"
        case .diskLight: return "light"
        }
    }

    fileprivate var uiColor: UIColor {
        switch self {
        case .diskDark: return UIColor(named: "DarkColor")!
        case .diskLight: return UIColor(named: "LightColor")!
        }
    }
    
    fileprivate var cgColor: CGColor {
        uiColor.cgColor
    }
       
    fileprivate init(name: String) {
        switch name {
        case Disk.diskDark.name:
            self = .diskDark
        case Disk.diskLight.name:
            self = .diskLight
        default:
            preconditionFailure("Illegal name: \(name)")
        }
    }
}
