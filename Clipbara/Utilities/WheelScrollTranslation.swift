import AppKit

/// Turns vertical scrolling into horizontal scrolling over rows that only run
/// sideways, such as the card row and the tab strip.
///
/// A plain mouse wheel only reports vertical movement, so without this those
/// rows ignore it and the user has to hold Shift. The decision is made from the
/// direction of the scroll rather than the kind of device, because a mouse can
/// report the same high resolution deltas a trackpad does once its vendor
/// software enables smooth scrolling.
enum WheelScrollTranslation {
    /// Where a scroll sits in a continuous gesture. A wheel notch reports
    /// `none`, while a trackpad or touch surface reports a began/changed/ended
    /// run followed by momentum.
    enum Phase {
        case none
        case began
        case changed
        case ended
        case momentum
        case momentumEnded
    }

    struct Input {
        let deltaX: Double
        let deltaY: Double
        let phase: Phase
        let canScrollHorizontally: Bool
        let canScrollVertically: Bool
    }

    /// Holds the decision for the length of one gesture.
    ///
    /// A swipe is never perfectly straight. Deciding per event would let a
    /// mostly vertical swipe flip to horizontal and back as the dominant axis
    /// changes, so the choice made when the gesture starts is kept until it
    /// finishes, momentum included.
    struct Translator {
        private var latched: Bool?

        init() {}

        mutating func shouldTranslate(_ input: Input) -> Bool {
            // Only rows that run sideways and nowhere else. A view that also
            // scrolls vertically, such as a zoomed Quick Look image, keeps the
            // normal meaning of the scroll.
            guard input.canScrollHorizontally, !input.canScrollVertically else {
                latched = nil
                return false
            }

            switch input.phase {
            case .none:
                // A wheel notch stands on its own.
                return isVertical(input)

            case .began:
                let decision = isVertical(input)
                latched = decision
                return decision

            case .changed, .momentum:
                if let latched { return latched }
                let decision = isVertical(input)
                latched = decision
                return decision

            case .ended:
                return latched ?? isVertical(input)

            case .momentumEnded:
                let decision = latched ?? isVertical(input)
                latched = nil
                return decision
            }
        }
    }

    /// Vertical movement that is not already a sideways scroll. Shift + wheel
    /// and a sideways swipe both arrive with horizontal movement, so they are
    /// left to AppKit and keep behaving as they do today.
    static func isVertical(_ input: Input) -> Bool {
        abs(input.deltaY) > abs(input.deltaX) && input.deltaY != 0
    }

    /// Copies a scroll event with its vertical movement moved onto the
    /// horizontal axis. Handing the copy back to AppKit keeps its own line
    /// height, acceleration, and edge clamping instead of reimplementing them.
    /// Axis 1 is vertical and axis 2 is horizontal in `CGEvent` scroll fields.
    static func horizontalCopy(of event: NSEvent) -> NSEvent? {
        guard let copy = event.cgEvent?.copy() else { return nil }

        let lines = copy.getDoubleValueField(.scrollWheelEventDeltaAxis1)
        let points = copy.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
        let fixed = copy.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)

        copy.setDoubleValueField(.scrollWheelEventDeltaAxis2, value: lines)
        copy.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: points)
        copy.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: fixed)
        copy.setDoubleValueField(.scrollWheelEventDeltaAxis1, value: 0)
        copy.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: 0)
        copy.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: 0)

        return NSEvent(cgEvent: copy)
    }

    static func phase(of event: NSEvent) -> Phase {
        let momentum = event.momentumPhase
        if momentum.contains(.began) || momentum.contains(.changed) {
            return .momentum
        }
        if momentum.contains(.ended) || momentum.contains(.cancelled) {
            return .momentumEnded
        }

        let phase = event.phase
        if phase.contains(.began) || phase.contains(.mayBegin) {
            return .began
        }
        if phase.contains(.changed) || phase.contains(.stationary) {
            return .changed
        }
        if phase.contains(.ended) || phase.contains(.cancelled) {
            return .ended
        }
        return .none
    }
}
