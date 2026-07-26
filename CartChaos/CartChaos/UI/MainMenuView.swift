import SwiftUI
import SpriteKit

struct MainMenuView: View {
    @ObservedObject var gameState: GameState
    @State private var showCharacterSelect = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.08, blue: 0.06),
                    Color(red: 0.22, green: 0.15, blue: 0.10),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 8) {
                    Text("🛒")
                        .font(.system(size: 64))

                    Text("CART CHAOS")
                        .font(.system(size: 42, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )

                    Text("Homeless Shopping Cart Racing")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(spacing: 16) {
                    characterCard

                    Button {
                        gameState.startRace()
                    } label: {
                        Text("START RACE")
                            .font(.title2)
                            .fontWeight(.heavy)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    Text("3 Laps • 4 Racers • Item Boxes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 32)

                Spacer()
                    .frame(height: 40)
            }
        }
    }

    private var characterCard: some View {
        VStack(spacing: 12) {
            Text("Choose Your Racer")
                .font(.headline)
                .foregroundStyle(.white)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(CharacterType.allCases) { character in
                        characterButton(character)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func characterButton(_ character: CharacterType) -> some View {
        let isSelected = gameState.selectedCharacter == character

        return Button {
            gameState.selectedCharacter = character
        } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(Color(character.cartColor))
                    .frame(width: 40, height: 40)
                    .overlay(Circle().stroke(isSelected ? .yellow : .clear, lineWidth: 3))

                Text(character.rawValue)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(isSelected ? .yellow : .white)
            }
            .frame(width: 90)
            .padding(.vertical, 8)
            .background(isSelected ? Color.white.opacity(0.15) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

private extension Color {
    init(_ skColor: SKColor) {
        self.init(
            red: Double(skColor.redComponent),
            green: Double(skColor.greenComponent),
            blue: Double(skColor.blueComponent),
            opacity: Double(skColor.alphaComponent)
        )
    }
}
