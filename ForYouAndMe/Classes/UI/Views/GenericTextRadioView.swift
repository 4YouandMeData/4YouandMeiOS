//
//  GenericTextRadioView.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 10/06/25.
//

import UIKit
import PureLayout
import RxRelay
import RxSwift

class GenericTextRadioView: UIView {
    
    public var isSelectedSubject: BehaviorRelay<Bool> { radioButton.isSelectedSubject }
    
    private let radioButton: GenericRadioButtonView
    private let label = UILabel()
    
    init(isDefaultSelected: Bool,
         radioStyle: GenericRadioStyleCategory,
         fontStyle: FontStyle,
         colorType: ColorType,
         textFirst: Bool,
         text: String) {
        
        
        self.radioButton = GenericRadioButtonView(isDefaultSelected: isDefaultSelected,
                                                  styleCategory: radioStyle)
        super.init(frame: .zero)
        
        
        let styleData = FontPalette.fontStyleData(forStyle: fontStyle)
        let paragraph = NSMutableParagraphStyle(); paragraph.alignment = .left
        paragraph.lineSpacing = styleData.lineSpacing
        let attributes: [NSAttributedString.Key: Any] = [
            .font: styleData.font,
            .foregroundColor: ColorPalette.color(withType: colorType),
            .paragraphStyle: paragraph
        ]
        let finalText = styleData.uppercase ? text.uppercased() : text
        label.numberOfLines = 0
        label.attributedText = NSAttributedString(string: finalText, attributes: attributes)
        
        let radioContainer = UIView()
        radioContainer.addSubview(radioButton)
        
        radioButton.autoSetDimensions(to: CGSize(width: 24, height: 24))
        radioButton.autoCenterInSuperview()
        radioContainer.autoSetDimension(.width, toSize: 24)
        radioContainer.autoSetDimension(.height, toSize: 24)
        
        // 4. Create horizontal stack
        let arranged: [UIView] = textFirst
        ? [label, radioContainer]
        : [radioContainer, label]
        let stack = UIStackView(arrangedSubviews: arranged)
        stack.axis = .horizontal
        stack.spacing = 12
        stack.alignment = .center
        stack.distribution = .fill
        addSubview(stack)
        stack.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0))
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
