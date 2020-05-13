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

class GenericCheckboxView: UIView {

    public var isChecked: Bool {
        return (try? self.isCheckedSubject.value()) ?? false
    }
    
    private lazy var checkboxImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        imageView.autoSetDimensions(to: CGSize(width: 24.0, height: 24.0))
        return imageView
    }()
    
    private var isCheckedSubject: BehaviorSubject<Bool>
    
    private final let disposeBag = DisposeBag()
    
    init(isDefaultChecked: Bool) {
        self.isCheckedSubject = BehaviorSubject(value: isDefaultChecked)
        super.init(frame: .zero)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(onTap))
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
        self.isCheckedSubject.onNext(!self.isChecked)
    }
}
