import UIKit
import SpriteKit

/// Hosts the SpriteKit view and boots the game at the menu.
final class GameViewController: UIViewController {

    /// Design resolution. `aspectFit` letterboxes this onto any device so the
    /// full playfield and all on-screen controls are always visible.
    private let designSize = CGSize(width: 1024, height: 576)

    override func loadView() {
        view = SKView(frame: UIScreen.main.bounds)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let skView = view as? SKView else { return }

        let scene = MenuScene(size: designSize)
        scene.scaleMode = .aspectFit
        skView.presentScene(scene)

        skView.ignoresSiblingOrder = true
        #if DEBUG
        skView.showsFPS = true
        skView.showsNodeCount = true
        #endif
    }

    override var prefersStatusBarHidden: Bool { true }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
}
