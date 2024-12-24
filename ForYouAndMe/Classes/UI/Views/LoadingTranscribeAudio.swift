//
//  LoadingTranscribeAudio.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 23/12/24.
//

import UIKit

enum LoadingTranscribeAudioStyleCategory: StyleCategory {
    case loading
    case error
    
    var style: Style<LoadingTranscribeAudio> {
        switch self {
            
        case .loading:
            return Style<LoadingTranscribeAudio> { view in
                // Configure for "loading" style
                view.backgroundColor = ColorPalette.color(withType: .secondary)
                view.layer.borderWidth = 1.0
                view.layer.borderColor = ColorPalette.color(withType: .inactive).cgColor
                view.layer.cornerRadius = 6.0
               
                view.activityIndicator.isHidden = false
                view.activityIndicator.startAnimating()
                view.imageView.isHidden = true
               
                view.primaryLabel.attributedText = NSAttributedString.create(
                   withText: StringsProvider.string(forText: "Text format transcription in progress"),
                   fontStyle: .paragraph,
                   colorType: .primaryText
               )
                view.secondaryLabel.attributedText = NSAttributedString.create(
                   withText: StringsProvider.string(forText: "Soon you will see your recorded audio transcribed here"),
                   fontStyle: .header3,
                   colorType: .primaryText
               )
            }
        case .error:
                        
            return Style<LoadingTranscribeAudio> { view in
                // Configure for "error" style
                view.backgroundColor = ColorPalette.warningColor
                view.layer.borderWidth = 2.0
                view.layer.borderColor = ColorPalette.borderWarningColor.cgColor
                view.layer.cornerRadius = 8.0
                
                view.activityIndicator.isHidden = true
                view.activityIndicator.stopAnimating()
                view.imageView.isHidden = false
                view.imageView.image = ImagePalette.image(withName: .warningIcon)
                
                view.primaryLabel.attributedText = NSAttributedString.create(
                    withText: StringsProvider.string(forText: "Unable to transcribe audio, something went wrong during transcription"),
                    fontStyle: .paragraph,
                    colorType: .primaryText
                )
                view.secondaryLabel.attributedText = nil
            }
        }
    }
}

class LoadingTranscribeAudio: UIView {
    
    // MARK: - UI Components
    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 8
        return stackView
    }()

    fileprivate let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .gray
        return indicator
    }()

    fileprivate let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .orange
        imageView.autoSetDimensions(to: CGSize(width: 32, height: 32))
        imageView.isHidden = true // Hidden by default, shown only for "error" style
        return imageView
    }()

    fileprivate let primaryLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()

    fileprivate let secondaryLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    
    init(initWithStyle styleCategory: LoadingTranscribeAudioStyleCategory) {
        
        super.init(frame: .zero)
        self.backgroundColor = ColorPalette.color(withType: .secondary)
        self.setupUI()
        self.apply(style: styleCategory.style)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup UI
    private func setupUI() {
        self.addSubview(stackView)
        self.stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        
        self.stackView.addArrangedSubview(activityIndicator)
        self.stackView.addArrangedSubview(imageView)
        self.stackView.addArrangedSubview(primaryLabel)
        self.stackView.addArrangedSubview(secondaryLabel)
    }
}
