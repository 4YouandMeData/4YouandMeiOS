//
//  SpiroPopoverController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 25/03/25.
//

import UIKit
import PureLayout

/// A custom popover view controller that shows a title, a close button,
/// and a descriptive text. Looks like the screenshot with "Measurement target".
class SpiroPopoverController: UIViewController {
    
    private let titleLabel = UILabel()
    private var titleText: String = ""
    
    private let closeButton = UIButton(type: .system)
    
    private let bodyLabel = UILabel()
    private var bodyText: String = ""
    
    // MARK: - Init & Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        view.layer.cornerRadius = 10
        
        setupUI()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let fittingSize = view.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize)
        preferredContentSize = fittingSize
        bodyLabel.preferredMaxLayoutWidth = view.bounds.width - 32
    }
    
    // MARK: - Public
    
    func setBodyText(_ text: String) {
        self.bodyText = text
        bodyLabel.text = text  // Aggiorna il label
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
    
    func setTitleText(_ text: String) {
        self.titleText = text
        titleLabel.text = text  // Aggiorna il label
        view.setNeedsLayout()
        view.layoutIfNeeded()
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        // Aggiungiamo le subview
        view.addSubview(titleLabel)
        view.addSubview(closeButton)
        view.addSubview(bodyLabel)
        
        // Configure titleLabel
        titleLabel.text = titleText
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textAlignment = .left
        
        // Configure closeButton
        closeButton.setTitle("X", for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.tintColor = ColorPalette.color(withType: .primary)
        
        // Configure bodyLabel
        bodyLabel.text = bodyText
        bodyLabel.numberOfLines = 0
        bodyLabel.lineBreakMode = .byWordWrapping
        bodyLabel.font = UIFont.systemFont(ofSize: 14)
        bodyLabel.textAlignment = .justified
        
        [titleLabel, closeButton, bodyLabel].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        
        // Layout constraints
        titleLabel.autoPinEdge(toSuperviewEdge: .top, withInset: 24)
        titleLabel.autoPinEdge(toSuperviewEdge: .left, withInset: 16)
        
        closeButton.autoPinEdge(toSuperviewEdge: .top, withInset: 8)
        closeButton.autoPinEdge(toSuperviewEdge: .right, withInset: 8)
        closeButton.autoSetDimension(.width, toSize: 44)
        closeButton.autoSetDimension(.height, toSize: 44)
        
        bodyLabel.autoPinEdge(.top, to: .bottom, of: titleLabel, withOffset: 12)
        bodyLabel.autoPinEdge(toSuperviewEdge: .left, withInset: 16)
        bodyLabel.autoPinEdge(toSuperviewEdge: .right, withInset: 16)
        bodyLabel.autoPinEdge(toSuperviewEdge: .bottom, withInset: 24)
    }
    
    // MARK: - Actions
    
    @objc private func closeTapped() {
        dismiss(animated: true, completion: nil)
    }
}

// MARK: - UIPopoverPresentationControllerDelegate
extension SpiroPopoverController: UIPopoverPresentationControllerDelegate {
    
    /// Forza lo stile .none anche su iPhone, impedendo di adattarsi a schermo intero.
    func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        return .none
    }
    
    /// (Opzionale) Se vuoi fare qualcosa quando il popover viene dismesso toccando fuori
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        // ...
    }
}
