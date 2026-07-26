import SwiftUI
import SpriteKit

struct ContentView: View {
    @StateObject private var game = GameModel()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                SpriteView(scene: game.scene)
                    .ignoresSafeArea()
                    .onAppear {
                        game.scene.size = geo.size
                        game.scene.scaleMode = .resizeFill
                    }

                if game.phase == .title {
                    TitleOverlay(
                        onPlay: { game.openSelect() },
                        onHow: { game.openHowTo() }
                    )
                }

                if game.phase == .select {
                    SelectOverlay(
                        racers: RacerRoster.all,
                        selected: game.selectedRacer,
                        onSelect: { game.selectedRacer = $0 },
                        onStart: { game.startCountdown() },
                        onBack: { game.backToTitle() }
                    )
                }

                if game.phase == .howTo {
                    HowToOverlay(onBack: { game.backToTitle() })
                }

                if game.phase == .countdown {
                    Text(game.countdownLabel)
                        .font(.custom("AvenirNext-Heavy", size: 96))
                        .foregroundStyle(Color(red: 0.78, green: 0.96, blue: 0.26))
                        .shadow(color: .black, radius: 0, x: 4, y: 4)
                }

                if game.phase == .racing {
                    VStack {
                        HStack {
                            HudPill(text: "LAP \(min(game.playerLap + 1, 3))/3")
                            Spacer()
                            HudPill(text: game.playerPlaceLabel, accent: true)
                            Spacer()
                            HudPill(text: game.timeLabel)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 8)

                        HStack {
                            ItemSlot(icon: game.playerItemIcon)
                            Spacer()
                        }
                        .padding(.horizontal, 12)

                        Spacer()

                        HStack(alignment: .bottom) {
                            HStack(spacing: 10) {
                                ControlButton(label: "◀") { game.setTouchLeft(true) } onEnd: { game.setTouchLeft(false) }
                                ControlButton(label: "▶") { game.setTouchRight(true) } onEnd: { game.setTouchRight(false) }
                            }
                            Spacer()
                            VStack(spacing: 10) {
                                ControlButton(label: "DRIFT", wide: true) { game.setTouchDrift(true) } onEnd: { game.setTouchDrift(false) }
                                ControlButton(label: "ITEM", wide: true, highlight: true) { game.useItem() } onEnd: {}
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                }

                if game.phase == .results {
                    ResultsOverlay(
                        title: game.resultTitle,
                        place: game.playerPlaceLabel,
                        time: game.timeLabel,
                        standings: game.standings,
                        onRetry: { game.startCountdown() },
                        onMenu: { game.backToTitle() }
                    )
                }
            }
            .onChange(of: geo.size) { newSize in
                game.scene.size = newSize
            }
        }
        .background(Color(red: 0.08, green: 0.12, blue: 0.09))
    }
}

struct HudPill: View {
    let text: String
    var accent = false
    var body: some View {
        Text(text)
            .font(.custom("AvenirNext-Bold", size: 16))
            .foregroundStyle(accent ? Color(red: 1, green: 0.7, blue: 0.28) : Color(red: 0.95, green: 0.94, blue: 0.89))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.72))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color(red: 0.78, green: 0.96, blue: 0.26).opacity(0.35)))
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct ItemSlot: View {
    let icon: String
    var body: some View {
        Text(icon)
            .font(.system(size: 26))
            .frame(width: 52, height: 52)
            .background(Color.black.opacity(0.75))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.78, green: 0.96, blue: 0.26).opacity(0.5), lineWidth: 2))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ControlButton: View {
    let label: String
    var wide = false
    var highlight = false
    let onStart: () -> Void
    let onEnd: () -> Void

    var body: some View {
        Text(label)
            .font(.custom("AvenirNext-Heavy", size: wide ? 16 : 22))
            .foregroundStyle(highlight ? Color(red: 0.78, green: 0.96, blue: 0.26) : Color(red: 0.95, green: 0.94, blue: 0.89))
            .frame(width: wide ? 96 : 72, height: wide ? 50 : 72)
            .background(Color.black.opacity(0.7))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(highlight ? Color(red: 0.78, green: 0.96, blue: 0.26).opacity(0.5) : Color.white.opacity(0.25), lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onStart() }
                    .onEnded { _ in onEnd() }
            )
    }
}

struct TitleOverlay: View {
    let onPlay: () -> Void
    let onHow: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.1, green: 0.18, blue: 0.12),
                    Color(red: 0.05, green: 0.08, blue: 0.06),
                    Color(red: 0.14, green: 0.22, blue: 0.13)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 14) {
                Text("AFTER HOURS @ MEGASAVE")
                    .font(.custom("AvenirNext-DemiBold", size: 12))
                    .tracking(3)
                    .foregroundStyle(Color(red: 1, green: 0.7, blue: 0.28))
                Text("CART\nMAYHEM")
                    .font(.custom("AvenirNext-Heavy", size: 64))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color(red: 0.78, green: 0.96, blue: 0.26))
                    .shadow(color: .black, radius: 0, x: 4, y: 4)
                Text("Abandoned carts. Empty aisles. No rules.")
                    .font(.custom("AvenirNext-Regular", size: 16))
                    .foregroundStyle(Color(red: 0.95, green: 0.94, blue: 0.89).opacity(0.85))
                    .padding(.bottom, 18)
                Button("RACE", action: onPlay).buttonStyle(ArcadeButtonStyle())
                Button("HOW TO PLAY", action: onHow).buttonStyle(ArcadeButtonStyle(ghost: true))
            }
            .padding(24)
        }
    }
}

