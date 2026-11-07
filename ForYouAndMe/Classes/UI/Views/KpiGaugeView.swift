//
//  KpiGaugeView.swift
//  ForYouAndMe
//
//  FUAM-4315: half-ring gauge of the KPI widget (spec §3). A 120×120 box clipped to its top 60:
//  centre (60, 60), stroke centreline radius 57, stroke 6, round caps, start 183°, sweep 174°
//  clockwise over the top. 183° sits 3 pt above the centre line on purpose: that is where the cap
//  centres belong, so the caps end exactly at the clip edge.
//  D20: with a threshold the track splits into two round-capped segments around a 4 px gap; the
//  fill stays one continuous arc (see KpiGaugeGeometry).
//

import UIKit
import PureLayout

final class KpiGaugeView: UIView {

    static let size = CGSize(width: 120, height: 60)
    static let animationDuration: CFTimeInterval = 0.6
    private static let radius: CGFloat = KpiGaugeGeometry.radius
    private static let lineWidth: CGFloat = KpiGaugeGeometry.lineWidth
    private static let countSteps = 12

    private let trackLayer = CAShapeLayer()
    /// Track segments too short to stroke, drawn as filled circles of the stroke's diameter.
    private let trackDotLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    let valueLabel = UILabel() // internal (read-only) for the specs
    private let percentLabel = UILabel()

    private var progressColor: UIColor = ColorPalette.color(withType: .kpiWidgetThreshold0)
    private var trackColor: UIColor = ColorPalette.color(withType: .inactive)

    // What is shown, or being animated to, and for which widget.
    private var widgetId: String?
    private var targetFill: CGFloat?
    private var targetDisplay: Int?
    private var threshold: CGFloat?
    private var meetsThreshold: Bool = false
    private var animationToken: Int = 0
    private var countTimer: Timer?
    /// Injectable for the specs; production reads the system setting.
    var isReduceMotionEnabled: () -> Bool = { UIAccessibility.isReduceMotionEnabled }

    /// The running fill animation, if any (read by the specs).
    var fillAnimation: CABasicAnimation? {
        return self.progressLayer.animation(forKey: "fill") as? CABasicAnimation
    }

    init() {
        super.init(frame: CGRect(origin: .zero, size: Self.size))
        self.clipsToBounds = true
        self.autoSetDimensions(to: Self.size)
        self.setContentCompressionResistancePriority(.required, for: .horizontal)
        self.setContentCompressionResistancePriority(.required, for: .vertical)
        self.setContentHuggingPriority(.required, for: .horizontal)

        self.layer.addSublayer(self.trackDotLayer)
        for shapeLayer in [self.trackLayer, self.progressLayer] {
            shapeLayer.fillColor = UIColor.clear.cgColor
            shapeLayer.lineWidth = Self.lineWidth
            shapeLayer.lineCap = .round
            self.layer.addSublayer(shapeLayer)
        }
        self.progressLayer.strokeEnd = 0
        self.progressLayer.isHidden = true

        // Gauge numbers are fixed-size (D9): no Dynamic Type.
        self.valueLabel.font = FontPalette.baseFont(forStyle: .paragraphBold).withSize(30)
        self.percentLabel.font = FontPalette.baseFont(forStyle: .paragraph).withSize(20)
        self.percentLabel.text = "%"
        self.addSubview(self.valueLabel)
        self.addSubview(self.percentLabel)
        // Value centred on x = 60, baseline 1 pt above the clip bottom; "%" 4 pt after it on the same baseline.
        self.valueLabel.autoAlignAxis(toSuperviewAxis: .vertical)
        self.valueLabel.lastBaselineAnchor.constraint(equalTo: self.bottomAnchor, constant: -1).isActive = true
        self.percentLabel.autoPinEdge(.leading, to: .trailing, of: self.valueLabel, withOffset: 4)
        self.percentLabel.autoAlignAxis(.lastBaseline, toSameAxisOf: self.valueLabel)

        self.isAccessibilityElement = true
        self.accessibilityTraits = .staticText
        self.applyColors()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        self.countTimer?.invalidate()
    }

    // MARK: - Public

