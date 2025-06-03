//
//  MedicalAlertViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 03/06/25.
//

/// A simple modal view that shows a “Warning” icon, a title and a body text,
/// and a button “Ok”.
class SpirometryWarningViewController: UIViewController {
    
    // MARK: - UI Subviews
    
    /// Close button in the top-left corner
    private lazy var closeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(
            ImagePalette.templateImage(withName: .closeButton),
            for: .normal
        )
        button.tintColor = ColorPalette.color(withType: .primaryText)
        button.autoSetDimension(.width, toSize: 32)
        button.autoSetDimension(.height, toSize: 32)
        button.addTarget(
            self,
            action: #selector(closeButtonPressed),
            for: .touchUpInside
        )
        return button
    }()
    
    /// A thin separator line below the close button
    private lazy var separatorLine: UIView = {
        let view = UIView()
        view.backgroundColor = ColorPalette.color(withType: .secondaryMenu)
        return view
    }()
    
    /// The warning icon in the center
    private lazy var warningIconView: UIImageView = {
        let imageView = UIImageView()
        // Usare un’icona di warning a tua scelta, ad esempio un triangolo con un punto esclamativo
        imageView.image = ImagePalette.templateImage(withName: .medicalAlert)
        imageView.tintColor = ColorPalette.color(withType: .primary)
        imageView.contentMode = .scaleAspectFit
        imageView.autoSetDimensions(to: CGSize(width: 48, height: 48))
        return imageView
    }()
    
    /// Title label (“Warning”)
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = StringsProvider.string(forKey: .spiroTitleMedicalAlertTitle)
        label.font = FontPalette.fontStyleData(forStyle: .title).font
        label.textColor = ColorPalette.color(withType: .primaryText)
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()
    
    /// Body label (multi-line explanatory text)
    private lazy var bodyLabel: UILabel = {
        let label = UILabel()
        label.text = StringsProvider.string(forKey: .spiroTitleMedicalAlertMessage)
        label.font = FontPalette.fontStyleData(forStyle: .paragraph).font
        label.textColor = ColorPalette.color(withType: .primaryText)
        label.textAlignment = .left
        label.numberOfLines = 0
        return label
    }()
    
    private lazy var okButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(
            StringsProvider.string(forKey: .spiroTitleMedicalAlertButtonText),
            for: .normal
        )
        button.titleLabel?.font = FontPalette.fontStyleData(forStyle: .paragraph).font
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = ColorPalette.color(withType: .primary)
        button.layer.cornerRadius = 24
        button.clipsToBounds = true
        button.addTarget(
            self,
            action: #selector(okButtonPressed),
            for: .touchUpInside
        )
        return button
    }()
    
    private lazy var scrollView: UIScrollView = {
        let scroll = UIScrollView()
        scroll.alwaysBounceVertical = true
        scroll.showsVerticalScrollIndicator = false
        return scroll
    }()
    
    private lazy var contentContainer: UIStackView = {
        let stack = UIStackView.create(withAxis: .vertical, spacing: 16)
        return stack
    }()
    
    // MARK: - Initialization
    
    init() {
        super.init(nibName: nil, bundle: nil)
        
        if #available(iOS 13.0, *) {
            self.modalPresentationStyle = .pageSheet
            self.isModalInPresentation = true
        } else {
            self.modalPresentationStyle = .fullScreen
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureViewHierarchy()
        configureLayoutConstraints()
        configureStyling()
    }
    
    // MARK: - Setup
    
    private func configureViewHierarchy() {
        view.backgroundColor = .white
        
        view.addSubview(closeButton)
        view.addSubview(separatorLine)
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentContainer)
        
        contentContainer.addArrangedSubview(warningIconView)
        contentContainer.addArrangedSubview(titleLabel)
        contentContainer.addArrangedSubview(bodyLabel)
        
        view.addSubview(okButton)
    }
    
    private func configureLayoutConstraints() {

        closeButton.autoPinEdge(toSuperviewSafeArea: .top, withInset: 12)
        closeButton.autoPinEdge(toSuperviewEdge: .leading, withInset: 12)
        
        separatorLine.autoPinEdge(.top, to: .bottom, of: closeButton, withOffset: 12)
        separatorLine.autoPinEdge(toSuperviewEdge: .leading, withInset: 0)
        separatorLine.autoPinEdge(toSuperviewEdge: .trailing, withInset: 0)
        separatorLine.autoSetDimension(.height, toSize: 1 / UIScreen.main.scale)
        
        okButton.autoPinEdge(toSuperviewSafeArea: .bottom, withInset: 16)
        okButton.autoPinEdge(toSuperviewEdge: .leading, withInset: 16)
        okButton.autoPinEdge(toSuperviewEdge: .trailing, withInset: 16)
        okButton.autoSetDimension(.height, toSize: 48)
        
        scrollView.autoPinEdge(.top, to: .bottom, of: separatorLine, withOffset: 24)
        scrollView.autoPinEdge(toSuperviewEdge: .leading, withInset: Constants.Style.DefaultHorizontalMargins)
        scrollView.autoPinEdge(toSuperviewEdge: .trailing, withInset: Constants.Style.DefaultHorizontalMargins)
        scrollView.autoPinEdge(.bottom, to: .top, of: okButton, withOffset: -24)
        
        contentContainer.autoPinEdgesToSuperviewEdges()
        contentContainer.autoMatch(
            .width,
            to: .width,
            of: scrollView
        )
    }
    
    private func configureStyling() {
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
    }
    
    // MARK: - Actions
    
    @objc private func closeButtonPressed() {
        // Chiudo il modal
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc private func okButtonPressed() {
        // Comportamento identico a chiudere
        self.dismiss(animated: true, completion: nil)
    }
}
