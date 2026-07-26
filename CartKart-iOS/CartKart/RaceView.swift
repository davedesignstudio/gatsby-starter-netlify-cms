// RaceView.swift — SwiftUI host for SpriteKit race scene
import SwiftUI
import SpriteKit

struct RaceView: View {
    let cart: CartDef
    var onFinished: ([RaceResult]) -> Void

    @StateObject private var scene: RaceScene = RaceScene(size: CGSize(width: 800, height: 600))

    var body: some View {
        ZStack {
            SpriteView(scene: scene)
                .ignoresSafeArea()

            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(scene.hudPlace)
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundStyle(Color(red: 0.94, green: 0.77, blue: 0.10))
                        Text(scene.hudLap)
                            .font(.caption.weight(.bold))
                            .padding(6)
                            .background(Color.black.opacity(0.45))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Spacer()
                    Text(scene.hudItem)
                        .font(.system(size: 28))
                        .frame(width: 56, height: 56)
                        .background(Color.black.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(scene.hudItem.isEmpty ? Color.white.opacity(0.25) : Color(red: 0.94, green: 0.77, blue: 0.10), lineWidth: 2)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()

                Spacer()

                if !scene.countdownText.isEmpty {
                    Text(scene.countdownText)
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundStyle(Color(red: 0.94, green: 0.77, blue: 0.10))
                        .shadow(radius: 4)
                }

                Spacer()

                HStack(alignment: .bottom) {
                    Text("STEER")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.35))
                        .frame(maxWidth: .infinity, maxHeight: 140, alignment: .bottomLeading)
                        .padding()
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let w = UIScreen.main.bounds.width * 0.55
                                    scene.steerInput = Float(((value.location.x / max(w, 1)) - 0.5) * 2)
                                }
                                .onEnded { _ in scene.steerInput = 0 }
                        )

                    VStack(spacing: 10) {
                        pad("BRAKE", Color.red.opacity(0.5)) {
                            scene.braking = true
                            scene.gas = false
                        } onEnd: {
                            scene.braking = false
                            scene.gas = true
                        }
                        pad("FIRE", Color.cyan.opacity(0.5)) {
                            scene.wantsFire = true
                        } onEnd: {}
                        pad("GAS", Color.green.opacity(0.55)) {
                            scene.gas = true
                            scene.braking = false
                        } onEnd: {
                            scene.gas = true
                        }
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                }
            }
        }
        .onAppear {
            scene.scaleMode = .resizeFill
            scene.configure(playerCart: cart) { results in
                onFinished(results)
            }
        }
    }

    private func pad(_ title: String, _ color: Color, onStart: @escaping () -> Void, onEnd: @escaping () -> Void) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: title == "GAS" ? 88 : 64, height: title == "GAS" ? 88 : 64)
            .background(color)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white.opacity(0.35), lineWidth: 3))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onStart() }
                    .onEnded { _ in onEnd() }
            )
    }
}
