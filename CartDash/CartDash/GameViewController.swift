import SpriteKit
import UIKit

final class GameViewController: UIViewController {
    override func loadView() {
        view = SKView(frame: UIScreen.main.bounds)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let spriteView = view as? SKView else { return }
        spriteView.isMultipleTouchEnabled = true
        spriteView.ignoresSiblingOrder = true
        spriteView.preferredFramesPerSecond = 60

        let scene = GameScene(size: spriteView.bounds.size)
        scene.scaleMode = .resizeFill
        spriteView.presentScene(scene)
    }

    override var prefersStatusBarHidden: Bool {
        true
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        true
    }

    override var shouldAutorotate: Bool {
        true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .landscape
    }
}
