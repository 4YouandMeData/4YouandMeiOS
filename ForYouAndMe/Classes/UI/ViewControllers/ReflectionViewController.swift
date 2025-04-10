//
//  ReflectionViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 08/04/25.
//

class ReflectionViewController: UIViewController {
    
    var onWritePressed: (() -> Void)?
    var onAudioPressed: (() -> Void)?
    var onVideoPressed: (() -> Void)?
    var onLearnMorePressed: ((String, String) -> Void)?
    
    private let headerImage: URL?

    private lazy var footerView: UIStackView = {
        let buttonsView = UIStackView.create(withAxis: .vertical)
        buttonsView.backgroundColor = .red
        return buttonsView
    }()
    
    init(headerImage: URL?) {
        self.headerImage = headerImage
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        let containerView = UIView()
        self.view.addSubview(containerView)
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        self.view.addSubview(self.footerView)
                
        // StackView
        let stackView = UIStackView.create(withAxis: .vertical)
        containerView.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0.0,
                                                                  left: Constants.Style.DefaultHorizontalMargins,
                                                                  bottom: 0.0,
                                                                  right: Constants.Style.DefaultHorizontalMargins),
                                               excludingEdge: .bottom)
        stackView.autoAlignAxis(toSuperviewAxis: .vertical)
        stackView.addBlankSpace(space: 42.0)
        
        // Image
        stackView.addImageAsync(withURL: self.headerImage, sizeDimension: 76.0)
        stackView.addBlankSpace(space: 24.0)
        
        // Title
        stackView.addLabel(withText: StringsProvider.string(forKey: .reflectionTaskTitle),
                           fontStyle: .title,
                           colorType: .primaryText,
                           textAlignment: .center)
        
        stackView.addBlankSpace(space: 24.0)
        
        // Body
        let bodyText = StringsProvider.string(forKey: .reflectionTaskBody)
        stackView.addLabel(withText: bodyText,
                           fontStyle: .paragraph,
                           colorType: .primaryText,
                           textAlignment: .center,
                           numberOfLines: 8)
        
        if bodyText.count > 200 {
            stackView.addExternalLinkButton(self,
                                            action: #selector(self.learnMoreDidPressed),
                                            text: StringsProvider.string(forKey: .reflectionTaskLearnMore),
                                            exludingEdge: .leading)
        }
        
        containerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        containerView.autoPinEdge(.bottom, to: .top, of: self.footerView)
        
        // Footer pinned to bottom, left, right
        var title = StringsProvider.string(forKey: .reflectionTextTask)
        var image = ImagePalette.image(withName: .textNote)

        let writePage = GenericListItemView(withTitle: title,
                                            image: image ?? UIImage(),
                                            colorType: .primary,
                                            style: .shadowStyle,
                                            gestureCallback: { [weak self] in
            guard let self = self else { return }
            self.onWritePressed?()
        })
        self.footerView.addArrangedSubview(writePage)
        
        title = StringsProvider.string(forKey: .reflectionAudioTask)
        image = ImagePalette.image(withName: .audioNote)
        let audioPage = GenericListItemView(withTitle: title,
                                            image: image ?? UIImage() ,
                                            colorType: .primary,
                                            style: .shadowStyle,
                                            gestureCallback: { [weak self] in
            guard let self = self else { return }
            self.onAudioPressed?()
        })
        self.footerView.addArrangedSubview(audioPage)
    
        title = StringsProvider.string(forKey: .reflectionVideoTask)
        image = ImagePalette.templateImage(withName: .videoIcon) ?? UIImage()
        let videoPage = GenericListItemView(withTitle: title,
                                            image: image ?? UIImage(),
                                            colorType: .primary,
                                            style: .shadowStyle,
                                            gestureCallback: { [weak self] in
            guard let self = self else { return }
            self.onVideoPressed?()
        })
        self.footerView.addArrangedSubview(videoPage)
        self.footerView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0.0,
                                                                        left: 0.0,
                                                                        bottom: 56,
                                                                        right: 0.0),
                                                     excludingEdge: .top)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: false).style)
    }
    
    // MARK: - Actions
    
    @objc private func learnMoreDidPressed() {
        self.onLearnMorePressed?(StringsProvider.string(forKey: .reflectionTaskTitle),
                                 StringsProvider.string(forKey: .reflectionTaskBody))
    }
}


