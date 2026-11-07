//
//  KpiGaugeView.swift
//  ForYouAndMe
//
//  FUAM-4315: half-ring gauge of the KPI widget (spec §3). A 120×120 box clipped to its top 60:
//  centre (60, 60), stroke centreline radius 57, stroke 6, round caps, start 183°, sweep 174°
//  clockwise over the top. 183° sits 3 pt above the centre line on purpose: that is where the cap
//  centres belong, so the caps end exactly at the clip edge.
//

import UIKit
import PureLayout

final class KpiGaugeView: UIView {

    static let size = CGSize(width: 120, height: 60)
    static let animationDuration: CFTimeInterval = 0.6
    private static let radius: CGFloat = 57
    private static let lineWidth: CGFloat = 6
    private static let startAngle: CGFloat = 183 * .pi / 180
    private static let sweepAngle: CGFloat = 174 * .pi / 180
    private static let countSteps = 12

    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let valueLabel = UILabel()
    private let percentLabel = UILabel()

    private var progressColor: UIColor = ColorPalette.color(withType: .kpiWidgetThreshold0)
    private var trackColor: UIColor = ColorPalette.color(withType: .inactive)

    // What is shown, or being animated to, and for which widget.
    private var widgetId: String?
    private var targetFill: CGFloat?
    private var targetDisplay: Int?
    private var animationToken: Int = 0
    private var countTimer: Timer?

    init() {
        super.init(frame: CGRect(origin: .zero, size: Self.size))
        self.clipsToBounds = true
        self.autoSetDimensions(to: Self.size)
        self.setContentCompressionResistancePriority(.required, for: .horizontal)
        self.setContentCompressionResistancePriority(.required, for: .vertical)
        self.setContentHuggingPriority(.required, for: .horizontal)

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

    /// Shows `fill`/`display` for widget `id`. With `animatedFrom` the arc sweeps from that fill and
    /// the number counts along; `completion` runs when the gauge rests on the new value (immediately
    /// when not animated). A no-op for the arc when `id` already shows or animates to the same value.
    // swiftlint:disable:next function_parameter_count
    func set(id: String,
             fill: CGFloat,
             display: Int,
             progressColor: UIColor,
             trackColor: UIColor,
             animatedFrom: CGFloat?,
             completion: @escaping () -> Void) {
        self.progressColor = progressColor
        self.trackColor = trackColor
        self.applyColors()
        self.accessibilityLabel = "\(display)%"

        if id == self.widgetId, fill == self.targetFill, display == self.targetDisplay {
            return
        }
        // The count starts from the number on screen; a fresh view derives it from the start fill.
        let shownDisplay = (id == self.widgetId ? self.valueLabel.text.flatMap { Int($0) } : nil)
            ?? Int((Double(animatedFrom ?? 0) * 100 + 1e-9).rounded(.down))
        self.cancelAnimation()
        self.widgetId = id
        self.targetFill = fill
        self.targetDisplay = display

        guard let from = animatedFrom, !UIAccessibility.isReduceMotionEnabled else {
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
        animation.toValue = fill
        animation.duration = Self.animationDuration
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        self.setModelStrokeEnd(fill, hidden: fill == 0 && from == 0)
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
        let path = UIBezierPath(arcCenter: CGPoint(x: self.bounds.midX, y: self.bounds.height),
                                radius: Self.radius,
                                startAngle: Self.startAngle,
                                endAngle: Self.startAngle + Self.sweepAngle,
                                clockwise: true).cgPath
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.trackLayer.frame = self.bounds
        self.progressLayer.frame = self.bounds
        self.trackLayer.path = path
        self.progressLayer.path = path
        CATransaction.commit()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if self.traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            self.applyColors()
        }
    }

    // MARK: - Private

    private func applyColors() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.trackLayer.strokeColor = self.trackColor.resolvedColor(with: self.traitCollection).cgColor
        self.progressLayer.strokeColor = self.progressColor.resolvedColor(with: self.traitCollection).cgColor
        CATransaction.commit()
        self.valueLabel.textColor = self.progressColor
        self.percentLabel.textColor = self.trackColor
    }

    private func rest(fill: CGFloat, display: Int) {
        self.countTimer?.invalidate()
        self.countTimer = nil
        self.setModelStrokeEnd(fill, hidden: fill == 0)
        self.valueLabel.text = "\(display)"
    }

    /// Nothing is drawn at fill 0: with round caps a zero-length stroke would still paint a dot.
    private func setModelStrokeEnd(_ fill: CGFloat, hidden: Bool) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        self.progressLayer.strokeEnd = fill
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