    /// Shows `fill`/`display` for widget `id`, with the track split at `threshold` (0...1, nil for
    /// none). With `animatedFrom` (a fill) the arc sweeps from there and the number counts along;
    /// `completion` runs when the gauge rests on the new value (immediately when not animated).
    /// A no-op for the arc when `id` already shows or animates to the same value.
    // swiftlint:disable:next function_parameter_count
    func set(id: String,
             fill: CGFloat,
             threshold: CGFloat? = nil,
             meetsThreshold: Bool = false,
             display: Int,
             progressColor: UIColor,
             trackColor: UIColor,
             animatedFrom: CGFloat?,
             completion: @escaping () -> Void) {
        self.progressColor = progressColor
        self.trackColor = trackColor
        self.applyColors()
        self.accessibilityLabel = "\(display)%"

        let fillMappingChanged = meetsThreshold != self.meetsThreshold
        self.meetsThreshold = meetsThreshold
        if threshold != self.threshold {
            self.threshold = threshold
            self.updatePaths()
        }
        if id == self.widgetId, fill == self.targetFill, display == self.targetDisplay, !fillMappingChanged {
            return
        }
        // The count starts from the number on screen; a fresh view derives it from the start fill.
        let shownDisplay = (id == self.widgetId ? self.valueLabel.text.flatMap { Int($0) } : nil)
            ?? Int((Double(animatedFrom ?? 0) * 100 + 1e-9).rounded(.down))
        // A new value for the same widget while the arc is still sweeping continues from where the
        // arc is drawn, not from the store's last completed fill (which is not written yet).
        let inFlightFill: CGFloat? = (id == self.widgetId && self.fillAnimation != nil)
            ? self.progressLayer.presentation()?.strokeEnd
            : nil
        self.cancelAnimation()
        self.widgetId = id
        self.targetFill = fill
        self.targetDisplay = display

        let reduceMotion = self.isReduceMotionEnabled()
        // Animate the fill's end angle: both ends are mapped through the threshold geometry.
        let target = self.strokeEnd(forFill: fill)
        // A previous, completed value is assumed consistent with its own threshold check. The sweep
        // animates the end angle continuously, so it crosses the gap only once it passes t.
        let storedFrom = animatedFrom.map { self.strokeEnd(forFill: $0, meetsThreshold: $0 > (self.threshold ?? 2)) }
        guard let from = inFlightFill ?? storedFrom, !reduceMotion else {
            self.rest(fill: fill, display: display)
            completion()
            return
        }

        let token = self.animationToken
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            // A newer `set` (another widget, another value) supersedes this one: do not record it.
            guard let self = self, self.animationToken == token else { return }
            self.rest(fill: fill, display: display)
            completion()
        }
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = from
        animation.toValue = target
        animation.duration = Self.animationDuration
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        self.setModelStrokeEnd(target, hidden: fill == 0 && from == 0)
        self.progressLayer.add(animation, forKey: "fill")
        CATransaction.commit()

        self.startCount(from: shownDisplay, to: display, token: token)
    }

    /// The number shown at `progress` (0...1) of a count from `from` to `to`: integer interpolation,
    /// landing exactly on `to` (D11). Never derived from the animated fill.
    static func countedValue(from: Int, to: Int, progress: Double) -> Int {
        guard progress < 1 else { return to }
        let clamped = max(0, progress)
        return Int((Double(from) + Double(to - from) * clamped).rounded())
    }

    // MARK: - Layout / traits

    override func layoutSubviews() {
        super.layoutSubviews()
        self.updatePaths()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            self.applyColors()
        }
    }

    // MARK: - Private

    /// The progress layer's path is the full 183° -> 357° arc; its strokeEnd encodes the fill end angle.
    private func strokeEnd(forFill fill: CGFloat, meetsThreshold: Bool? = nil) -> CGFloat {
        let end = KpiGaugeGeometry(threshold: self.threshold, fill: fill,
                                   meetsThreshold: meetsThreshold ?? self.meetsThreshold).fillEnd
        return (end - KpiGaugeGeometry.startAngle) / KpiGaugeGeometry.sweep
    }

    private func updatePaths() {
        let center = CGPoint(x: self.bounds.midX, y: self.bounds.height)
        let geometry = KpiGaugeGeometry(threshold: self.threshold, fill: 0, meetsThreshold: false)
        let trackPath = UIBezierPath()
        let dotPath = UIBezierPath()
        for segment in geometry.track {
            if segment.isDot {
                let angle = segment.start * .pi / 180
                let point = CGPoint(x: center.x + Self.radius * cos(angle), y: center.y + Self.radius * sin(angle))
                dotPath.append(UIBezierPath(arcCenter: point, radius: Self.lineWidth / 2, startAngle: 0,
                                            endAngle: 2 * .pi, clockwise: true))
            } else {
                trackPath.append(Self.arc(center: center, from: segment.start, to: segment.end))
            }
        }
        let fullArc = Self.arc(center: center, from: KpiGaugeGeometry.startAngle, to: KpiGaugeGeometry.endAngle)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for shapeLayer in [self.trackLayer, self.trackDotLayer, self.progressLayer] {
            shapeLayer.frame = self.bounds
        }
        self.trackLayer.path = trackPath.cgPath
        self.trackDotLayer.path = dotPath.cgPath
        self.progressLayer.path = fullArc.cgPath
        // The fill end angle depends on the threshold: re-map the resting value.
        if let fill = self.targetFill, self.fillAnimation == nil {
            self.progressLayer.strokeEnd = self.strokeEnd(forFill: fill)
        }
        CATransaction.commit()
    }

    private static func arc(center: CGPoint, from start: CGFloat, to end: CGFloat) -> UIBezierPath {
        return UIBezierPath(arcCenter: center, radius: Self.radius, startAngle: start * .pi / 180,
                            endAngle: end * .pi / 180, clockwise: true)
    }

    private func applyColors() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.trackLayer.strokeColor = self.trackColor.resolvedColor(with: self.traitCollection).cgColor
        self.trackDotLayer.fillColor = self.trackColor.resolvedColor(with: self.traitCollection).cgColor
        self.progressLayer.strokeColor = self.progressColor.resolvedColor(with: self.traitCollection).cgColor
        CATransaction.commit()
        self.valueLabel.textColor = self.progressColor
        self.percentLabel.textColor = self.trackColor
    }

    private func rest(fill: CGFloat, display: Int) {
        self.countTimer?.invalidate()
        self.countTimer = nil
        self.setModelStrokeEnd(self.strokeEnd(forFill: fill), hidden: fill == 0)
        self.valueLabel.text = "\(display)"
    }

    /// Nothing is drawn at fill 0: with round caps a zero-length stroke would still paint a dot.
    private func setModelStrokeEnd(_ strokeEnd: CGFloat, hidden: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.progressLayer.strokeEnd = strokeEnd
        self.progressLayer.isHidden = hidden
        CATransaction.commit()
    }

    private func cancelAnimation() {
        self.animationToken += 1
        self.countTimer?.invalidate()
        self.countTimer = nil
        self.progressLayer.removeAnimation(forKey: "fill")
    }

    private func startCount(from: Int, to: Int, token: Int) {
        self.valueLabel.text = "\(from)"
        var step = 0
        let interval = Self.animationDuration / Double(Self.countSteps)
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] timer in
            guard let self = self, self.animationToken == token else {
                timer.invalidate()
                return
            }
            step += 1
            let time = Double(step) / Double(Self.countSteps)
            // Follow the arc's ease-out so the number and the sweep stay together.
            let progress = 1 - (1 - time) * (1 - time)
            self.valueLabel.text = "\(Self.countedValue(from: from, to: to, progress: progress))"
            if step >= Self.countSteps { timer.invalidate() }
        }
        RunLoop.main.add(timer, forMode: .common) // keep counting while the table scrolls
        self.countTimer = timer
    }
}

