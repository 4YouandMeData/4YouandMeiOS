//
//  DeviceItemView.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 11/09/2020.
//

typealias DeviceItemViewCallback = () -> Void

class DeviceItemView: UIView {
    
    private var gestureCallback: DeviceItemViewCallback?
    
    init(withTitle title: String,
         imageName: ImageName,
         gestureCallback: @escaping DeviceItemViewCallback) {
        
        super.init(frame: .zero)
        
        self.gestureCallback = gestureCallback
        self.backgroundColor = ColorPalette.color(withType: .primary)
        self.layer.cornerRadius = 8
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fill
        self.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0, left: 16.0, bottom: 0, right: 20.0))
        
        stackView.addImage(withImage: ImagePalette.image(withName: imageName) ?? UIImage(),
                           color: ColorPalette.color(withType: .secondary),
                           sizeDimension: 32)
        
        stackView.addLineSeparator(lineColor: ColorPalette.color(withType: .secondary),
                                   inset: 0,
                                   isVertical: true)
        
        var attributedString = NSAttributedString.create(withText: title,
                                                         fontStyle: .paragraph,
                                                         colorType: .secondaryText,
                                                         textAlignment: .left,
                                                         underlined: false)
        let label = UILabel()
        label.attributedText = attributedString
        label.numberOfLines = 0
        label.setContentHuggingPriority(UILayoutPriority(100), for: .horizontal)
        
        stackView.addArrangedSubview(label, horizontalInset: 16)
        
        attributedString = NSAttributedString.create(withText: "Connect",
                                                     fontStyle: .paragraph,
                                                     colorType: .secondaryText,
                                                     textAlignment: .left,
                                                     underlined: false)
        
        let connectLabel = UILabel()
        connectLabel.attributedText = attributedString
        connectLabel.numberOfLines = 0
        connectLabel.setContentHuggingPriority(UILayoutPriority(101), for: .horizontal)
        
        stackView.addArrangedSubview(connectLabel, horizontalInset: 16)
        
        stackView.addImage(withImage: ImagePalette.image(withName: .nextButtonSecondary) ?? UIImage(),
                           color: ColorPalette.color(withType: .primaryText),
                           sizeDimension: 32)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(viewDidPressed))
        self.addGestureRecognizer(tap)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc private func viewDidPressed() {
        UIView.animate(withDuration: 0.1, delay: 0.0,
                       options: [.curveLinear],
                       animations: {
                        self.backgroundColor = .white
                        self.backgroundColor = ColorPalette.color(withType: .primary)
        }, completion: nil)
        self.gestureCallback?()
    }
}
