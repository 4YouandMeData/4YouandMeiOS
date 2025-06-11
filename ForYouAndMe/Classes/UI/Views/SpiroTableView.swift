//
//  SpiroTableView.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 25/03/25.
//

import UIKit
import PureLayout

/// A custom view that mimics a table with a header row and two data rows:
///   1) Header: "Targets?", "Measurements?", "Results?"
///   2) Row #1 for PEF
///   3) Row #2 for FEV1
///
/// Each "?" is now a UIButton that, when tapped, will show a callout with more info.
class SpiroTableView: UIView {
    
    // MARK: - Subviews
    
    private let containerStack = UIStackView() // The vertical stack containing header + rows
    
    // Header row (4 columns: param? / Targets? / Measurements? / Results?)
    private let headerStack = UIStackView()
    private let headerCol1 = UIButton(type: .system)
    private let headerCol3 = UILabel()
        
    // Row 1 (PEF)
    private let row1Stack = UIStackView()
    private let row1Col2 = UILabel()
    private let row1Col3 = UILabel()
    private let row1Col4 = UILabel()
    
    // Row 2 (FEV1)
    private let row2Stack = UIStackView()
    private let row2Col2 = UILabel()
    private let row2Col3 = UILabel()
    private let row2Col4 = UILabel()
    
    // We assume the view controller that contains this view
    // will be set as a "weak" reference or we can store a closure
    // to present popovers. For simplicity, let's store a parentVC reference.
    // Make sure to set it from the outside if you need the popover logic.
    weak var parentViewController: UIViewController?
    
    // MARK: - Init
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    // MARK: - Setup
    
    private func setupView() {
        backgroundColor = .white
        layer.borderColor = UIColor.init(hexString: "#E4E4E4")?.cgColor
        layer.borderWidth = 1.0
        
        // Container stack (vertical)
        containerStack.axis = .vertical
        containerStack.alignment = .fill
        containerStack.distribution = .fillEqually
        
        addSubview(containerStack)
        containerStack.autoPinEdgesToSuperviewEdges()
        
        // Build each row
        setupHeaderRow()
        setupRow1()
        setupRow2()
        
        // Add them to the vertical stack
        containerStack.addArrangedSubview(headerStack)
        containerStack.addArrangedSubview(row1Stack)
        containerStack.addArrangedSubview(row2Stack)
    }
    
    private func setupHeaderRow() {
        headerStack.axis = .horizontal
        headerStack.alignment = .fill
        headerStack.distribution = .fillEqually
        headerStack.backgroundColor = UIColor.init(hexString: "#F5F5F5")
        headerStack.layer.borderWidth = 1.0
        headerStack.layer.borderColor = UIColor.init(hexString: "#E4E4E4")?.cgColor
        
        // 4 columns
        headerStack.addArrangedSubview(headerCol1)
        
        let targetCell = makeInfoCell(
            title: StringsProvider.string(forKey: .spiroTaskTargets),
            fontStyle: .infoNote,
            colorType: .primaryText,
            infoImage: .questionIcon,
            action: #selector(targetsButtonTapped(_:)),
            target: self
        )
        headerStack.addArrangedSubview(targetCell)
        
        headerStack.addArrangedSubview(headerCol3)
        headerCol3.text = StringsProvider.string(forKey: .spiroTaskMeasurements)
        headerCol3.font = FontPalette.fontStyleData(forStyle: .infoNote).font
        headerCol3.textColor = ColorPalette.color(withType: .primaryText)
        headerCol3.textAlignment = .center
        headerCol3.sizeToFit()
        
        let measCell = makeInfoCell(
            title: StringsProvider.string(forKey: .spiroTaskResults),
            fontStyle: .infoNote,
            colorType: .primaryText,
            infoImage: .questionIcon,
            action: #selector(resultsButtonTapped(_:)),
            target: self
        )
        headerStack.addArrangedSubview(measCell)
    }
    
