//
//  SpyrometerResultsViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 24/03/25.
//

import Foundation
import MirSmartDevice

public class SpyrometerResultsViewController: UIViewController {
    
    /// Called when the scanning is completed and the user taps "Continue".
    var onRedoPressed: (() -> Void)?
    
    var onDonePressed: ((SOResults) -> Void)?
    
    /// Button to trigger connection (demo).
    private lazy var footerView: DoubleButtonHorizontalView = {
        let buttonView = DoubleButtonHorizontalView(
            styleCategory: .secondaryBackground(firstButtonPrimary: false,
                                                secondButtonPrimary: true))
        return buttonView
    }()
    
    private let spiroTable = SpiroTableView()
    
    private let results: SOResults
    
    /// Threshold for PEF (in L)
    private let pefStandard: Float?
    private let pefWarning: Float?
    
    /// Threshold for FEV1 (in L)
    private let fev1Standard: Float?
    private let fev1Warning: Float?
    
    /// Converter: from cL to L (valore decimale)
    private func clampToLiters(_ centiLiters: Int32) -> Float {
        // Example: if 719 cL → 7.19 L
        return Float(centiLiters) / 100.0
    }
    
    init(results: SOResults,
         pefStandard: Float?,
         pefWarning: Float?,
         fev1Standard: Float?,
         fev1Warning: Float?) {
        
        self.results = results
        self.pefStandard = pefStandard
        self.pefWarning = pefWarning
        self.fev1Standard = fev1Standard
        self.fev1Warning = fev1Warning
        
        super.init(nibName: nil, bundle: nil)

        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        let stackView = UIStackView.create(withAxis: .vertical, spacing: 16)
        self.view.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets(top: 25.0,
                                                                     left: Constants.Style.DefaultHorizontalMargins,
                                                                     bottom: 0,
                                                                     right: Constants.Style.DefaultHorizontalMargins),
                                                  excludingEdge: .bottom)
        
        stackView.addBlankSpace(space: 32)
        stackView.addLabel(withText: StringsProvider.string(
            forText: StringsProvider.string(forKey: .spiroTaskCompleteTitle)),
                           fontStyle: .title,
                           colorType: .primaryText,
                           textAlignment: .left)
        stackView.addBlankSpace(space: 20.0)
        stackView.addLabel(withText: StringsProvider.string(
            forText: StringsProvider.string(forKey: .spiroTaskCompleteBody)),
                           fontStyle: .paragraph,
                           colorType: .primaryText,
                           textAlignment: .justified)
        
        stackView.addBlankSpace(space: 42)
        stackView.addArrangedSubview(spiroTable)
        spiroTable.autoSetDimension(.height, toSize: 150, relation: .greaterThanOrEqual)
        spiroTable.parentViewController = self
        
        let pefLiters = clampToLiters(self.results.pef_cLs)
        let fev1Liters = clampToLiters(self.results.fev1_cL)
        
        let pefTargetString: String
        if let std = pefStandard {
            // For example “7.00 L/m”
            pefTargetString = String(format: "%.2f L/m", std)
        } else {
            pefTargetString = ""
        }
        
        let fev1TargetString: String
        if let std = fev1Standard {
            // Ad esempio “4.50 L”
            fev1TargetString = String(format: "%.2f L", std)
        } else {
            fev1TargetString = ""
        }
        
        let pefMeasuredString = String(format: "%.2f L/m", pefLiters)
        let fev1MeasuredString = String(format: "%.2f L", fev1Liters)
        
        let pefStatus  = statusMessage(
            measured:  pefLiters,
            standard:  pefStandard,
            warning:   pefWarning
        )
        let fev1Status = statusMessage(
            measured:  fev1Liters,
            standard:  fev1Standard,
            warning:   fev1Warning
        )
        
        spiroTable.updatePEFRow(
            target:      pefTargetString,
            measurement: pefMeasuredString,
            result:      pefStatus
        )
        spiroTable.updateFEV1Row(
            target:      fev1TargetString,
            measurement: fev1MeasuredString,
            result:      fev1Status
        )
        
        self.view.addSubview(self.footerView)
        
        // Connect button constraints.
        self.footerView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero, excludingEdge: .top)
        self.footerView.setFirstButtonText(StringsProvider.string(forKey: .spiroTaskButtonRedo))
        self.footerView.setSecondButtonText(StringsProvider.string(forKey: .spiroTaskButtonDone))
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        self.footerView.addTargetToFirstButton(target: self, action: #selector(self.redoButtonPressed))
        self.footerView.addTargetToSecondButton(target: self, action: #selector(self.doneButtonPressed))
    }
    
    func statusMessage(
        measured: Float,
        standard: Float?,
        warning: Float?) -> String {
        guard let std = standard, let warn = warning else {
            return "OK"
        }
        if measured >= std {
            return "OK"
        } else if measured >= warn {
            return "Warning"
        } else {
            return "Critical"
        }
    }
    
    @objc private func redoButtonPressed() {
        onRedoPressed?()
    }
    
    @objc private func doneButtonPressed() {
        onDonePressed?(results)
    }
}
