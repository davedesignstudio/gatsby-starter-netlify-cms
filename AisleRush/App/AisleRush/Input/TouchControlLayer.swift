import SwiftUI
import UIKit

/// Press state for the control visuals. Published only on press and release,
/// never per frame.
final class ControlVisualState: ObservableObject {
    @Published var pressed: Set<ControlRegion> = []
    @Published var isAimingBackward = false
    @Published var isSteering = false

    func set(_ region: ControlRegion, pressed value: Bool) {
        if value {
            guard !pressed.contains(region) else { return }
            pressed.insert(region)
        } else {
            guard pressed.contains(region) else { return }
            pressed.remove(region)
        }
    }
}

/// A UIKit view that owns all touch handling for the control pad.
///
/// SwiftUI arbitrates gestures across the view tree and will not reliably
/// track two `DragGesture`s on sibling views at once, which in a kart racer
/// means you cannot steer and drift at the same time. UIKit multitouch has no
/// such problem: every touch is tracked independently, and `touchesCancelled`
/// gives us a release event when the system takes a touch away.
struct TouchControlLayer: UIViewRepresentable {
    let layout: ControlLayout
    let input: RaceInput
    let visuals: ControlVisualState

    func makeUIView(context: Context) -> TouchControlView {
        let view = TouchControlView(frame: .zero)
        view.isMultipleTouchEnabled = true
        view.backgroundColor = .clear
        view.configure(layout: layout, input: input, visuals: visuals)
        return view
    }

    func updateUIView(_ view: TouchControlView, context: Context) {
        view.configure(layout: layout, input: input, visuals: visuals)
    }
}

final class TouchControlView: UIView {
    private var layout = ControlLayout(size: .zero, showsGas: false)
    private weak var input: RaceInput?
    private var visuals: ControlVisualState?

    /// Touch identity is the object itself; `UITouch` instances are stable for
    /// the life of a touch.
    private var assignments: [ObjectIdentifier: ControlRegion] = [:]
    private var steerTouch: UITouch?
    private var steerOrigin: CGPoint = .zero

    /// The steering knob is drawn here rather than in SwiftUI so that dragging
    /// a thumb does not publish sixty view updates a second.
    private let knob = CALayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        knob.backgroundColor = UIColor.white.withAlphaComponent(0.62).cgColor
        knob.shadowColor = UIColor.black.cgColor
        knob.shadowOpacity = 0.3
        knob.shadowRadius = 6
        knob.shadowOffset = CGSize(width: 0, height: 3)
        layer.addSublayer(knob)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("TouchControlView is created in code")
    }

    func configure(layout: ControlLayout, input: RaceInput, visuals: ControlVisualState) {
        self.layout = layout
        self.input = input
        self.visuals = visuals
        layoutKnob(offset: 0)
    }

    private func layoutKnob(offset: CGFloat) {
        let side: CGFloat = 62
        let centre = layout.steerCentre
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        knob.frame = CGRect(
            x: centre.x + offset - side / 2,
            y: centre.y - side / 2,
            width: side,
            height: side
        )
        knob.cornerRadius = side / 2
        CATransaction.commit()
    }

    // MARK: - Touches

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let point = touch.location(in: self)
            guard let region = layout.region(at: point) else { continue }

            if region == .steer {
                guard steerTouch == nil else { continue }
                steerTouch = touch
                steerOrigin = point
                visuals?.isSteering = true
            } else if assignments.values.contains(region) {
                // Already held by another finger; ignore the duplicate.
                continue
            }
            assignments[ObjectIdentifier(touch)] = region
            apply(region, pressed: true, touch: touch)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            guard let region = assignments[ObjectIdentifier(touch)] else { continue }
            switch region {
            case .steer:
                updateSteer(for: touch)
            case .item:
                // Dragging down off the button aims the throw backwards.
                let backward = touch.location(in: self).y - layout.itemCentre.y > 26
                if backward != (visuals?.isAimingBackward ?? false) {
                    visuals?.isAimingBackward = backward
                }
                input?.aimBackward = backward
            default:
                break
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        release(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        release(touches)
    }

    private func release(_ touches: Set<UITouch>) {
        for touch in touches {
            guard let region = assignments.removeValue(forKey: ObjectIdentifier(touch)) else { continue }
            if region == .steer, steerTouch === touch {
                steerTouch = nil
                visuals?.isSteering = false
            }
            apply(region, pressed: false, touch: touch)
        }
    }

    private func updateSteer(for touch: UITouch) {
        let travel = layout.steerTravel
        let offset = max(-travel, min(travel, touch.location(in: self).x - steerOrigin.x))
        layoutKnob(offset: offset)
        // Positive steer is a left turn in the simulation.
        input?.steer = TouchControlView.shape(Double(-offset / travel))
    }

    private func apply(_ region: ControlRegion, pressed: Bool, touch: UITouch) {
        visuals?.set(region, pressed: pressed)
        switch region {
        case .steer:
            // Steering is relative to where the thumb landed, so both press
            // and release start from centre.
            layoutKnob(offset: 0)
            input?.steer = 0
        case .drift:
            input?.drift = pressed
            if pressed { Haptics.impact(.light) }
        case .brake:
            input?.brake = pressed
        case .gas:
            input?.throttle = pressed ? 1 : 0
        case .item:
            if pressed {
                let backward = touch.location(in: self).y - layout.itemCentre.y > 26
                input?.aimBackward = backward
                visuals?.isAimingBackward = backward
                Haptics.impact(.light)
            } else {
                visuals?.isAimingBackward = false
            }
            input?.fire = pressed
        }
    }

    /// Light curve near centre: precise for small corrections, full lock at
    /// the edges.
    private static func shape(_ value: Double) -> Double {
        let sign: Double = value < 0 ? -1 : 1
        let magnitude = min(abs(value), 1)
        return sign * (magnitude * magnitude * 0.45 + magnitude * 0.55)
    }

    /// Releases everything, for when the pad is taken away mid-touch.
    func releaseAll() {
        assignments.removeAll()
        steerTouch = nil
        visuals?.pressed.removeAll()
        visuals?.isSteering = false
        visuals?.isAimingBackward = false
        input?.releaseAll()
        layoutKnob(offset: 0)
    }
}
