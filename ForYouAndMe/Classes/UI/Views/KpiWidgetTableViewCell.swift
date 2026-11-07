//
//  KpiWidgetTableViewCell.swift
//  ForYouAndMe
//
//  FUAM-4315: the KPI widget card at the top of the Feed. Chrome follows the sibling feed cards
//  (QuickActivityView: radius 8, cell shadow, no border); inner layout follows the design (§3).
//

import UIKit
import PureLayout

final class KpiWidgetTableViewCell: UITableViewCell {

    private static let lineHeightMultiple: CGFloat = 1.5
    // ponytail: unbounded memo keyed by id + body + size category; a handful of entries per day.
    private static var bodyCache: [String: NSAttributedString] = [:]

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        return label
    }()

    private let infoIconView: UIImageView = {
        let imageView = UIImageView(image: ImagePalette.templateImage(withName: .kpiInfo))
        imageView.tintColor = ColorPalette.color(withType: .inactive)
        imageView.contentMode = .scaleAspectFit
        imageView.autoSetDimensions(to: CGSize(width: 20, height: 20))
        imageView.setContentCompressionResistancePriority(.required, for: .horizontal)
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        return imageView
    }()

    private let bodyLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return label
    }()

    private let gaugeView = KpiGaugeView()
    private let titleRow = UIStackView.create(withAxis: .horizontal, spacing: 16)
    private lazy var titleTap = UITapGestureRecognizer(target: self, action: #selector(self.titleRowTapped))
    private var infoCallback: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        self.selectionStyle = .none
        self.backgroundColor = .clear
        self.contentView.backgroundColor = .clear

        // Same recipe as QuickActivityView: shadow on a clear container, rounded panel inside.
        let backgroundView = UIView()
        self.contentView.addSubview(backgroundView)
        backgroundView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 16.0,
                                                                       left: Constants.Style.DefaultHorizontalMargins,
                                                                       bottom: 0.0,
                                                                       right: Constants.Style.DefaultHorizontalMargins))
        backgroundView.addShadowCell()

        let panelView = UIView()
        panelView.backgroundColor = ColorPalette.color(withType: .secondary)
        panelView.layer.cornerRadius = 8.0
        panelView.layer.masksToBounds = true
        backgroundView.addSubview(panelView)
        panelView.autoPinEdgesToSuperviewEdges()

        let stackView = UIStackView.create(withAxis: .vertical, spacing: 8)
        panelView.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))

        self.titleRow.alignment = .center
        self.titleRow.addArrangedSubview(self.titleLabel)
        self.titleRow.addArrangedSubview(self.infoIconView)
        self.titleRow.addGestureRecognizer(self.titleTap)
        stackView.addArrangedSubview(self.titleRow)

        let contentRow = UIStackView.create(withAxis: .horizontal, spacing: 10)
        contentRow.alignment = .center
        contentRow.addArrangedSubview(self.bodyLabel)
        contentRow.addArrangedSubview(self.gaugeView)
        stackView.addArrangedSubview(contentRow)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public

    func display(widget: KpiWidget, store: KpiWidgetStore?, showInfo: Bool, infoCallback: @escaping () -> Void) {
        self.infoCallback = infoCallback

        // Title row: the title wraps; the info icon and the tap exist only with a configured message.
        if let title = widget.title {
            self.titleLabel.attributedText = NSAttributedString(string: title, attributes: [
                .font: Self.scaledFont(.paragraphBold, size: 16),
                .foregroundColor: ColorPalette.color(withType: .primaryText),
                .paragraphStyle: Self.paragraphStyle
            ])
        } else {
            self.titleLabel.attributedText = nil
        }
        self.titleLabel.isHidden = widget.title == nil
        self.infoIconView.isHidden = !showInfo
        self.titleTap.isEnabled = showInfo
        self.titleRow.isHidden = widget.title == nil && !showInfo

        // A nil body keeps the (empty) label so the gauge stays trailing.
        self.bodyLabel.attributedText = widget.body.map { Self.attributedBody($0, widgetId: widget.id) }

        let progressColor = ColorPalette.color(withType: widget.meetsThreshold ? .kpiWidgetThreshold1 : .kpiWidgetThreshold0)
        let fill = widget.fill
        let widgetId = widget.id
        self.gaugeView.set(id: widgetId,
                           fill: fill,
                           display: widget.displayPercent,
                           progressColor: progressColor,
                           trackColor: ColorPalette.color(withType: .inactive),
                           animatedFrom: store?.animationStart(for: widget),
                           completion: { [weak store] in store?.markRendered(widgetId: widgetId, fill: fill) })
    }

    // MARK: - Private

    @objc private func titleRowTapped() {
        self.infoCallback?()
    }

    private static var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = Self.lineHeightMultiple
        return style
    }

    /// Dynamic Type from the unscaled palette font, resized first (§3).
    private static func scaledFont(_ style: FontStyle, size: CGFloat) -> UIFont {
        return UIFontMetrics.default.scaledFont(for: FontPalette.baseFont(forStyle: style).withSize(size))
    }

    private static func attributedBody(_ body: String, widgetId: String) -> NSAttributedString {
        let key = "\(widgetId)|\(UIApplication.shared.preferredContentSizeCategory.rawValue)|\(body)"
        if let cached = self.bodyCache[key] { return cached }
        let regular = self.scaledFont(.paragraph, size: 15)
        let italicBase = FontPalette.baseFont(forStyle: .paragraph).withSize(15)
        let italic = italicBase.fontDescriptor.withSymbolicTraits(.traitItalic)
            .map { UIFontMetrics.default.scaledFont(for: UIFont(descriptor: $0, size: 15)) } ?? regular
        let attributed = body.kpiAttributedString(regular: regular,
                                                  bold: self.scaledFont(.paragraphBold, size: 15),
                                                  italic: italic,
                                                  color: ColorPalette.color(withType: .primaryText),
                                                  lineHeightMultiple: self.lineHeightMultiple)
        self.bodyCache[key] = attributed
        return attributed
    }
}
