//
//  VideoDiaryPlayerView.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 27/08/2020.
//

import UIKit

protocol VideoDiaryPlayerViewDelegate: class {
    func mainButtonPressed()
    func discardButtonPressed()
}

class VideoDiaryPlayerView: UIView {
    
    private weak var delegate: VideoDiaryPlayerViewDelegate?
    
    // MARK: - Record
    
    private let instructionLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .left
        return label
    }()
    
    private lazy var timeLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .left
        return label
    }()
    
    private lazy var recordView: UIView = {
        let verticalStackView = UIStackView.create(withAxis: .vertical, spacing: 16.0)

        let horizontalStackView = UIStackView.create(withAxis: .horizontal, spacing: 16.0)

        let discardButtonContainerView = UIView()
        let discardButton = UIButton()
        discardButton.setImage(ImagePalette.image(withName: .closeCircleButton), for: .normal)
        discardButton.imageView?.contentMode = .scaleAspectFit
        discardButton.addTarget(self, action: #selector(self.discardButtonPressed), for: .touchUpInside)
        discardButton.contentEdgeInsets = UIEdgeInsets(top: 4.0, left: 4.0, bottom: 4.0, right: 4.0)
        discardButtonContainerView.addSubview(discardButton)
        discardButton.autoPinEdge(toSuperviewEdge: .leading)
        discardButton.autoPinEdge(toSuperviewEdge: .trailing)
        discardButton.autoPinEdge(toSuperviewEdge: .top, withInset: 0, relation: .greaterThanOrEqual)
        discardButton.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0, relation: .greaterThanOrEqual)
        discardButton.autoAlignAxis(toSuperviewAxis: .horizontal)

        horizontalStackView.addArrangedSubview(self.instructionLabel)
        self.instructionLabel.setContentHuggingPriority(UILayoutPriority(rawValue: 200), for: .horizontal)
        self.instructionLabel.setContentCompressionResistancePriority(UILayoutPriority(rawValue: 200), for: .horizontal)
        self.instructionLabel.adjustsFontSizeToFitWidth = true
        horizontalStackView.addArrangedSubview(discardButtonContainerView)

        verticalStackView.addArrangedSubview(horizontalStackView)
        
        let timerStackView = UIStackView.create(withAxis: .horizontal, spacing: 12.0)
        
        let imageView = UIImageView(image: ImagePalette.image(withName: .videoTime))
        imageView.contentMode = .scaleAspectFit
        imageView.autoSetDimensions(to: CGSize(width: 24.0, height: 24.0))
        timerStackView.addArrangedSubview(imageView)
        
        let timeLabelContainerView = UIView()
        timeLabelContainerView.addSubview(self.timeLabel)
        self.timeLabel.autoPinEdge(toSuperviewEdge: .leading)
        self.timeLabel.autoPinEdge(toSuperviewEdge: .trailing)
        self.timeLabel.autoPinEdge(toSuperviewEdge: .top, withInset: 0, relation: .greaterThanOrEqual)
        self.timeLabel.autoPinEdge(toSuperviewEdge: .bottom, withInset: 0, relation: .greaterThanOrEqual)
        self.timeLabel.autoAlignAxis(toSuperviewAxis: .horizontal)
        
        timerStackView.addArrangedSubview(timeLabelContainerView)
        verticalStackView.addArrangedSubview(timerStackView)
        
        return verticalStackView
    }()
    
    private let progressBarBackgroundView: UIView = {
        let view = UIView()
        view.autoSetDimension(.height, toSize: 4.0)
        view.backgroundColor = ColorPalette.color(withType: .inactive)
        view.round(radius: 2.0)
        view.clipsToBounds = true
        return view
    }()
    
    private lazy var progressBarFillView: UIView = {
        let view = UIView()
        view.backgroundColor = ColorPalette.color(withType: .active)
        self.progressBarBackgroundView.addSubview(view)
        view.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .trailing)
        return view
    }()
    
    private let infoView: UIView = {
        let verticalStackView = UIStackView.create(withAxis: .vertical, spacing: 16.0)
        verticalStackView.addLabel(withText: StringsProvider.string(forKey: .videoDiaryRecorderInfoTitle),
                                   fontStyle: .paragraph,
                                   colorType: .fourthText,
                                   textAlignment: .left)
        verticalStackView.addLabel(withText: StringsProvider.string(forKey: .videoDiaryRecorderInfoBody),
                                   fontStyle: .paragraph,
                                   colorType: .primaryText,
                                   textAlignment: .left)
        return verticalStackView
    }()
    
    private var fillProgressBarWidthConstraint: NSLayoutConstraint?
    
    // MARK: - Review
    
    private lazy var discardButtonView: UIView = {
        let view = UIView()
        let button = UIButton()
        button.setImage(ImagePalette.image(withName: .closeCircleButton), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.addTarget(self, action: #selector(self.discardButtonPressed), for: .touchUpInside)
        button.contentEdgeInsets = UIEdgeInsets(top: 4.0, left: 4.0, bottom: 4.0, right: 4.0)
        button.autoSetDimension(.height, toSize: 40.0)
        view.addSubview(button)
        button.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .leading)
        return view
    }()
    
    private lazy var singleTimeLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        return label
    }()
    
    // MARK: - Submit Successful
    
    private let recordingDateLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .left
        return label
    }()
    
    private lazy var recordedVideoFeedback: UIView = {
        let view = UIView()
        let horizontalStackView = UIStackView.create(withAxis: .horizontal, spacing: 10.0)
        view.addSubview(horizontalStackView)
        horizontalStackView.autoPinEdge(toSuperviewEdge: .top)
        horizontalStackView.autoPinEdge(toSuperviewEdge: .bottom)
        horizontalStackView.autoPinEdge(toSuperviewEdge: .leading, withInset: 0.0, relation: .greaterThanOrEqual)
        horizontalStackView.autoPinEdge(toSuperviewEdge: .trailing, withInset: 0.0, relation: .greaterThanOrEqual)
        horizontalStackView.autoAlignAxis(toSuperviewAxis: .vertical)
        
        let imageView = UIImageView(image: ImagePalette.image(withName: .videoRecordedFeedback))
        imageView.autoSetDimension(.width, toSize: 38.0)
        imageView.contentMode = .scaleAspectFit
        horizontalStackView.addArrangedSubview(imageView)
        
        let verticalStackView = UIStackView.create(withAxis: .vertical, spacing: 2.0)
        verticalStackView.addLabel(withText: StringsProvider.string(forKey: .videoDiaryRecorderSubmitFeedback),
                                   fontStyle: .header3,
                                   colorType: .fourthText,
                                   textAlignment: .left)
        verticalStackView.addArrangedSubview(UIView())
        verticalStackView.addArrangedSubview(self.recordingDateLabel)
        
        horizontalStackView.addArrangedSubview(verticalStackView)
        
        return view
    }()
    
    // MARK: - Main Button
    
    private lazy var buttonView: GenericButtonView = {
        let buttonView = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false),
                                           horizontalInset: 4.0,
                                           topInset: 0.0,
                                           bottomInset: 0.0)
        buttonView.addTarget(target: self, action: #selector(self.mainButtonPressed))
        return buttonView
    }()
    
    // MARK: - AttributedTextStyles
    
    private let instructionLabelAttributedTextStyle = AttributedTextStyle(fontStyle: .title,
                                                                          colorType: .primaryText,
                                                                          textAlignment: .left)
    private let currentTimeLabelAttributedTextStyle = AttributedTextStyle(fontStyle: .header3,
                                                                          colorType: .primaryText,
                                                                          textAlignment: .left)
    private let totalTimeLabelAttributedTextStyle = AttributedTextStyle(fontStyle: .header3,
                                                                        colorType: .fourthText,
                                                                        textAlignment: .left)
    private let singleTimeLabelAttributedTextStyle = AttributedTextStyle(fontStyle: .title,
                                                                         colorType: .primaryText)
    
    init(delegate: VideoDiaryPlayerViewDelegate) {
        self.delegate = delegate
        super.init(frame: .zero)
        
        self.backgroundColor = ColorPalette.color(withType: .secondary)
        
        let stackView = UIStackView.create(withAxis: .vertical, spacing: 16.0)
        self.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets(top: 30.0, left: 20.0, bottom: 20.0, right: 20.0))
        
        stackView.addArrangedSubview(self.discardButtonView)
        stackView.addArrangedSubview(self.recordView)
        stackView.addArrangedSubview(self.progressBarBackgroundView)
        stackView.addArrangedSubview(self.infoView)
        stackView.addArrangedSubview(self.singleTimeLabel)
        stackView.addArrangedSubview(self.recordedVideoFeedback)
        stackView.addArrangedSubview(self.buttonView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        self.roundCorners(corners: [.topLeft, .topRight], radius: 30.0)
    }
    
    // MARK: - Public Methods
    
    public func updateState(newState: VideoDiaryState, recordDurationTime: TimeInterval) {
        
        self.buttonView.setButtonEnabled(enabled: true)
        
        self.isHidden = false
        self.recordView.isHidden = true
        self.progressBarBackgroundView.isHidden = true
        self.infoView.isHidden = true
        self.discardButtonView.isHidden = true
        self.singleTimeLabel.isHidden = true
        self.recordedVideoFeedback.isHidden = true
        
        let totalTime = Constants.Misc.VideoDiaryMaxDurationSeconds
        
        switch newState {
        case .record(let isRecording):
            if isRecording {
                self.isHidden = true
            } else {
                self.buttonView.setButtonText(StringsProvider.string(forKey: .videoDiaryRecorderReviewButton))
                self.recordView.isHidden = false
                self.infoView.isHidden = false
                self.progressBarBackgroundView.isHidden = false
                self.updateProgressBar(newFillPercentage: CGFloat(recordDurationTime) / CGFloat(totalTime))
                self.timeLabel.setTime(currentTime: Int(recordDurationTime),
                                       totalTime: Int(totalTime),
                                       attributedTextStyle: self.totalTimeLabelAttributedTextStyle,
                                       currentTimeAttributedTextStyle: self.currentTimeLabelAttributedTextStyle)
                
                if recordDurationTime > 0.0 {
                    let instructionText = StringsProvider.string(forKey: .videoDiaryRecorderResumeRecordingDescription)
                    let attributedTextStyle = self.instructionLabelAttributedTextStyle
                    self.instructionLabel.attributedText = NSAttributedString.create(withText: instructionText,
                                                                                     attributedTextStyle: attributedTextStyle)
                } else {
                    self.buttonView.setButtonEnabled(enabled: false)
                    let instructionText = StringsProvider.string(forKey: .videoDiaryRecorderStartRecordingDescription)
                    let attributedTextStyle = self.instructionLabelAttributedTextStyle
                    self.instructionLabel.attributedText = NSAttributedString.create(withText: instructionText,
                                                                                     attributedTextStyle: attributedTextStyle)
                }
            }
        case .review(let isPlaying):
            if isPlaying {
                self.isHidden = true
            } else {
                self.buttonView.setButtonText(StringsProvider.string(forKey: .videoDiaryRecorderSubmitButton))
                self.discardButtonView.isHidden = false
                self.singleTimeLabel.isHidden = false
                self.singleTimeLabel.setTime(currentTime: Int(recordDurationTime),
                                             totalTime: Int(totalTime),
                                             attributedTextStyle: self.singleTimeLabelAttributedTextStyle)
            }
        case .submitted(let submitDate, let isPlaying):
            if isPlaying {
                self.isHidden = true
            } else {
                self.buttonView.setButtonText(StringsProvider.string(forKey: .videoDiaryRecorderCloseButton))
                self.singleTimeLabel.isHidden = false
                self.singleTimeLabel.setTime(currentTime: Int(recordDurationTime),
                                             totalTime: Int(totalTime),
                                             attributedTextStyle: self.singleTimeLabelAttributedTextStyle)
                self.recordedVideoFeedback.isHidden = false
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .short
                let recordingDateText = dateFormatter.string(from: submitDate)
                self.recordingDateLabel.attributedText = NSAttributedString.create(withText: recordingDateText,
                                                                                   fontStyle: .header3,
                                                                                   colorType: .primaryText)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func updateProgressBar(newFillPercentage: CGFloat) {
        self.fillProgressBarWidthConstraint?.autoRemove()
        self.fillProgressBarWidthConstraint = self.progressBarFillView.autoMatch(.width,
                                                                                 to: .width,
                                                                                 of: self.progressBarBackgroundView,
                                                                                 withMultiplier: newFillPercentage)
    }
    
    // MARK: - Actions
    
    @objc private func mainButtonPressed() {
        self.delegate?.mainButtonPressed()
    }
    
    @objc private func discardButtonPressed() {
        self.delegate?.discardButtonPressed()
    }
}
