//
//  MessagePageViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 15/01/25.
//

class MessagePageViewController: UIViewController {
    
    let message: MessageInfo
    
    init(message: MessageInfo) {
        self.message = message
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        let containerView = UIView()
        
        let stackView = UIStackView.create(withAxis: .vertical, spacing: 16.0)
        stackView.alignment = .fill
        stackView.distribution = .fill
        
        // Title Label
        let titleLabel = UILabel()
        titleLabel.text = message.title ?? ""
        titleLabel.font = FontPalette.fontStyleData(forStyle: .title).font
        titleLabel.textColor = ColorPalette.color(withType: .primaryText)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 1
        titleLabel.setContentHuggingPriority(.required, for: .vertical)
        titleLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        stackView.addArrangedSubview(titleLabel)
        
        // Body Scrollable View
        let bodyScrollView = UIScrollView()
        bodyScrollView.showsVerticalScrollIndicator = true
        bodyScrollView.backgroundColor = .clear
        
        let bodyLabel = UILabel()
        bodyLabel.text = message.body ?? ""
        bodyLabel.font = FontPalette.fontStyleData(forStyle: .paragraph).font
        bodyLabel.textColor = ColorPalette.color(withType: .primaryText)
        bodyLabel.textAlignment = .left
        bodyLabel.numberOfLines = 0
        bodyLabel.setContentHuggingPriority(.defaultLow, for: .vertical)
        bodyLabel.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        
        bodyScrollView.addSubview(bodyLabel)
        bodyLabel.autoPinEdgesToSuperviewEdges()
        bodyLabel.autoMatch(.width, to: .width, of: bodyScrollView)
        stackView.addArrangedSubview(bodyScrollView)
        
        // Add Stack View to Container
        containerView.addSubview(stackView)
        
        // Add Container to View
        self.view.addSubview(containerView)
        
        // Constraints
        containerView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20))
        stackView.autoPinEdgesToSuperviewEdges()
        bodyScrollView.autoSetDimension(.height, toSize: 200, relation: .greaterThanOrEqual)
    }
}
