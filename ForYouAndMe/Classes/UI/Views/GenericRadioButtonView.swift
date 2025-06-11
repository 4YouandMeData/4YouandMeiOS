//
//  GenericRadioButtonView.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 10/06/25.
//

// GenericRadioButtonView.swift

import UIKit
import PureLayout
import RxSwift
import RxCocoa

enum GenericRadioStyleCategory: StyleCategory {
    case primary
    case secondary
    
    var style: Style<GenericRadioButtonView> {
        switch self {
        case .primary:
            return Style<GenericRadioButtonView> { view in
                view.filledColor = ColorPalette.color(withType: .primary)
                view.outlineColor = ColorPalette.color(withType: .inactive)
            }
        case .secondary:
            return Style<GenericRadioButtonView> { view in
                view.filledColor = ColorPalette.color(withType: .secondary)
                view.outlineColor = ColorPalette.color(withType: .secondary)
            }
        }
    }
}

class GenericRadioButtonView: UIView {

    fileprivate var filledColor: UIColor = .white
    fileprivate var outlineColor: UIColor = .white

    /// Emits the current checked state
    public var isSelectedSubject: BehaviorRelay<Bool>

    private lazy var imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.autoSetDimensions(to: CGSize(width: 24, height: 24))
        return iv
    }()

    private let disposeBag = DisposeBag()

    init(isDefaultSelected: Bool, styleCategory: GenericRadioStyleCategory) {
        self.isSelectedSubject = BehaviorRelay(value: isDefaultSelected)
        super.init(frame: .zero)

        self.apply(style: styleCategory.style)

        let tap = UITapGestureRecognizer(target: self, action: #selector(onTap))
        self.addGestureRecognizer(tap)

        addSubview(imageView)
        imageView.autoCenterInSuperview()

        // update image on state change
        isSelectedSubject
            .subscribe(onNext: { [weak self] selected in
                self?.updateImage(selected: selected)
            })
            .disposed(by: disposeBag)

        // initial state
        updateImage(selected: isDefaultSelected)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func updateImage(selected: Bool) {
        let name = selected ? TemplateImageName.radioButtonFilled : TemplateImageName.radioButtonOutline
        imageView.image = ImagePalette.templateImage(withName: name)
        imageView.tintColor = selected ? filledColor : outlineColor
    }

    @objc private func onTap() {
        isSelectedSubject.accept(true)
    }
}
