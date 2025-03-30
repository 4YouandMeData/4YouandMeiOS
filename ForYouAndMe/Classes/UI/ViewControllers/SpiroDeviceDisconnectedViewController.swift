//
//  SpiroDeviceDisconnectedViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 30/03/25.
//

class SpiroDeviceDisconnectedViewController: UIViewController {
    
    var onNextPressed: (() -> Void)?

    private lazy var footerView: GenericButtonView = {
        let buttonView = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: true ))
        return buttonView
    }()
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        let containerView = UIView()
        view.addSubview(containerView)
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        view.addSubview(self.footerView)
                
        // StackView
        let stackView = UIStackView.create(withAxis: .vertical)
        containerView.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0.0,
                                                                  left: Constants.Style.DefaultHorizontalMargins,
                                                                  bottom: 0.0,
                                                                  right: Constants.Style.DefaultHorizontalMargins),
                                               excludingEdge: .bottom)
        stackView.autoAlignAxis(toSuperviewAxis: .vertical)
        stackView.addBlankSpace(space: 100.0)
        
        // Title
        stackView.addLabel(withText: StringsProvider.string(forKey: .spiroTaskDeviceDisconnectedTitle),
                           fontStyle: .title,
                           colorType: .primaryText,
                           textAlignment: .center)
        
        stackView.addBlankSpace(space: 24.0)
        
        // Body
        stackView.addLabel(withText: StringsProvider.string(forKey: .spiroTaskDeviceDisconnectedBody),
                           fontStyle: .paragraph,
                           colorType: .primaryText,
                           textAlignment: .center)
        
        containerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        containerView.autoPinEdge(.bottom, to: .top, of: footerView)
        
        // Footer pinned to bottom, left, right
        self.footerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        self.footerView.setButtonText(StringsProvider.string(forKey: .spiroNext))
        self.footerView.addTarget(target: self, action: #selector(self.nextButtonPressed))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: false).style)
    }
    
    // MARK: - Actions
    
    @objc private func nextButtonPressed() {
        self.onNextPressed?()
    }
    
    // MARK: - Private Methods
    
}
