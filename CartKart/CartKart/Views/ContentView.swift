import SwiftUI

struct ContentView: View {
    @State private var showGame = false
    @State private var selectedTrack = 0

    private let tracks = ["Aisle 7 Speedway", "Frozen Foods Loop", "Checkout Chaos"]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.12, blue: 0.22), Color(red: 0.15, green: 0.05, blue: 0.12)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if showGame {
                GameContainerView(trackIndex: selectedTrack) {
                    showGame = false
                }
                .transition(.opacity)
            } else {
                mainMenu
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showGame)
    }

    private var mainMenu: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 8) {
                Text("CART KART")
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.yellow, .orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .orange.opacity(0.6), radius: 12)

                Text("Homeless Shopping Cart Racing")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.75))
            }

            Image(systemName: "cart.fill")
                .font(.system(size: 80))
                .foregroundStyle(.white, .orange)
                .symbolEffect(.bounce, value: showGame)
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 12) {
                Text("SELECT TRACK")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white.opacity(0.5))

                Picker("Track", selection: $selectedTrack) {
                    ForEach(0..<tracks.count, id: \.self) { index in
                        Text(tracks[index]).tag(index)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 32)

            Button {
                showGame = true
            } label: {
                Label("START RACE", systemImage: "flag.checkered")
                    .font(.title2.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundColor(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .shadow(color: .green.opacity(0.4), radius: 10, y: 4)
            }
            .padding(.horizontal, 32)

            VStack(spacing: 6) {
                Text("Controls")
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white.opacity(0.5))
                Text("Left thumb: steer  •  Right thumb: gas & brake")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.65))
                Text("Tap right side to use items  •  Drift for boost!")
                    .font(.caption)
                    .foregroundColor(.yellow.opacity(0.8))
            }
            .padding(.top, 8)

            Spacer()
        }
    }
}

#Preview {
    ContentView()
}
