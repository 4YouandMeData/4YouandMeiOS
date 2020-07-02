//
//  GenericCheckboxView.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 13/05/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit
import PureLayout
import RxSwift
import RxCocoa

enum GenericCheckboxStyleCategory: StyleCategory {
    case primary
    case secondary
    
    var style: Style<GenericCheckboxView> {
        switch self {
        case .primary: return Style<GenericCheckboxView> { checkboxView in
            checkboxView.checkboxFilledImage = ImagePalette.image(withName: .checkboxPrimaryFilled)
            checkboxView.checkboxOutlineImage = ImagePalette.image(withName: .checkboxPrimaryOutline)
            }
        case .secondary: return Style<GenericCheckboxView> { checkboxView in
            checkboxView.checkboxFilledImage = ImagePalette.image(withName: .checkboxSecondaryFilled)
            checkboxView.checkboxOutlineImage = ImagePalette.image(withName: .checkboxSecondaryOutline)
            }
        }
    }
}

class GenericCheckboxView: UIView {

    fileprivate var checkboxFilledImage: UIImage?
    fileprivate var checkboxOutlineImage: UIImage?
    
    public var isCheckedSubject: BehaviorRelay<Bool>
    
    private lazy var checkboxImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        imageView.autoSetDimensions(to: CGSize(width: 24.0, height: 24.0))
        return imageView
    }()
    
    private final let disposeBag = DisposeBag()
    
    init(isDefaultChecked: Bool, styleCategory: GenericCheckboxStyleCategory) {
        self.isCheckedSubject = BehaviorRelay(value: isDefaultChecked)
        super.init(frame: .zero)
        
        self.apply(style: styleCategory.style)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.onTap))
        self.addGestureRecognizer(tap)
        
        self.addSubview(self.checkboxImageView)
        self.checkboxImageView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0))
        
        self.isCheckedSubject.asObservable().subscribe(onNext: { checked in
            if checked {
                self.checkboxImageView.image = self.checkboxFilledImage
            } else {
                self.checkboxImageView.image = self.checkboxOutlineImage
            }
        }).disposed(by: self.disposeBag)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Actions
    
    @objc private func onTap() {
        self.isCheckedSubject.accept(!self.isCheckedSubject.value)
    }
}
