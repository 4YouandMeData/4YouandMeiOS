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
                view.backgroundColor = ColorPalette.color(withType: .secondary)
            }
        case .error:
                        
            return Style<LoadingTranscribeAudio> { view in
                view.backgroundColor = ColorPalette.color(withType: .primary)
            }
        }
    }
}

class LoadingTranscribeAudio: UIView {
    
    init(initWithStyle styleCategory: LoadingTranscribeAudioStyleCategory) {
        
        super.init(frame: .zero)
        self.backgroundColor = ColorPalette.color(withType: .secondary)
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        self.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges()
        
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.color = .gray
        stackView.addArrangedSubview(activityIndicator)
        activityIndicator.startAnimating()
        
        stackView.addBlankSpace(space: 12.0)
        
        stackView.addLabel(withText: StringsProvider.string(
            forText: "Text format transcription in progress"),
                           fontStyle: .paragraph,
                           colorType: .primaryText,
                           horizontalInset: 8.0)
        stackView.addBlankSpace(space: 10.0)
        stackView.addLabel(withText: StringsProvider.string(
            forText: "Soon you will see your recorded audio transcribed here"),
                           fontStyle: .header3,
                           colorType: .primaryText,
                           horizontalInset: 8.0)
        
        self.apply(style: styleCategory.style)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
