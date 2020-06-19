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

class GenericCheckboxView: UIView {

    public var isChecked: Bool {
        return self.isCheckedSubject.value
    }
    
    public var isCheckedSubject: BehaviorRelay<Bool>
    
    private lazy var checkboxImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        imageView.autoSetDimensions(to: CGSize(width: 24.0, height: 24.0))
        return imageView
    }()
    
    private final let disposeBag = DisposeBag()
    
    init(isDefaultChecked: Bool) {
        self.isCheckedSubject = BehaviorRelay(value: isDefaultChecked)
        super.init(frame: .zero)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(self.onTap))
        self.addGestureRecognizer(tap)
        
        self.addSubview(self.checkboxImageView)
        self.checkboxImageView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 8.0, left: 8.0, bottom: 8.0, right: 8.0))
        
        self.isCheckedSubject.asObservable().subscribe(onNext: { checked in
            if checked {
                self.checkboxImageView.image = ImagePalette.image(withName: .checkboxFilled)
            } else {
                self.checkboxImageView.image = ImagePalette.image(withName: .checkboxOutline)
            }
        }).disposed(by: self.disposeBag)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Actions
    
    @objc private func onTap() {
        self.isCheckedSubject.accept(!self.isChecked)
    }
}
