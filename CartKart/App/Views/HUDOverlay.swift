import CartKartCore
import Combine
import SwiftUI

/// Race information laid over the SpriteKit view.
struct HUDOverlay: View {
    @ObservedObject var hud: RaceHUDModel
    let track: Track
    let isTimeTrial: Bool

    var body: some View {
        ZStack {
            VStack {
                HStack(alignment: .top) {
                    leftColumn
                    Spacer()
                    if !isTimeTrial {
                        rightColumn
                    } else {
                        MinimapView(hud: hud, track: track)
                            .frame(width: 116, height: 116)
                    }
                }
                Spacer()
                bottomRow
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            centrePieces
        }
        .font(.arcadeBody(14))
    }

    // MARK: - Corners

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !isTimeTrial {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(hud.snapshot.position)")
                        .font(.arcade(46))
                        .foregroundStyle(placeColor)
                    Text(placeSuffix)
                        .font(.arcade(20))
                        .foregroundStyle(placeColor)
                    Text("/ \(hud.snapshot.racerCount)")
                        .font(.arcadeBody(13))
                        .foregroundStyle(Palette.subtleText)
                        .padding(.leading, 2)
                }
                .shadow(radius: 4)
            }

            HStack(spacing: 6) {
                Text("LAP")
                    .font(.arcade(13))
                    .foregroundStyle(Palette.subtleText)
                Text("\(hud.snapshot.lap)/\(hud.snapshot.totalLaps)")
                    .font(.arcade(22))
                    .foregroundStyle(hud.snapshot.isFinalLap ? Palette.danger : Palette.text)
            }

            ItemSlot(item: hud.snapshot.item, charges: hud.snapshot.itemCharges, isSpinning: hud.snapshot.isItemSpinning)
        }
        .shadow(color: .black.opacity(0.6), radius: 6)
    }

    private var rightColumn: some View {
        VStack(alignment: .trailing, spacing: 8) {
            MinimapView(hud: hud, track: track)
                .frame(width: 116, height: 116)
            StandingsList(standings: hud.standings)
        }
    }

    private var bottomRow: some View {
        HStack(alignment: .bottom) {
            TimeReadout(snapshot: hud.snapshot)
            Spacer()
            SpeedGauge(fraction: hud.snapshot.speedFraction, isBoosting: hud.snapshot.isBoosting)
                .frame(width: 150, height: 12)
                .padding(.bottom, 6)
            Spacer()
            // Balances the readout so the gauge sits centred.
            TimeReadout(snapshot: hud.snapshot).hidden()
        }
    }

    // MARK: - Centre

    private var centrePieces: some View {
        VStack(spacing: 12) {
            Spacer()
            if let countdown = hud.snapshot.countdown {
                Text(countdown)
                    .font(.arcade(countdown == "GO!" ? 92 : 110))
                    .foregroundStyle(countdown == "GO!" ? Palette.primary : Palette.text)
                    .shadow(color: .black.opacity(0.8), radius: 12)
                    .transition(.scale)
                    .id(countdown)
            }
            if let banner = hud.banner {
                Text(banner)
                    .font(.arcade(38))
                    .foregroundStyle(Palette.primary)
                    .shadow(color: .black.opacity(0.8), radius: 8)
                    .transition(.opacity)
            }
            if hud.snapshot.isWrongWay {
                Label("WRONG WAY", systemImage: "exclamationmark.triangle.fill")
                    .font(.arcade(26))
                    .foregroundStyle(Palette.danger)
                    .shadow(color: .black.opacity(0.8), radius: 8)
            }
            Spacer()
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hud.snapshot.countdown)
        .animation(.easeInOut(duration: 0.2), value: hud.banner)
    }

    private var placeColor: Color {
        switch hud.snapshot.position {
        case 1: return Palette.primary
        case 2, 3: return Palette.text
        default: return Palette.subtleText
        }
    }

    private var placeSuffix: String {
        String(TimeFormat.ordinal(hud.snapshot.position).dropFirst(String(hud.snapshot.position).count))
    }
}

