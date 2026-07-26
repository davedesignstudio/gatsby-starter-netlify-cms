import SwiftUI
import SpriteKit
import UIKit

struct ContentView: View {
    @State private var scenePhase: GamePhase = .title
    @State private var selectedCart: CartDef = CartDef.roster[0]
    @State private var results: [RaceResult] = []

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.12, blue: 0.14), Color(red: 0.10, green: 0.09, blue: 0.06)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            switch scenePhase {
            case .title:
                TitleView(
                    onPlay: { scenePhase = .select },
                    onHow: { scenePhase = .how }
                )
            case .how:
                HowToView(onBack: { scenePhase = .title })
            case .select:
                SelectView(selected: $selectedCart) {
                    scenePhase = .racing
                }
            case .racing:
                GameContainer(
                    cart: selectedCart,
                    onFinish: { finishResults in
                        results = finishResults
                        scenePhase = .results
                    },
                    onQuit: { scenePhase = .title }
                )
                .ignoresSafeArea()
            case .results:
                ResultsView(results: results, onRetry: {
                    scenePhase = .racing
                }, onHome: {
                    scenePhase = .title
                })
            }
        }
        .preferredColorScheme(.dark)
    }
}

enum GamePhase {
    case title, how, select, racing, results
}

struct TitleView: View {
    var onPlay: () -> Void
    var onHow: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text("MEGAMART AFTER HOURS")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(4)
                .foregroundStyle(Color(red: 0.94, green: 0.70, blue: 0.16))
            Text("CART\nCLASH")
                .font(.system(size: 64, weight: .black, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color(red: 0.96, green: 0.94, blue: 0.89))
                .shadow(color: Color(red: 0.89, green: 0.23, blue: 0.18), radius: 0, x: 4, y: 5)
            Text("Homeless shopping carts. One linoleum kingdom. Race or rust.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(Color(red: 0.66, green: 0.72, blue: 0.74))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            HStack(spacing: 12) {
                Button("Race Now", action: onPlay)
                    .buttonStyle(ClashPrimaryButton())
                Button("How to Play", action: onHow)
                    .buttonStyle(ClashGhostButton())
            }
        }
        .padding()
    }
}

struct HowToView: View {
    var onBack: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How to Play")
                .font(.system(size: 28, weight: .black, design: .rounded))
            Group {
                Text("Steer — drag left/right on the stick")
                Text("Gas / Brake — hold the pedals")
                Text("Item — tap ITEM for banana, soda, price gun, coupon")
                Text("Win — finish 3 laps first")
            }
            .foregroundStyle(Color(red: 0.66, green: 0.72, blue: 0.74))
            Button("Got it", action: onBack)
                .buttonStyle(ClashPrimaryButton())
                .padding(.top, 8)
        }
        .padding(24)
        .background(Color(red: 0.05, green: 0.12, blue: 0.15).opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
    }
}

struct SelectView: View {
    @Binding var selected: CartDef
    var onStart: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Pick Your Cart")
                .font(.system(size: 28, weight: .black, design: .rounded))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                ForEach(CartDef.roster) { cart in
                    Button {
                        selected = cart
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(
                                    LinearGradient(colors: [cart.color, cart.accent], startPoint: .top, endPoint: .bottom)
                                )
                                .frame(height: 48)
                            Text(cart.name)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(cart.blurb)
                                .font(.system(size: 12))
                                .foregroundStyle(Color(red: 0.66, green: 0.72, blue: 0.74))
                                .multilineTextAlignment(.leading)
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selected.id == cart.id ? Color(red: 0.12, green: 0.65, blue: 0.63) : Color.white.opacity(0.2), lineWidth: 2)
                        )
                    }
                }
            }
            Button("Start Race", action: onStart)
                .buttonStyle(ClashPrimaryButton())
        }
        .padding()
    }
}

struct ResultsView: View {
    var results: [RaceResult]
    var onRetry: () -> Void
    var onHome: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            let you = results.first(where: \.isPlayer)
            Text(you?.place == 1 ? "Aisle Champion!" : "Race Over")
                .font(.system(size: 28, weight: .black, design: .rounded))
            ForEach(results) { r in
                HStack {
                    Text("\(r.placeSuffix) — \(r.name)\(r.isPlayer ? " (You)" : "")")
                        .foregroundStyle(r.isPlayer ? Color(red: 0.94, green: 0.70, blue: 0.16) : .white)
                    Spacer()
                    Text(r.finished ? String(format: "%.1fs", r.time) : "DNF")
                        .foregroundStyle(Color(red: 0.66, green: 0.72, blue: 0.74))
                }
            }
            HStack {
                Button("Race Again", action: onRetry).buttonStyle(ClashPrimaryButton())
                Button("Title", action: onHome).buttonStyle(ClashGhostButton())
            }
        }
        .padding(24)
        .background(Color(red: 0.05, green: 0.12, blue: 0.15).opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
    }
}

struct ClashPrimaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .heavy, design: .rounded))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(red: 0.89, green: 0.23, blue: 0.18))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct ClashGhostButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .heavy, design: .rounded))
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.4), lineWidth: 2)
            )
            .foregroundStyle(.white)
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

struct GameContainer: View {
    var cart: CartDef
    var onFinish: ([RaceResult]) -> Void
    var onQuit: () -> Void
    @State private var scene: GameScene?

    var body: some View {
        Group {
            if let scene {
                SpriteView(scene: scene).ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .onAppear {
            if scene == nil {
                let s = GameScene(
                    size: UIScreen.main.bounds.size,
                    playerCart: cart,
                    onFinish: onFinish,
                    onQuit: onQuit
                )
                s.scaleMode = .resizeFill
                scene = s
            }
        }
    }
}
