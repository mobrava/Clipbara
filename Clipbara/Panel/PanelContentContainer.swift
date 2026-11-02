import AppKit

/// Hosts the panel's sliding content and keeps it exactly as wide as the panel.
///
/// The hosting view used to follow the panel through `autoresizingMask`, which
/// only applies the change in width. Once the two ever disagreed, every later
/// resize kept the same gap, so the content could stay squeezed against the left
/// edge until the app was relaunched. Deriving the width from the container on
/// every resize makes that state impossible to keep. The vertical position is
/// left alone because the slide animation owns it.
@MainActor
final class PanelContentContainer: NSView {
    weak var hostedView: NSView?
    /// Transparent band at the top of the window that the content's shadow
    /// draws into. The content is this much shorter than the container.
    var topInset: CGFloat = 0
    /// Transparent band on each side for the shadow, when the panel is
    /// narrower than the screen. The content is this much in from each side.
    var sideInset: CGFloat = 0

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        fitHostedViewWidth()
    }

    /// Snaps the hosted view to the container's width less `sideInset` on
    /// each side and to its height less `topInset`, keeping its vertical offset.
    func fitHostedViewWidth() {
        guard let hostedView else { return }
        let target = NSRect(
            x: sideInset,
            y: hostedView.frame.minY,
            width: max(bounds.width - sideInset * 2, 0),
            height: max(bounds.height - topInset, 0)
        )
        if hostedView.frame != target {
            hostedView.frame = target
        }
    }
}

/// The part of the panel that slides: the SwiftUI content clipped to rounded
/// top corners, with its shadow and top edge drawn on this view's layer.
///
/// The window's own shadow is computed from the whole window and cannot follow
/// content that moves inside it, so it had to be switched off for the slide and
/// popped in afterwards. Drawing the shadow here moves it with the content.
@MainActor
final class PanelSlideView: NSView {
    /// Blur radius of the shadow.
    nonisolated private static let shadowRadius: CGFloat = 8
    /// How far the shadow is pushed up, away from the screen edge.
    nonisolated private static let shadowLift: CGFloat = 1
    /// How far above the content the shadow can still be seen. The Gaussian
    /// blur fades out over roughly three times its radius; a band shorter than
    /// this cuts the shadow off in a hard line at the top of the window.
    nonisolated static var shadowReach: CGFloat {
        (shadowRadius * 3 + shadowLift).rounded(.up)
    }

    /// Radius of the two top corners.
    private let cornerRadius: CGFloat
    /// The rounded, clipped view that holds the SwiftUI content.
    private let clipView = NSView()
    /// Hairline along the top edge, like the outline of a window shadow.
    private let edgeLayer = CAShapeLayer()

    /// - Parameters:
    ///   - content: The SwiftUI hosting view.
    ///   - cornerRadius: Radius of the two top corners.
    init(content: NSView, cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = false
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.14
        layer?.shadowRadius = Self.shadowRadius
        // Layers are not flipped: a positive y casts the shadow upward, away
        // from the screen edge the panel rests on.
        layer?.shadowOffset = CGSize(width: 0, height: Self.shadowLift)

        clipView.wantsLayer = true
        clipView.layer?.masksToBounds = true
        // AppKit layers are not flipped, so the max Y corners are the top ones.
        clipView.layer?.cornerRadius = cornerRadius
        clipView.layer?.cornerCurve = .continuous
        clipView.layer?.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        addSubview(clipView)
        clipView.addSubview(content)

        edgeLayer.fillColor = nil
        edgeLayer.lineWidth = 1
        // Keep the hairline above the content.
        edgeLayer.zPosition = 1
        layer?.addSublayer(edgeLayer)
        updateEdgeColor()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        layoutContent()
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        // A frame change from the container doesn't always schedule
        // `layout()`, so follow every resize directly.
        layoutContent()
    }

    /// Fits the clipped content to the bounds and redraws the shadow and
    /// hairline paths to match.
    private func layoutContent() {
        clipView.frame = bounds
        clipView.subviews.first?.frame = clipView.bounds
        layer?.shadowPath = topRoundedPath(in: bounds, closed: true)
        // Half a line down so the top hairline sits inside the content. The
        // sides run just past the screen edges, so only the top shows.
        edgeLayer.path = topRoundedPath(in: bounds.insetBy(dx: -1, dy: 0.5), closed: false)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateEdgeColor()
    }

    /// Dark hairline in light mode, a faint light one in dark mode, as on
    /// window edges.
    private func updateEdgeColor() {
        let isDark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        edgeLayer.strokeColor = (isDark
            ? NSColor.white.withAlphaComponent(0.14)
            : NSColor.black.withAlphaComponent(0.10)).cgColor
    }

    /// A rectangle with its two top corners rounded.
    /// - Parameters:
    ///   - rect: The rectangle to trace.
    ///   - closed: Whether to close the path along the bottom edge. The open
    ///     form traces only the sides and top, for the hairline.
    private func topRoundedPath(in rect: CGRect, closed: Bool) -> CGPath {
        let radius = min(cornerRadius, rect.width / 2, rect.height)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
        path.addArc(
            tangent1End: CGPoint(x: rect.minX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.minX + radius, y: rect.maxY),
            radius: radius
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.maxY))
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.maxY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.maxY - radius),
            radius: radius
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        if closed {
            path.closeSubpath()
        }
        return path
    }
}
