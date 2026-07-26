import GameKit
import Combine
import UIKit

struct NetworkRacerState: Codable {
    let name: String
    let x: CGFloat
    let y: CGFloat
    let rotation: CGFloat
    let speed: CGFloat
    let lap: Int
    let checkpoint: Int
}

final class GameCenterManager: NSObject, ObservableObject {
    static let shared = GameCenterManager()

    @Published var isAuthenticated = false
    @Published var localPlayerName = "Player"
    @Published var matchStatus = "Not connected"
    @Published var isHost = false
    @Published var onlineMatchReady = false

    private(set) var match: GKMatch?
    private var presentingViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController?
            .topMostViewController()
    }

    private override init() {
        super.init()
    }

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            guard let self else { return }
            if let viewController {
                self.presentingViewController?.present(viewController, animated: true)
                return
            }
            self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
            self.localPlayerName = GKLocalPlayer.local.displayName
            self.matchStatus = self.isAuthenticated ? "Ready for matchmaking" : (error?.localizedDescription ?? "Not signed in")
        }
    }

    func findMatch(minPlayers: Int = 2, maxPlayers: Int = 4) {
        guard isAuthenticated else {
            authenticate()
            matchStatus = "Sign in to Game Center first"
            return
        }

        let request = GKMatchRequest()
        request.minPlayers = minPlayers
        request.maxPlayers = maxPlayers
        request.defaultNumberOfPlayers = maxPlayers

        guard let vc = presentingViewController else {
            matchStatus = "No view controller for matchmaking"
            return
        }

        let matchmaker = GKMatchmakerViewController(matchRequest: request)
        matchmaker?.matchmakerDelegate = self
        vc.present(matchmaker!, animated: true)
    }

    func sendRacerState(_ state: NetworkRacerState) {
        guard let match, let data = try? JSONEncoder().encode(state) else { return }
        do {
            try match.send(data, to: match.players, dataMode: .unreliable)
        } catch {}
    }

    func disconnect() {
        match?.disconnect()
        match = nil
        matchStatus = "Disconnected"
    }

    var connectedPlayerCount: Int {
        (match?.players.count ?? 0) + (match != nil ? 1 : 0)
    }
}

extension GameCenterManager: GKMatchmakerViewControllerDelegate {
    func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
        viewController.dismiss(animated: true)
        matchStatus = "Matchmaking cancelled"
    }

    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
        viewController.dismiss(animated: true)
        matchStatus = "Match failed: \(error.localizedDescription)"
    }

    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
        viewController.dismiss(animated: true)
        self.match = match
        match.delegate = self
        isHost = match.players.isEmpty
        onlineMatchReady = true
        matchStatus = "Connected (\(connectedPlayerCount) players)"
        NotificationCenter.default.post(name: .cartKartOnlineMatchReady, object: nil)
    }
}

extension GameCenterManager: GKMatchDelegate {
    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        NotificationCenter.default.post(name: .cartKartNetworkStateReceived, object: nil, userInfo: ["data": data, "player": player])
    }

    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        matchStatus = "Player \(player.displayName): \(state == .connected ? "connected" : "disconnected")"
    }

    func match(_ match: GKMatch, didFailWithError error: Error?) {
        matchStatus = "Match error: \(error?.localizedDescription ?? "unknown")"
    }
}

extension Notification.Name {
    static let cartKartNetworkStateReceived = Notification.Name("cartKartNetworkStateReceived")
    static let cartKartOnlineMatchReady = Notification.Name("cartKartOnlineMatchReady")
}

private extension UIViewController {
    func topMostViewController() -> UIViewController {
        if let presented = presentedViewController {
            return presented.topMostViewController()
        }
        if let nav = self as? UINavigationController, let visible = nav.visibleViewController {
            return visible.topMostViewController()
        }
        if let tab = self as? UITabBarController, let selected = tab.selectedViewController {
            return selected.topMostViewController()
        }
        return self
    }
}
