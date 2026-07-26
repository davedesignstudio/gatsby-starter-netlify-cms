import CartKartCore
import SwiftUI

struct HowToPlayView: View {
    @EnvironmentObject private var game: GameCoordinator
    @EnvironmentObject private var storage: Storage

    var body: some View {
        VStack(spacing: 16) {
            ScreenHeader(title: "How to play", subtitle: "Ninety seconds of shopping etiquette") {
                game.go(to: .menu)
            }

            ScrollView {
                VStack(spacing: 14) {
                    Panel(title: "Driving") {
                        Rule(icon: "bolt.fill", title: "You accelerate automatically",
                             detail: "Your only jobs are steering, drifting and aiming.")
                        Rule(icon: "hand.draw.fill", title: storage.controlScheme.displayName + " steering",
                             detail: storage.controlScheme.explanation + " Change it in the menu settings.")
                        Rule(icon: "timer", title: "Time the start",
                             detail: "Hold the screen just as the countdown hits one for a rocket start. Too early and the wheels judder.")
                    }

                    Panel(title: "Drifting") {
                        Rule(icon: "arrow.triangle.turn.up.right.diamond.fill", title: "Hold DRIFT through corners",
                             detail: "Steer into the bend and hold the drift button. Sparks build from blue to orange to purple.")
                        Rule(icon: "flame.fill", title: "Release for a mini-turbo",
                             detail: "Let go as the corner opens up. The longer the drift, the bigger the boost.")
                    }

                    Panel(title: "The shop floor") {
                        Rule(icon: "chevron.right.2", title: "Waxed patches boost you",
                             detail: "Drive over the arrow pads for free speed.")
                        Rule(icon: "drop.fill", title: "Mopped floors have no grip",
                             detail: "You keep your speed but lose your steering. Plan ahead.")
                        Rule(icon: "leaf.fill", title: "Off the tiles you crawl",
                             detail: "Matting and spilled cereal slow you down, unless your cart is built for it.")
                        Rule(icon: "figure.wave", title: "Staff will untangle you",
                             detail: "Wedged against a pallet? A member of staff lifts you back onto the aisle after a few seconds.")
                    }

                    Panel(title: "Items") {
                        ForEach(ItemKind.allCases, id: \.self) { kind in
                            HStack(alignment: .top, spacing: 12) {
                                Text(kind.emoji).font(.system(size: 24)).frame(width: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(kind.displayName)
                                        .font(.arcadeBody(14))
                                        .foregroundStyle(Palette.text)
                                    Text(blurb(for: kind))
                                        .font(.arcadeBody(12))
                                        .foregroundStyle(Palette.subtleText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 3)
                        }
                        Text("Item boxes are kinder to whoever is losing, so being last is not hopeless.")
                            .font(.arcadeBody(12))
                            .foregroundStyle(Palette.secondary)
                            .padding(.top, 4)
                    }
                }
            }

            ArcadeButton(title: "Got it", systemImage: "checkmark", isProminent: true) {
                game.go(to: .menu)
            }
        }
        .padding(22)
    }

    private func blurb(for kind: ItemKind) -> String {
        switch kind {
        case .grapeSpill: return "Drop it behind you. Anyone who rolls through spins out."
        case .soupCan: return "Fires forwards and nudges itself towards the cart in front."
        case .tripleSoup: return "Three tins. Fire them one at a time."
        case .energyDrink: return "Instant boost. Save it for a straight."
        case .mopBucket: return "Leaves a mopped patch that steals steering."
        case .flourBomb: return "A cloud of flour that blinds and slows."
        case .bulkBuy: return "Briefly invincible and faster. Everything you touch goes flying."
        case .runawayMelon: return "Rolls down the aisle until it finds the leader. Only for the back of the pack."
        }
    }
}

private struct Rule: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.arcade(16))
                .foregroundStyle(Palette.primary)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.arcadeBody(14))
                    .foregroundStyle(Palette.text)
                Text(detail)
                    .font(.arcadeBody(12))
                    .foregroundStyle(Palette.subtleText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 3)
    }
}