/// D20 geometry of the gauge (amended: the fill covers the gap only strictly above the threshold),
/// in degrees on the stroke centreline (radius 57, stroke 6), screen
/// coordinates (clockwise from the positive x axis). Pure, so both the drawing and the specs use it.
struct KpiGaugeGeometry: Equatable {

    struct Segment: Equatable {
        let start: CGFloat
        let end: CGFloat
        /// Too short to stroke: drawn as a filled circle of the stroke's diameter at `start`.
        var isDot: Bool { self.end - self.start < 0.05 }
    }

    static let radius: CGFloat = 57
    static let lineWidth: CGFloat = 6
    static let startAngle: CGFloat = 183
    static let sweep: CGFloat = 174
    static var endAngle: CGFloat { startAngle + sweep }
    /// Angle a round cap (radius 3) covers on the centreline: asin(3/57), about 3.0°.
    static let cap: CGFloat = asin(3 / 57) * 180 / .pi
    /// The 4 px gap measured on the centreline: 4/57 rad, about 4.0°.
    static let gap: CGFloat = (4 / 57) * 180 / .pi
    /// The span shared by the two segments once the two inner caps and the gap are taken out (~164°).
    static let divisibleSpan: CGFloat = sweep - 2 * cap - gap

    /// One segment without a threshold (or with t <= 0 or t >= 1), two around the gap otherwise.
    let track: [Segment]
    /// End angle of the continuous fill arc (which always starts at `startAngle`).
    let fillEnd: CGFloat

    var hasGap: Bool { self.track.count == 2 }

    /// `meetsThreshold` is the backend's exact check: the percentage is rounded to 2 decimals, so
    /// `fill >= threshold` alone could disagree with it. The fill covers the gap only when both hold.
    init(threshold: CGFloat?, fill: CGFloat, meetsThreshold: Bool) {
        let value = min(1, max(0, fill))
        guard let threshold = threshold, threshold > 0, threshold < 1 else {
            self.track = [Segment(start: Self.startAngle, end: Self.endAngle)]
            self.fillEnd = Self.startAngle + Self.sweep * value
            return
        }
        let split = Self.startAngle + threshold * Self.divisibleSpan
        self.track = [Segment(start: Self.startAngle, end: split),
                      Segment(start: split + 2 * Self.cap + Self.gap, end: Self.endAngle)]
        // Up to the threshold the fill ends flush against the gap (at exactly t its cap coincides with
        // the left segment's end cap); only a value above the threshold covers the gap.
        let coversGap = meetsThreshold && value > threshold
        self.fillEnd = Self.startAngle + value * Self.divisibleSpan + (coversGap ? 2 * Self.cap + Self.gap : 0)
    }
}
