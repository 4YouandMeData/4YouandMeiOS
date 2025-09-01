//
//  SuccessViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 06/06/25.
//

import UIKit
import PureLayout

/// A simple view controller that shows a “Success” message and a circular “next” button at the bottom-center.
class SuccessViewController: UIViewController {
    
    // MARK: – UI Subviews
    
    /// A vertical scroll stack to hold title and body text (in case body fosse più lungo dello schermo)
    private let scrollStack: ScrollStackView = {
        let sv = ScrollStackView(axis: .vertical,
                                 horizontalInset: Constants.Style.DefaultHorizontalMargins)
        return sv
    }()
    
    /// Title label (“Success!”)
    private let titleLabel: UILabel = {
        let lbl = UILabel()
        lbl.numberOfLines = 0
        lbl.textAlignment = .center
        lbl.font = UIFont.boldSystemFont(ofSize: 28) // usa dimensione simile a .title in InfoPage
        lbl.textColor = ColorPalette.color(withType: .primaryText)
        return lbl
    }()
    
    /// Body label (paragrafo sotto il titolo)
    private let bodyLabel: UILabel = {
        let lbl = UILabel()
        lbl.numberOfLines = 0
        lbl.textAlignment = .center
        lbl.font = UIFont.systemFont(ofSize: FontPalette.fontStyleData(forStyle: .paragraph).font.pointSize)
        lbl.textColor = ColorPalette.color(withType: .primaryText)
        return lbl
    }()
    
    // MARK: – Public API
    
    /// Called when user taps the circular next button
    var onConfirm: (() -> Void)?
    
    // MARK: – Init
    
    init() {
        super.init(nibName: nil, bundle: nil)
        // Configure title and body from localized strings
        titleLabel.text = StringsProvider.string(forKey: .noticedStepSuccessTitle)
        bodyLabel.text  = StringsProvider.string(forKey: .noticedStepSuccessMessage)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: – Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ColorPalette.color(withType: .secondary)
        setupLayout()
    }
    
    // MARK: – Layout
    
    private func setupLayout() {
        // Add scrollStack to view
        view.addSubview(scrollStack)
        scrollStack.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)
        
        scrollStack.stackView.addBlankSpace(space: 100)
        
        // Title
        scrollStack.stackView.addArrangedSubview(titleLabel)
        
        scrollStack.stackView.addBlankSpace(space: 20)
        
        // Body
        scrollStack.stackView.addArrangedSubview(bodyLabel)
        
        let bottomView = GenericButtonView(withImageStyleCategory: .secondaryBackground)
        bottomView.addTarget(target: self, action: #selector(nextTapped))
        self.view.addSubview(bottomView)
        bottomView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets.zero, excludingEdge: .top)
        scrollStack.scrollView.autoPinEdge(.bottom, to: .top, of: bottomView)
    }
    
    // MARK: – Actions
    
    @objc private func nextTapped() {
        onConfirm?()
    }
}
