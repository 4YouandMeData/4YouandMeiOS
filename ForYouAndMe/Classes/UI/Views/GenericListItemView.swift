//
//  GenericListItemView.swift
//  Alamofire
//
//  Created by Giuseppe Lapenta on 10/09/2020.
//

import UIKit

typealias GestureCallback = () -> Void

class GenericListItemView: UIView {
    
    private var gestureCallback: GestureCallback?
    
    init(withTitle title: String,
         templateImageName: TemplateImageName,
         colorType: ColorType,
         gestureCallback: @escaping GestureCallback) {
        
        super.init(frame: .zero)
        
        self.gestureCallback = gestureCallback
        self.backgroundColor = ColorPalette.color(withType: .secondary)
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fill
        self.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 10.0, left: 20.0, bottom: 10.0, right: 20.0))
        
        stackView.addImage(withImage: ImagePalette.templateImage(withName: templateImageName) ?? UIImage(),
                           color: ColorPalette.color(withType: colorType),
                           sizeDimension: 32)
        
        let attributedString = NSAttributedString.create(withText: title,
                                                         fontStyle: .paragraph,
                                                         colorType: .primaryText,
                                                         textAlignment: .left,
                                                         underlined: false)
        let label = UILabel()
        label.attributedText = attributedString
        label.numberOfLines = 0
        label.setContentHuggingPriority(UILayoutPriority(99), for: .horizontal)
        
        stackView.addArrangedSubview(label, horizontalInset: 16)
        
        stackView.addImage(withImage: ImagePalette.templateImage(withName: .arrowRight) ?? UIImage(),
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
                        self.backgroundColor = ColorPalette.color(withType: .primary)
                        self.backgroundColor = .white
        }, completion: nil)
        self.gestureCallback?()
    }
}
