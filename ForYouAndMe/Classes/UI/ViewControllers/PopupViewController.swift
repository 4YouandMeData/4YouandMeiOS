//
//  PopupViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 18/06/2020.
//

import Foundation
import PureLayout

protocol PopupCoordinator {
    func onConfirmButtonPressed(popupViewController: PopupViewController)
    func onCloseButtonPressed(popupViewController: PopupViewController)
}

struct PopupData {
    let body: String
    let buttonText: String
}

public class PopupViewController: UIViewController {
    
    private let data: PopupData
    private let coordinator: PopupCoordinator
    
    init(withData data: PopupData, coordinator: PopupCoordinator) {
        self.data = data
        self.coordinator = coordinator
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.overlayColor
        
        let panelView = UIView()
        panelView.backgroundColor = ColorPalette.color(withType: .secondary)
        self.view.addSubview(panelView)
        panelView.autoPinEdge(toSuperviewEdge: .leading, withInset: Constants.Style.DefaultHorizontalMargins)
        panelView.autoPinEdge(toSuperviewEdge: .trailing, withInset: Constants.Style.DefaultHorizontalMargins)
        panelView.autoPinEdge(toSuperviewSafeArea: .top,
                              withInset: Constants.Style.DefaultHorizontalMargins,
                              relation: .greaterThanOrEqual)
        panelView.autoPinEdge(toSuperviewSafeArea: .bottom,
                              withInset: Constants.Style.DefaultHorizontalMargins,
                              relation: .greaterThanOrEqual)
        panelView.autoAlignAxis(toSuperviewAxis: .horizontal)
        panelView.round(radius: 8.0)
        
        // StackView
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 12.0
        panelView.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 12.0, left: 12.0, bottom: 0.0, right: 12.0))
        
        // Close button
        let closeButton = UIButton()
        closeButton.setImage(ImagePalette.image(withName: .closeButton), for: .normal)
        closeButton.addTarget(self, action: #selector(self.closeButtonPressed), for: .touchUpInside)
        closeButton.contentEdgeInsets = UIEdgeInsets(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0)
        
        let closeButtonContainerView = UIView()
        closeButtonContainerView.addSubview(closeButton)
        closeButton.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .trailing)
        stackView.addArrangedSubview(closeButtonContainerView)
        
        // Body
        stackView.addLabel(withText: self.data.body, fontStyle: .paragraph, colorType: .primaryText)
        
        // Confirm Button
        let confirmButton = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false),
                                              horizontalInset: 0.0,
                                              topInset: 24.0,
                                              bottomInset: 24.0)
        confirmButton.setButtonText(self.data.buttonText)
        confirmButton.addTarget(target: self, action: #selector(self.confirmButtonPressed))
        stackView.addArrangedSubview(confirmButton)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.apply(style: NavigationBarStyles.hiddenStyle)
    }
    
    // MARK: Actions
    
    @objc private func confirmButtonPressed() {
        self.coordinator.onConfirmButtonPressed(popupViewController: self)
    }
    
    @objc private func closeButtonPressed() {
        self.coordinator.onCloseButtonPressed(popupViewController: self)
    }
}
