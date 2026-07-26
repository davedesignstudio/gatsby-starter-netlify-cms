import SpriteKit
import SwiftUI

struct ContentView: View {
    enum Screen { case title, select, race, results }

    @State private var screen: Screen = .title
    @State private var selected = 0
    @State private var scene = GameScene(size: CGSize(width: 390, height: 844))
    @State private var placeText = "Finish!"
    @State private var results: [RaceResult] = []
    @State private var hud = HUDState()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.23, green: 0.27, blue: 0.31),
                    Color(red: 0.07, green: 0.09, blue: 0.11),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            switch screen {
            case .title:
                titleView
            case .select:
                selectView
            case .race:
                raceView
            case .results:
                resultsView
            }
        }
        .onAppear {
            configureScene()
        }
    }

    private var titleView: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("AISLE\nKART")
                .font(.custom("AvenirNext-Heavy", size: 72))
                .foregroundStyle(
                    LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
                )
                .multilineTextAlignment(.center)
                .shadow(color: .orange.opacity(0.5), radius: 16, y: 6)
            Text("Homeless shopping carts. No owners. One grocery gauntlet.")
                .font(.custom("AvenirNext-DemiBold", size: 17))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Pick Your Cart") {
                withAnimation { screen = .select }
            }
            .buttonStyle(KartButtonStyle())
            .padding(.top, 12)
            Spacer()
            Text("Tilt-friendly · SpriteKit")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.bottom, 24)
        }
    }

    private var selectView: some View {
        VStack(spacing: 14) {
            Text("Choose a rogue")
                .font(.custom("AvenirNext-Heavy", size: 34))
                .foregroundStyle(.yellow)
                .padding(.top, 48)
            Text("Every cart has a story. And a dent.")
                .foregroundStyle(.white.opacity(0.8))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Array(CartBuild.all.enumerated()), id: \.element.id) { index, cart in
                    Button {
                        selected = index
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(cart.name)
                                .font(.custom("AvenirNext-Bold", size: 18))
                                .foregroundStyle(.yellow)
                            Text(cart.blurb)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.8))
                                .multilineTextAlignment(.leading)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(selected == index ? 0.16 : 0.06))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(selected == index ? Color.yellow : .clear, lineWidth: 2)
                        )
                    }
                }
            }
            .padding(.horizontal)
            Button("Start Race") {
                startRace()
            }
            .buttonStyle(KartButtonStyle())
            Button("Back") {
                withAnimation { screen = .title }
            }
            .foregroundStyle(.white.opacity(0.8))
            Spacer()
        }
    }

    private var raceView: some View {
        ZStack {
            SpriteView(scene: scene)
                .ignoresSafeArea()

            VStack {
                HStack {
                    hudPill("POS \(hud.place)/5")
                    Spacer()
                    hudPill("LAP \(hud.lap)/3")
                    Spacer()
                    hudPill("\(hud.speed) mph")
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)

                HStack {
                    Text(hud.itemEmoji)
                        .font(.system(size: 28))
                        .frame(width: 58, height: 58)
                        .background(Color.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.yellow.opacity(0.45), style: StrokeStyle(lineWidth: 2, dash: [5]))
                        )
                    Spacer()
                }
                .padding(.horizontal, 12)

                Spacer()

                HStack {
                    HStack(spacing: 10) {
                        control("◀") { scene.setSteer(-1) } release: { scene.setSteer(0) }
                        control("▶") { scene.setSteer(1) } release: { scene.setSteer(0) }
                    }
                    Spacer()
                    HStack(spacing: 10) {
                        control("🛒") { scene.usePlayerItem() } release: {}
                        control("BRK") { scene.setBrake(true) } release: { scene.setBrake(false) }
                        control("⛽") { scene.setGas(true) } release: { scene.setGas(false) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }

            if let text = hud.countdown {
                Text(text)
                    .font(.custom("AvenirNext-Heavy", size: 96))
                    .foregroundStyle(.yellow)
                    .shadow(color: .orange, radius: 8, y: 4)
            }
        }
    }

    private var resultsView: some View {
        VStack(spacing: 16) {
            Text(placeText)
                .font(.custom("AvenirNext-Heavy", size: 40))
                .foregroundStyle(.yellow)
                .padding(.top, 60)
            VStack(spacing: 8) {
                ForEach(results) { row in
                    HStack {
                        Text("\(row.place). \(row.name)\(row.isPlayer ? " (You)" : "")")
                        Spacer()
                    }
                    .padding(12)
                    .background(row.isPlayer ? Color.orange.opacity(0.28) : Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 24)
            Button("Race Again") { startRace() }
                .buttonStyle(KartButtonStyle())
            Button("Main Menu") {
                withAnimation { screen = .title }
            }
            .foregroundStyle(.white.opacity(0.85))
            Spacer()
        }
    }

    private func hudPill(_ text: String) -> some View {
        Text(text)
            .font(.custom("AvenirNext-Bold", size: 14))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func control(_ label: String, press: @escaping () -> Void, release: @escaping () -> Void) -> some View {
        Text(label)
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 68, height: 68)
            .background(Color.black.opacity(0.65))
            .clipShape(Circle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in press() }
                    .onEnded { _ in release() }
            )
    }

    private func configureScene() {
        scene.scaleMode = .resizeFill
        scene.onHUD = { hud = $0 }
        scene.onRaceFinished = { place, rows in
            placeText = place
            results = rows
            withAnimation { screen = .results }
        }
    }

    private func startRace() {
        configureScene()
        scene.startRace(playerBuild: CartBuild.all[selected])
        withAnimation { screen = .race }
        // Auto-hold gas feels better for arcade racing on first launch
        scene.setGas(true)
    }
}

struct HUDState {
    var place = 1
    var lap = 1
    var speed = 0
    var itemEmoji = "—"
    var countdown: String? = nil
}

struct KartButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("AvenirNext-Bold", size: 18))
            .foregroundStyle(Color(red: 0.1, green: 0.12, blue: 0.14))
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(
                LinearGradient(colors: [.yellow, .orange], startPoint: .top, endPoint: .bottom)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .orange.opacity(0.4), radius: 10, y: 4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
    }
}
