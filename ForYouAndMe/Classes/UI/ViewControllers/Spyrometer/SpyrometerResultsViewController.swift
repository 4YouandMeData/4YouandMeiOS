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
    
    private let feed: Feed
    
    private var shouldShowMirWarning: Bool = false
    
    /// Converter: from cL to L (valore decimale)
    private func clampToLiters(_ centiLiters: Int32) -> Float {
        // Example: if 719 cL → 7.19 L
        return Float(centiLiters) / 100.0
    }
    
    init(feed: Feed, results: SOResults) {
        
        self.feed = feed
        self.results = results
        
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
        
        evaluateMirDropFlag()

        populateTable()
        
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
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if shouldShowMirWarning {
            showWarningScreen()
            shouldShowMirWarning = false
        }
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
    
    private func evaluateMirDropFlag() {
        
        let fev1Liters = Double(results.fev1_cL)
        let previous    = feed.previousFev1
        let threshold   = feed.mirThreshold
        
        guard let prev = previous, let thr = threshold else {
            shouldShowMirWarning = false
            return
        }
        
        let dropAmount     = prev - fev1Liters
        let dropPercentage = dropAmount / prev
        
        shouldShowMirWarning = (dropPercentage > thr)
    }
    
    private func populateTable() {

        let pefLiters  = Float(results.pef_cLs) / 100.0
        let fev1Liters = Float(results.fev1_cL) / 100.0
        
        let pefStd      = feed.pefThresholdStandard
        let pefWarn     = feed.pefThresholdWarning
        let fev1Std     = feed.fev1ThresholdStandard
        let fev1Warn    = feed.fev1ThresholdWarning
        
        let pefTargetString: String = {
            if let std = pefStd {
                // Esempio: “7.00 L/m”
                return String(format: "%.2f L/m", std)
            } else {
                return ""
            }
        }()
        let fev1TargetString: String = {
            if let std = fev1Std {
                // Esempio: “4.50 L”
                return String(format: "%.2f L", std)
            } else {
                return ""
            }
        }()
        
        let pefMeasuredString  = String(format: "%.2f L/m", pefLiters)
        let fev1MeasuredString = String(format: "%.2f L", fev1Liters)
        
        let pefStatus  = statusMessage(measured: pefLiters, standard: pefStd, warning: pefWarn)
        let fev1Status = statusMessage(measured: fev1Liters, standard: fev1Std, warning: fev1Warn)
        
        spiroTable.updatePEFRow(
            target: pefTargetString,
            measurement: pefMeasuredString,
            result: pefStatus
        )
        spiroTable.updateFEV1Row(
            target: fev1TargetString,
            measurement: fev1MeasuredString,
            result: fev1Status
        )
    }
    
    private func showWarningScreen() {
    
        let warningVC = SpirometryWarningViewController()
        warningVC.modalPresentationStyle = .pageSheet
        if let sheet = warningVC.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.preferredCornerRadius = 16
        }
        self.present(warningVC, animated: true, completion: nil)
    }
    
    @objc private func redoButtonPressed() {
        onRedoPressed?()
    }
    
    @objc private func doneButtonPressed() {
        onDonePressed?(results)
    }
}
