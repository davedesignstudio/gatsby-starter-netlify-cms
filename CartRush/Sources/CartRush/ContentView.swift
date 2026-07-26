import SwiftUI
import SpriteKit

struct ContentView: View {
    @State private var scene = RaceScene(size: CGSize(width: 1334, height: 750))

    var body: some View {
        ZStack {
            SpriteView(scene: scene)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Text("CART RUSH")
                        .font(.custom("AvenirNext-Heavy", size: 22))
                        .foregroundStyle(Color(red: 0.78, green: 0.88, blue: 0.42))
                    Spacer()
                    Text(scene.hudText)
                        .font(.custom("AvenirNext-Bold", size: 16))
                        .foregroundStyle(Color(red: 0.96, green: 0.94, blue: 0.90))
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer()

                HStack {
                    Text("Drag left to steer · Hold right to accelerate · Tap center for items")
                        .font(.custom("AvenirNext-Medium", size: 12))
                        .foregroundStyle(.white.opacity(0.55))
                    Spacer()
                }
                .padding(16)
            }
        }
        .onAppear {
            scene.scaleMode = .aspectFill
        }
    }
}
