//
//  GenericListItemView.swift
//  Alamofire
//
//  Created by Giuseppe Lapenta on 10/09/2020.
//

import UIKit

class GenericListItemView: UIView {
    
    init(withTopOffset topOffset: CGFloat,
         title: String,
         templateImageName: TemplateImageName,
         colorType: ColorType) {
        super.init(frame: .zero)
        
        self.backgroundColor = ColorPalette.color(withType: .secondary)
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fill
        self.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: topOffset, left: 20.0, bottom: 0.0, right: 20.0))
        
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
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
