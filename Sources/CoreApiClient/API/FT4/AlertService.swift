import UIKit

class AlertService {
    
    static func alert(in vc: UIViewController, title: String?, message: String?, action: UIAlertAction? = nil, cancelActionStyle: UIAlertAction.Style = .cancel ) {
        DispatchQueue.main.async {
            let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: cancelActionStyle == .cancel ? Loc.general.cancel : Loc.general.ok, style: cancelActionStyle, handler: nil)
            controller.addAction(cancelAction)
            if let action = action {
                controller.addAction(action)
            }
            vc.present(controller, animated: true)
        }
    }
    
    static func error(in vc: UIViewController, title: String?, message: String?, cancelActionStyle: UIAlertAction.Style = .cancel) {
        DispatchQueue.main.async {
            let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
            let cancelAction = UIAlertAction(title: Loc.general.ok, style: cancelActionStyle, handler: nil)
            controller.addAction(cancelAction)
            
            vc.present(controller, animated: true)
        }
    }
}