struct SelectOverlay: View {
    let racers: [RacerDef]
    let selected: Int
    let onSelect: (Int) -> Void
    let onStart: () -> Void
    let onBack: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(spacing: 14) {
                Text("PICK YOUR CART")
                    .font(.custom("AvenirNext-Heavy", size: 28))
                    .foregroundStyle(Color(red: 0.78, green: 0.96, blue: 0.26))
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(Array(racers.enumerated()), id: \.offset) { idx, racer in
                        Button {
                            onSelect(idx)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(
                                        LinearGradient(colors: [racer.color, racer.accent], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                                    .frame(height: 34)
                                Text(racer.name)
                                    .font(.custom("AvenirNext-Bold", size: 14))
                                    .foregroundStyle(.white)
                                Text(racer.blurb)
                                    .font(.custom("AvenirNext-Regular", size: 11))
                                    .foregroundStyle(.white.opacity(0.65))
                            }
                            .padding(10)
                            .background(Color.black.opacity(0.35))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(selected == idx ? Color(red: 0.78, green: 0.96, blue: 0.26) : .clear, lineWidth: 2)
                            )
                        }
                    }
                }
                Button("START RACE", action: onStart).buttonStyle(ArcadeButtonStyle())
                Button("BACK", action: onBack).buttonStyle(ArcadeButtonStyle(ghost: true))
            }
            .padding(20)
            .background(Color(red: 0.08, green: 0.14, blue: 0.1).opacity(0.95))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.78, green: 0.96, blue: 0.26).opacity(0.3), lineWidth: 2))
            .padding(20)
        }
    }
}

struct HowToOverlay: View {
    let onBack: () -> Void
    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                Text("HOW TO PLAY")
                    .font(.custom("AvenirNext-Heavy", size: 28))
                    .foregroundStyle(Color(red: 0.78, green: 0.96, blue: 0.26))
                    .frame(maxWidth: .infinity)
                Text("• Steer with on-screen arrows")
                Text("• Hold DRIFT for tight turns + boost")
                Text("• Grab neon crates, tap ITEM to fire")
                Text("• First cart through 3 laps wins")
                Text("Power-ups: soda boost, banana, soup can, sticky gum")
                    .foregroundStyle(Color(red: 1, green: 0.7, blue: 0.28))
                    .padding(.top, 4)
                Button("GOT IT", action: onBack).buttonStyle(ArcadeButtonStyle())
                    .frame(maxWidth: .infinity)
            }
            .font(.custom("AvenirNext-Regular", size: 15))
            .foregroundStyle(Color(red: 0.95, green: 0.94, blue: 0.89))
            .padding(22)
            .background(Color(red: 0.08, green: 0.14, blue: 0.1).opacity(0.95))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.78, green: 0.96, blue: 0.26).opacity(0.3), lineWidth: 2))
            .padding(24)
        }
    }
}

struct ResultsOverlay: View {
    let title: String
    let place: String
    let time: String
    let standings: [String]
    let onRetry: () -> Void
    let onMenu: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 10) {
                Text(title)
                    .font(.custom("AvenirNext-Heavy", size: 32))
                    .foregroundStyle(Color(red: 0.78, green: 0.96, blue: 0.26))
                Text(place)
                    .font(.custom("AvenirNext-Heavy", size: 56))
                    .foregroundStyle(Color(red: 1, green: 0.7, blue: 0.28))
                Text("Time \(time)")
                    .foregroundStyle(.white.opacity(0.7))
                ForEach(standings, id: \.self) { row in
                    Text(row)
                        .font(.custom("AvenirNext-Medium", size: 14))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Button("RACE AGAIN", action: onRetry).buttonStyle(ArcadeButtonStyle())
                Button("MENU", action: onMenu).buttonStyle(ArcadeButtonStyle(ghost: true))
            }
            .padding(22)
            .background(Color(red: 0.08, green: 0.14, blue: 0.1).opacity(0.95))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(red: 0.78, green: 0.96, blue: 0.26).opacity(0.3), lineWidth: 2))
            .padding(24)
        }
    }
}

struct ArcadeButtonStyle: ButtonStyle {
    var ghost = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("AvenirNext-Heavy", size: ghost ? 18 : 24))
            .frame(maxWidth: 280)
            .padding(.vertical, 12)
            .foregroundStyle(ghost ? Color(red: 0.95, green: 0.94, blue: 0.89) : Color(red: 0.05, green: 0.09, blue: 0.06))
            .background(ghost ? Color.clear : Color(red: 0.78, green: 0.96, blue: 0.26))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(red: 0.95, green: 0.94, blue: 0.89).opacity(ghost ? 0.35 : 0), lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .offset(y: configuration.isPressed ? 3 : 0)
    }
}

#Preview {
    ContentView()
}
