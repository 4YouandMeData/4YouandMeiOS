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
    
    init(results: SOResults) {
        
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
        spiroTable.updatePEFRow(target: "", measurement: String(format: "%d L/m", self.results.pef_cLs), result: "OK")
        spiroTable.updateFEV1Row(target: "", measurement: String(format: "%d L/m", self.results.fev1_cL), result: "OK")
        
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
    
    @objc private func redoButtonPressed() {
        onRedoPressed?()
    }
    
    @objc private func doneButtonPressed() {
        onDonePressed?(results)
    }
}
