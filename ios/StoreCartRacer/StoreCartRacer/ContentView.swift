import SpriteKit
import SwiftUI

struct ContentView: View {
    @StateObject private var model = GameModel()
    @State private var scene = GameScene(size: CGSize(width: 2048, height: 1536))

    var body: some View {
        ZStack {
            SpriteView(scene: scene)
                .ignoresSafeArea()

            VStack {
                hud
                Spacer()
                controls
            }
            .padding(20)

            if model.raceFinished {
                finishOverlay
            }
        }
        .onAppear {
            scene.scaleMode = .aspectFill
            scene.bind(model: model)
        }
    }

    private var hud: some View {
        HStack(spacing: 16) {
            StatBadge(title: "LAP", value: "\(model.lap)/\(model.maxLaps)")
            StatBadge(title: "POS", value: "#\(model.position)")
            StatBadge(title: "SPEED", value: "\(Int(model.speed))")
        }
    }

    private var controls: some View {
        HStack {
            HStack(spacing: 16) {
                HoldButton(label: "LEFT", tint: .blue) { isHeld in
                    if isHeld {
                        model.steering = -1
                    } else if model.steering < 0 {
                        model.steering = 0
                    }
                }

                HoldButton(label: "RIGHT", tint: .indigo) { isHeld in
                    if isHeld {
                        model.steering = 1
                    } else if model.steering > 0 {
                        model.steering = 0
                    }
                }
            }

            Spacer()

            HoldButton(label: "BOOST", tint: .orange) { isHeld in
                model.boosting = isHeld
            }
        }
    }

    private var finishOverlay: some View {
        VStack(spacing: 16) {
            Text("Checkout Dash Complete!")
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text("You finished in position #\(model.position)")
                .font(.headline)
                .foregroundStyle(.white.opacity(0.9))
            Button("Race Again") {
                scene.restartRace()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(24)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 20))
    }
}

private struct StatBadge: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.8))
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.black.opacity(0.58), in: Capsule())
    }
}

private struct HoldButton: View {
    let label: String
    let tint: Color
    let onChange: (Bool) -> Void

    var body: some View {
        Text(label)
            .font(.headline.weight(.bold))
            .frame(width: 92, height: 56)
            .foregroundStyle(.white)
            .background(tint.opacity(0.88), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.white.opacity(0.32), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onChange(true) }
                    .onEnded { _ in onChange(false) }
            )
    }
}