    private func setupRow1() {
        row1Stack.axis = .horizontal
        row1Stack.alignment = .fill
        row1Stack.distribution = .fillEqually
        
        let pefCell = makeInfoCell(
            title: "PEF",
            action: #selector(pefButtonTapped(_:)),
            target: self
        )
        row1Stack.addArrangedSubview(pefCell)
        row1Stack.addArrangedSubview(row1Col2)
        row1Stack.addArrangedSubview(row1Col3)
        row1Stack.addArrangedSubview(row1Col4)
        
        // row1Col1 as a button
        
        row1Col2.text = "700 L/m"
        row1Col3.text = "719 L/m"
        row1Col4.text = "OK"
        
        row1Col2.textAlignment = .center
        row1Col2.backgroundColor = .white
        row1Col2.layer.borderColor =  UIColor.init(hexString: "#E4E4E4")?.cgColor
        row1Col2.layer.borderWidth = 1
        row1Col3.textAlignment = .center
        row1Col3.backgroundColor = .white
        row1Col3.layer.borderColor =  UIColor.init(hexString: "#E4E4E4")?.cgColor
        row1Col3.layer.borderWidth = 1
        row1Col4.textAlignment = .center
        row1Col4.textColor = .systemGreen
        row1Col4.backgroundColor = .white
        row1Col4.layer.borderColor =  UIColor.init(hexString: "#E4E4E4")?.cgColor
        row1Col4.layer.borderWidth = 1
        
        row1Col2.font = FontPalette.fontStyleData(forStyle: .infoNote).font
        row1Col3.font = FontPalette.fontStyleData(forStyle: .infoNote).font
        row1Col4.font = FontPalette.fontStyleData(forStyle: .infoNote).font
    }
    
    private func setupRow2() {
        row2Stack.axis = .horizontal
        row2Stack.alignment = .fill
        row2Stack.distribution = .fillEqually
        row2Stack.backgroundColor = .lightGray
        
        let fevCell = makeInfoCell(
            title: "FEV1",
            action: #selector(fev1ButtonTapped(_:)),
            target: self
        )
        row2Stack.addArrangedSubview(fevCell)
        row2Stack.addArrangedSubview(row2Col2)
        row2Stack.addArrangedSubview(row2Col3)
        row2Stack.addArrangedSubview(row2Col4)
        
        // row2Col1 as a button
        row2Col2.text = "3.5 L"
        row2Col2.backgroundColor = .white
        row2Col2.layer.borderColor =  UIColor.init(hexString: "#E4E4E4")?.cgColor
        row2Col2.layer.borderWidth = 1
        row2Col3.text = "4.64 L"
        row2Col3.backgroundColor = .white
        row2Col3.layer.borderColor =  UIColor.init(hexString: "#E4E4E4")?.cgColor
        row2Col3.layer.borderWidth = 1
        row2Col4.text = "Warning"
        row2Col4.backgroundColor = .white
        row2Col4.layer.borderColor =  UIColor.init(hexString: "#E4E4E4")?.cgColor
        row2Col4.layer.borderWidth = 1
        
        row2Col2.textAlignment = .center
        row2Col3.textAlignment = .center
        row2Col4.textAlignment = .center
        row2Col4.textColor = .systemOrange
        
        row2Col2.font = FontPalette.fontStyleData(forStyle: .infoNote).font
        row2Col3.font = FontPalette.fontStyleData(forStyle: .infoNote).font
        row2Col4.font = FontPalette.fontStyleData(forStyle: .infoNote).font
    }
    
    // MARK: - Button Actions
    
    @objc private func pefButtonTapped(_ sender: UIButton) {
        showCallout(from: sender, withTitle: StringsProvider.string(forKey: .spiroTaskPefCalloutTitle),
                    withMessage: StringsProvider.string(forKey: .spiroTaskFev1CalloutBody))
    }
    
    @objc private func fev1ButtonTapped(_ sender: UIButton) {
        showCallout(from: sender, withTitle: StringsProvider.string(forKey: .spiroTaskFev1CalloutTitle),
                    withMessage: StringsProvider.string(forKey: .spiroTaskFev1CalloutBody))
    }
    
    @objc private func targetsButtonTapped(_ sender: UIButton) {
        showCallout(from: sender, withTitle: StringsProvider.string(forKey: .spiroTaskMeasCalloutTitle),
                    withMessage: StringsProvider.string(forKey: .spiroTaskMeasCalloutBody))
    }
    
