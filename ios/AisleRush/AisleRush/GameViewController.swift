import SpriteKit
import UIKit

final class GameViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let gameView = SKView(frame: view.bounds)
        gameView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        gameView.preferredFramesPerSecond = 60
        gameView.ignoresSiblingOrder = true
        gameView.showsFPS = false
        gameView.showsNodeCount = false
        view.addSubview(gameView)

        let scene = GameScene(size: gameView.bounds.size)
        scene.scaleMode = .resizeFill
        gameView.presentScene(scene)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .landscape
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        true
    }

    override var prefersStatusBarHidden: Bool {
        true
    }
}
