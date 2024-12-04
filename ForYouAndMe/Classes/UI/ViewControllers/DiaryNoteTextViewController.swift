//
//  DiaryNoteTextViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 03/12/24.
//

import UIKit
import RxSwift

class DiaryNoteTextViewController: UIViewController {
    
    private let navigator: AppNavigator
    private let repository: Repository
    private let analytics: AnalyticsService
    
    private let disposeBag = DisposeBag()
    
    private lazy var closeButton: UIButton = {
        let button = UIButton()
        button.setImage(ImagePalette.templateImage(withName: .backButtonNavigation), for: .normal)
        button.tintColor = ColorPalette.color(withType: .primaryText)
        button.autoSetDimension(.width, toSize: 32)
        button.imageView?.contentMode = .scaleAspectFit
        button.addTarget(self, action: #selector(self.closeButtonPressed), for: .touchUpInside)
        return button
    }()
    
    private lazy var headerView: UIView = {
        let containerView = UIView()
        
        let stackView = UIStackView.create(withAxis: .vertical, spacing: 8.0)
        
        // Close button
        let closeButtonContainerView = UIView()
        closeButtonContainerView.addSubview(self.closeButton)
        self.closeButton.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .trailing)
        stackView.addArrangedSubview(closeButtonContainerView)

        stackView.addLabel(withText: "Text Note",
                           fontStyle: .title,
                           colorType: .primaryText)
        
        stackView.addLineSeparator(lineColor: ColorPalette.color(withType: .secondaryMenu), space: 0, isVertical: false)
        
        containerView.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 25.0,
                                                                     left: Constants.Style.DefaultHorizontalMargins/2,
                                                                     bottom: 0,
                                                                     right: Constants.Style.DefaultHorizontalMargins/2))
        return containerView
    }()
    
    private lazy var textView: UIView = {
        
        let container = UIView()
        // Text View
        let textView = UITextView()
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 8
        textView.typingAttributes = [.foregroundColor: ColorPalette.color(withType: .primaryText),
                                     .font: FontPalette.fontStyleData(forStyle: .header3).font,
                                     .paragraphStyle: style]
        textView.delegate = self
        textView.layer.borderWidth = 1
        textView.tintColor = ColorPalette.color(withType: .primary)
        textView.layer.borderColor = ColorPalette.color(withType: .inactive).cgColor
        textView.backgroundColor = .red
        
        // Toolbar
        let toolBar = UIToolbar()
        toolBar.barStyle = .default
        toolBar.isTranslucent = true
        toolBar.tintColor = ColorPalette.color(withType: .primary)
        toolBar.sizeToFit()
        
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.doneButtonPressed))
        let spaceButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolBar.setItems([spaceButton, doneButton], animated: false)
        textView.inputAccessoryView = toolBar
        container.addSubview(textView)
        
        textView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0,
                                                                 left: 12.0,
                                                                 bottom: 0.0,
                                                                 right: 12.0))
        
        return container
    }()
    
    private lazy var footerView: UIView = {
        
        let containerView = UIView()
                
        let buttonView = GenericButtonView(withTextStyleCategory: .secondaryBackground())
        buttonView.setButtonText(StringsProvider.string(forKey: .onboardingOptInSubmitButton))
        buttonView.addTarget(target: self, action: #selector(self.editButtonPressed))
        
        containerView.addSubview(buttonView)
        buttonView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero)
        
        return containerView
    }()
    
    private var storage: CacheService
    private let dataPointID: String
    
    init(withDataPointID dataPointID: String) {
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        self.storage = Services.shared.storageServices
        self.analytics = Services.shared.analytics
        self.dataPointID = dataPointID
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("DiaryNoteTextViewController - deinit")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        // Main Stack View
        let stackView = UIStackView.create(withAxis: .vertical)
        self.view.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges()
                
        stackView.addArrangedSubview(self.headerView)
        stackView.addArrangedSubview(self.textView)
        stackView.addBlankSpace(space: 60.0)
        stackView.addArrangedSubview(self.footerView)
        
        self.textView.autoPinEdge(.top, to: .bottom, of: self.headerView)
        self.updateUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
    }
    
    // MARK: - Actions
    
    @objc private func closeButtonPressed() {
        self.customBackButtonPressed()
    }
    
    @objc private func editButtonPressed() {
        
    }
    
    @objc private func doneButtonPressed() {
        self.textView.resignFirstResponder()
    }
    
    // MARK: - Private Methods
    
    private func updateUI() {
    }
}

extension DiaryNoteTextViewController: UITextViewDelegate {
    
}