    @objc private func resultsButtonTapped(_ sender: UIButton) {
        showCallout(from: sender, withTitle: StringsProvider.string(forKey: .spiroTaskResultsCalloutTitle),
                    withMessage: StringsProvider.string(forKey: .spiroTaskResultsCalloutBody))
    }
    
    // MARK: - Callout / Popover
    
    private func showCallout(from source: UIView, withTitle title: String, withMessage message: String) {
        guard let vc = parentViewController else { return }
            
        let popVC = SpiroPopoverController()
        popVC.modalPresentationStyle = .popover
        popVC.setTitleText(title)
        popVC.setBodyText(message)
        
        if let popover = popVC.popoverPresentationController {
            popover.sourceView = source
            popover.sourceRect = source.bounds
            popover.permittedArrowDirections = [.up, .down] // o .any
            popover.delegate = popVC
        }
        
        vc.present(popVC, animated: true, completion: nil)
    }
    
    func makeInfoCell(
        title: String,
        fontStyle: FontStyle = .infoNote,
        colorType: ColorType = .primaryText,
        infoImage: TemplateImageName = .questionIcon,
        tag: Int = 0,
        action: Selector,
        target: Any
    ) -> UIView {
        // Container view
        let cell = UIView()
        cell.backgroundColor = .white
        cell.backgroundColor = UIColor.init(hexString: "#F5F5F5")
        cell.layer.borderColor = UIColor(hexString: "#E4E4E4")?.cgColor
        cell.layer.borderWidth = 1.0

        // Label
        let label = UILabel()
        let styleData = FontPalette.fontStyleData(forStyle: fontStyle)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        paragraph.lineSpacing = styleData.lineSpacing
        let attrs: [NSAttributedString.Key: Any] = [
            .font: styleData.font,
            .foregroundColor: ColorPalette.color(withType: colorType),
            .paragraphStyle: paragraph
        ]
        let text = styleData.uppercase ? title.uppercased() : title
        label.attributedText = NSAttributedString(string: text, attributes: attrs)
        label.numberOfLines = 1
        cell.addSubview(label)

        // Info‐button
        let btn = UIButton(type: .system)
        btn.setImage(ImagePalette.templateImage(withName: infoImage), for: .normal)
        btn.tintColor = ColorPalette.color(withType: .primary)
        btn.tag = tag
        btn.addTarget(target, action: action, for: .touchUpInside)
        cell.addSubview(btn)

        let margin: CGFloat = Constants.Style.DefaultHorizontalMargins/2
        label.autoPinEdge(toSuperviewEdge: .leading, withInset: margin)
        label.autoAlignAxis(toSuperviewAxis: .horizontal)
        btn.autoPinEdge(toSuperviewEdge: .trailing, withInset: margin/2)
        btn.autoAlignAxis(toSuperviewAxis: .horizontal)

        return cell
    }
    
    // MARK: - Public API to update values
    
    /// Updates the values displayed in the PEF row.
    /// - Parameters:
    ///   - target: The target value (e.g., "700 L/m").
    ///   - measurement: The measured value (e.g., "719 L/m").
    ///   - result: The result status (e.g., "OK").
    public func updatePEFRow(target: String, measurement: String, result: String) {
        row1Col2.text = target
        row1Col3.text = measurement
        row1Col4.text = result
        
        switch result.lowercased() {
        case "ok":
            row1Col4.textColor = .systemGreen
        case "warning":
            row1Col4.textColor = .systemOrange
        case "critical":
            row1Col4.textColor = .systemRed
        default:
            row1Col4.textColor = ColorPalette.color(withType: .primaryText)
        }
    }
    
    /// Updates the values displayed in the FEV1 row.
    /// - Parameters:
    ///   - target: The target value (e.g., "3.5 L").
    ///   - measurement: The measured value (e.g., "4.64 L").
    ///   - result: The result status (e.g., "Warning").
    public func updateFEV1Row(target: String, measurement: String, result: String) {
        row2Col2.text = target
        row2Col3.text = measurement
        row2Col4.text = result
        
        switch result.lowercased() {
        case "ok":
            row2Col4.textColor = .systemGreen
        case "warning":
            row2Col4.textColor = .systemOrange
        case "critical":
            row2Col4.textColor = .systemRed
        default:
            row2Col4.textColor = ColorPalette.color(withType: .primaryText)
        }
    }
}
