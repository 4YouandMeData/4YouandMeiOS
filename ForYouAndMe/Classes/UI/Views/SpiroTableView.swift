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
//    private let headerCol2 = UILabel()
    private let headerCol3 = UILabel()
//    private let headerCol4 = UILabel()
    
    // Row 1 (PEF)
    private let row1Stack = UIStackView()
    private let row1Col1 = UIButton(type: .system)
//    private let row1Col2 = UILabel()
    private let row1Col3 = UILabel()
//    private let row1Col4 = UILabel()
    
    // Row 2 (FEV1)
    private let row2Stack = UIStackView()
    private let row2Col1 = UIButton(type: .system)
//    private let row2Col2 = UILabel()
    private let row2Col3 = UILabel()
//    private let row2Col4 = UILabel()
    
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
        layer.borderColor = UIColor.lightGray.cgColor
        layer.borderWidth = 1.0
        
        // Container stack (vertical)
        containerStack.axis = .vertical
        containerStack.alignment = .fill
        containerStack.distribution = .fillEqually
        containerStack.spacing = 1.0
        containerStack.backgroundColor = .lightGray
        
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
        headerStack.spacing = 1.0
        headerStack.backgroundColor = .lightGray
        
        // 4 columns
        headerStack.addArrangedSubview(headerCol1)
//        headerStack.addArrangedSubview(headerCol2)
        headerStack.addArrangedSubview(headerCol3)
//        headerStack.addArrangedSubview(headerCol4)
        
//        headerCol2.text = StringsProvider.string(forKey: .spiroTaskTargets)
//        headerCol2.font = FontPalette.fontStyleData(forStyle: .infoNote).font
//        headerCol2.textColor = ColorPalette.color(withType: .primaryText)
//        headerCol2.textAlignment = .center
//        headerCol2.sizeToFit()
        
        headerCol3.text = StringsProvider.string(forKey: .spiroTaskMeasurements)
        headerCol3.font = FontPalette.fontStyleData(forStyle: .infoNote).font
        headerCol3.textColor = ColorPalette.color(withType: .primaryText)
        headerCol3.textAlignment = .center
        headerCol3.sizeToFit()
        
//        headerCol4.text = StringsProvider.string(forKey: .spiroTaskResults)
//        headerCol4.font = FontPalette.fontStyleData(forStyle: .infoNote).font
//        headerCol4.textColor = ColorPalette.color(withType: .primaryText)
//        headerCol4.textAlignment = .center
//        headerCol4.sizeToFit()
        
        // Optional styling
        [headerCol1, headerCol3].forEach {
            if let lbl = $0 as? UILabel {
                lbl.backgroundColor = .systemGray5
            } else if let btn = $0 as? UIButton {
                btn.backgroundColor = .systemGray5
            }
        }
    }
    
    private func setupRow1() {
        row1Stack.axis = .horizontal
        row1Stack.alignment = .fill
        row1Stack.distribution = .fillEqually
        row1Stack.spacing = 1.0
        row1Stack.backgroundColor = .lightGray
        
        row1Stack.addArrangedSubview(row1Col1)
//        row1Stack.addArrangedSubview(row1Col2)
        row1Stack.addArrangedSubview(row1Col3)
//        row1Stack.addArrangedSubview(row1Col4)
        
        // row1Col1 as a button
        row1Col1.setTitle("PEF ?", for: .normal)
        row1Col1.addTarget(self, action: #selector(pefButtonTapped(_:)), for: .touchUpInside)
        row1Col1.backgroundColor = .white
        
//        row1Col2.text = "700 L/m"
        row1Col3.text = "719 L/m"
//        row1Col4.text = "OK"
        
//        row1Col2.textAlignment = .center
//        row1Col2.backgroundColor = .white
        row1Col3.textAlignment = .center
        row1Col3.backgroundColor = .white
//        row1Col4.textAlignment = .center
//        row1Col4.textColor = .systemGreen
//        row1Col4.backgroundColor = .white
        
//        row1Col2.font = FontPalette.fontStyleData(forStyle: .infoNote).font
        row1Col3.font = FontPalette.fontStyleData(forStyle: .infoNote).font
//        row1Col4.font = FontPalette.fontStyleData(forStyle: .infoNote).font
    }
    
    private func setupRow2() {
        row2Stack.axis = .horizontal
        row2Stack.alignment = .fill
        row2Stack.distribution = .fillEqually
        row2Stack.spacing = 1.0
        row2Stack.backgroundColor = .lightGray
        
        row2Stack.addArrangedSubview(row2Col1)
//        row2Stack.addArrangedSubview(row2Col2)
        row2Stack.addArrangedSubview(row2Col3)
//        row2Stack.addArrangedSubview(row2Col4)
        
        // row2Col1 as a button
        row2Col1.setTitle("FEV1 ?", for: .normal)
        row2Col1.addTarget(self, action: #selector(fev1ButtonTapped(_:)), for: .touchUpInside)
        row2Col1.backgroundColor = .white
        
//        row2Col2.text = "3.5 L"
//        row2Col2.backgroundColor = .white
        row2Col3.text = "4.64 L"
        row2Col3.backgroundColor = .white
//        row2Col4.text = "Warning"
//        row2Col4.backgroundColor = .white
        
//        row2Col2.textAlignment = .center
        row2Col3.textAlignment = .center
//        row2Col4.textAlignment = .center
//        row2Col4.textColor = .systemOrange
        
//        row2Col2.font = FontPalette.fontStyleData(forStyle: .infoNote).font
        row2Col3.font = FontPalette.fontStyleData(forStyle: .infoNote).font
//        row2Col4.font = FontPalette.fontStyleData(forStyle: .infoNote).font
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
    
    // MARK: - Public API to update values
    
    /// Updates the values displayed in the PEF row.
    /// - Parameters:
    ///   - target: The target value (e.g., "700 L/m").
    ///   - measurement: The measured value (e.g., "719 L/m").
    ///   - result: The result status (e.g., "OK").
    public func updatePEFRow(target: String, measurement: String, result: String) {
//        row1Col2.text = target
        row1Col3.text = measurement
//        row1Col4.text = result
    }
    
    /// Updates the values displayed in the FEV1 row.
    /// - Parameters:
    ///   - target: The target value (e.g., "3.5 L").
    ///   - measurement: The measured value (e.g., "4.64 L").
    ///   - result: The result status (e.g., "Warning").
    public func updateFEV1Row(target: String, measurement: String, result: String) {
//        row2Col2.text = target
        row2Col3.text = measurement
//        row2Col4.text = result
    }
}
