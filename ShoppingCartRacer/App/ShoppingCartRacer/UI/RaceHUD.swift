import SwiftUI

/// The overlay on top of the race: position, laps, times, item slot, minimap and
/// the countdown. Everything comes from the `HUDModel` snapshot.
struct RaceHUD: View {
    @ObservedObject var coordinator: RaceCoordinator

    var body: some View {
        let hud = coordinator.hud

        ZStack {
            VStack {
                HStack(alignment: .top, spacing: 12) {
                    positionPanel(hud)
                    Spacer()
                    timingPanel(hud)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
                        Button {
                            coordinator.setPaused(true)
                        } label: {
                            Image(systemName: "pause.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Theme.foreground)
                                .padding(10)
                                .background(Circle().fill(Color(Palette.hudBackground, opacity: 0.75)))
                        }
                        MinimapView(coordinator: coordinator)
                            .frame(width: 104, height: 104)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)

                Spacer()

                HStack(alignment: .bottom) {
                    Spacer()
                    speedPanel(hud)
                    Spacer()
                }
                .padding(.bottom, 10)
            }

            centrePiece(hud)
        }
        .allowsHitTesting(true)
    }

    // MARK: - Panels

    private func positionPanel(_ hud: HUDModel?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(hud?.positionText ?? "--")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.accent)
            Text("of \(hud?.fieldSize ?? 0)")
                .font(Theme.body(11))
                .foregroundStyle(Theme.muted)
            Text(hud?.lapText ?? "LAP -/-")
                .font(Theme.numeric(13))
                .foregroundStyle(Theme.foreground)
                .padding(.top, 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(Palette.hudBackground, opacity: 0.66)))
    }

    private func timingPanel(_ hud: HUDModel?) -> some View {
        VStack(spacing: 2) {
            Text(hud?.currentLapTimeText ?? "0:00.000")
                .font(Theme.numeric(16))
                .foregroundStyle(Theme.foreground)
            if let best = hud?.bestLapTimeText {
                Text("BEST \(best)")
                    .font(Theme.body(10))
                    .foregroundStyle(Theme.muted)
            }
            if let gap = hud?.gapAheadText {
                Text(gap)
                    .font(Theme.body(11))
                    .foregroundStyle(Theme.danger)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(Palette.hudBackground, opacity: 0.66)))
    }

    private func speedPanel(_ hud: HUDModel?) -> some View {
        VStack(spacing: 6) {
            // Mini-turbo charge, so the player can feel the tiers.
            if let hud, hud.driftChargeFraction > 0 {
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { tier in
                        Capsule()
                            .fill(tier < hud.driftTier ? Theme.accent : Theme.muted.opacity(0.35))
                            .frame(width: 26, height: 5)
                    }
                }
            }

            HStack(alignment: .bottom, spacing: 6) {
                Text("\(hud?.speedKph ?? 0)")
                    .font(.system(size: 26, weight: .heavy, design: .monospaced))
                    .foregroundStyle(hud?.status == .boosting ? Theme.accent : Theme.foreground)
                Text("km/h")
                    .font(Theme.body(10))
                    .foregroundStyle(Theme.muted)
                    .padding(.bottom, 4)
            }

            // Speed bar doubles as the boost meter.
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.muted.opacity(0.25)).frame(height: 6)
                Capsule()
                    .fill(hud?.status == .boosting ? Theme.accent : Theme.good)
                    .frame(width: max(4, 132 * (hud?.speedFraction ?? 0)), height: 6)
            }
            .frame(width: 132)

            if let hud, hud.tokens > 0 {
                Text("\(hud.tokens) × loose change")
                    .font(Theme.body(10))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(Palette.hudBackground, opacity: 0.6)))
    }

    /// Countdown, status banner and the finish notice.
    @ViewBuilder
    private func centrePiece(_ hud: HUDModel?) -> some View {
        VStack(spacing: 10) {
            if let hud {
                switch hud.countdown {
                case .number(let value):
                    Text("\(value)")
                        .font(.system(size: 92, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.foreground)
                        .shadow(radius: 12)
                    Text("Hold the throttle as the lights go out")
                        .font(Theme.body(12))
                        .foregroundStyle(Theme.muted)
                case .go:
                    Text("GO!")
                        .font(.system(size: 78, weight: .black, design: .rounded))
                        .foregroundStyle(Theme.good)
                        .shadow(radius: 12)
                case .hidden:
                    if let status = hud.status, status != .boosting {
                        Text(status.rawValue)
                            .font(Theme.heading(18))
                            .foregroundStyle(statusColour(status))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Color(Palette.hudBackground, opacity: 0.7)))
                    }
                }

                if hud.isFinished {
                    Text("FINISHED \(hud.positionText)")
                        .font(Theme.title(30))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func statusColour(_ status: HUDModel.Status) -> Color {
        switch status {
        case .spunOut, .stalled: return Theme.danger
        case .slipping: return Color(RacerColor(hex: 0x9FD8F2))
        case .offRoad: return Color(RacerColor(hex: 0xC8B79A))
        case .expressLane, .boosting: return Theme.good
        }
    }
}

/// Live course map with a blip per cart.
struct MinimapView: View {
    @ObservedObject var coordinator: RaceCoordinator

    var body: some View {
        Canvas { context, size in
            let map = coordinator.minimap
            guard map.outline.count > 1 else { return }

            func place(_ point: Vector2) -> CGPoint {
                CGPoint(x: point.x * size.width, y: (1 - point.y) * size.height)
            }

            var path = Path()
            for (index, point) in map.outline.enumerated() {
                let location = place(point)
                if index == 0 { path.move(to: location) } else { path.addLine(to: location) }
            }
            path.closeSubpath()
            context.stroke(
                path,
                with: .color(.white.opacity(0.7)),
                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
            )

            let start = place(map.startLine)
            context.fill(
                Path(ellipseIn: CGRect(x: start.x - 3, y: start.y - 3, width: 6, height: 6)),
                with: .color(Color(Palette.boostGlow))
            )

            for blip in map.blips(carts: coordinator.scene.simulation.carts) {
                let point = place(blip.point)
                let radius: CGFloat = blip.isPlayer ? 5 : 3.5
                let rect = CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)
                if blip.isPlayer {
                    context.stroke(Path(ellipseIn: rect.insetBy(dx: -2, dy: -2)), with: .color(.white), lineWidth: 1.5)
                }
                context.fill(Path(ellipseIn: rect), with: .color(Color(blip.color)))
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(Palette.hudBackground, opacity: 0.6)))
    }
}