/// The held item, with a roulette shimmer while it is still being decided.
private struct ItemSlot: View {
    let item: ItemKind?
    let charges: Int
    let isSpinning: Bool

    @State private var spinIndex = 0
    private let spinTimer = Timer.publish(every: 0.08, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.black.opacity(0.4))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(item == nil ? Color.white.opacity(0.2) : Palette.primary, lineWidth: 2.5)
                )
            if isSpinning {
                Text(ItemKind.allCases[spinIndex % ItemKind.allCases.count].emoji)
                    .font(.system(size: 30))
            } else if let item {
                Text(item.emoji)
                    .font(.system(size: 32))
            } else {
                Image(systemName: "questionmark")
                    .font(.arcade(20))
                    .foregroundStyle(Color.white.opacity(0.25))
            }
            if charges > 1 {
                Text("x\(charges)")
                    .font(.arcade(12))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Palette.primary))
                    .offset(x: 22, y: 20)
            }
        }
        .frame(width: 58, height: 58)
        .onReceive(spinTimer) { _ in
            if isSpinning { spinIndex += 1 }
        }
    }
}

private struct StandingsList: View {
    let standings: [RaceHUDModel.Standing]

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(standings.prefix(8)) { entry in
                HStack(spacing: 5) {
                    Text("\(entry.place)")
                        .font(.arcade(11))
                        .foregroundStyle(entry.isPlayer ? Palette.primary : Palette.subtleText)
                        .frame(width: 12, alignment: .trailing)
                    Text(entry.emblem)
                        .font(.system(size: 11))
                    Text(entry.name)
                        .font(.arcadeBody(11))
                        .foregroundStyle(entry.isPlayer ? Palette.text : Palette.subtleText)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.35)))
    }
}

private struct TimeReadout: View {
    let snapshot: RaceHUDModel.Snapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(TimeFormat.lap(snapshot.raceTime))
                .font(.arcade(20))
                .foregroundStyle(Palette.text)
            if let last = snapshot.lastLapTime {
                Text("last \(TimeFormat.lap(last))")
                    .font(.arcadeBody(11))
                    .foregroundStyle(Palette.subtleText)
            }
            if let best = snapshot.bestLapTime {
                Text("best \(TimeFormat.lap(best))")
                    .font(.arcadeBody(11))
                    .foregroundStyle(Palette.secondary)
            }
        }
        .shadow(color: .black.opacity(0.6), radius: 5)
    }
}

private struct SpeedGauge: View {
    let fraction: Double
    let isBoosting: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.black.opacity(0.45))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: isBoosting
                                ? [Palette.primary, Color.white]
                                : [Palette.secondary, Palette.primary],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: proxy.size.width * CGFloat(min(fraction, 1.35) / 1.35))
            }
        }
        .animation(.linear(duration: 0.1), value: fraction)
    }
}

/// Course outline with a dot per cart.
struct MinimapView: View {
    @ObservedObject var hud: RaceHUDModel
    let track: Track

    var body: some View {
        Canvas { canvas, size in
            var path = Path()
            for (index, point) in hud.minimapOutline.enumerated() {
                let mapped = CGPoint(x: point.x * size.width, y: point.y * size.height)
                if index == 0 { path.move(to: mapped) } else { path.addLine(to: mapped) }
            }
            path.closeSubpath()
            canvas.stroke(path, with: .color(.white.opacity(0.85)), lineWidth: 6)
            canvas.stroke(path, with: .color(track.theme.accent.color), lineWidth: 2)

            for dot in hud.minimapDots {
                let centre = CGPoint(x: dot.point.x * size.width, y: dot.point.y * size.height)
                let radius: CGFloat = dot.isPlayer ? 5 : 3.5
                let rect = CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2)
                if dot.isPlayer {
                    canvas.fill(Path(ellipseIn: rect.insetBy(dx: -2, dy: -2)), with: .color(.white))
                }
                canvas.fill(Path(ellipseIn: rect), with: .color(dot.color.color))
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 14).fill(.black.opacity(0.35)))
    }
}
