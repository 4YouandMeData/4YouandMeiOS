//
//  DiaryNoteAudioViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 04/12/24.
//

import UIKit
import RxSwift
import TPKeyboardAvoiding

class DiaryNoteAudioViewController: UIViewController {
    
    enum AudioDiaryState {
        case record(isRecording: Bool)
        case listen(isPlaying: Bool)
        case submitted(submitDate: Date, isPlaying: Bool)
    }
    
    fileprivate enum PageState { case listen, create }
    
    private let navigator: AppNavigator
    private let repository: Repository
    private let analytics: AnalyticsService
    
    private let disposeBag = DisposeBag()
    private let totalTimeLabelAttributedTextStyle = AttributedTextStyle(fontStyle: .title,
                                                                        colorType: .primaryText,
                                                                        textAlignment: .center)
    
    private let currentTimeLabelAttributedTextStyle = AttributedTextStyle(fontStyle: .title,
                                                                          colorType: .primaryText,
                                                                          textAlignment: .center)
    
    private let totalTime = Constants.Misc.AudioDiaryMaxDurationSeconds
    private var recordDurationTime: TimeInterval = 0.0
    private let pageState: PageState
    
    private lazy var closeButton: UIButton = {
        let button = UIButton()
        button.setImage(ImagePalette.templateImage(withName: .backButtonNavigation), for: .normal)
        button.tintColor = ColorPalette.color(withType: .primaryText)
        button.autoSetDimension(.width, toSize: 32)
        button.imageView?.contentMode = .scaleAspectFit
        button.addTarget(self, action: #selector(self.closeButtonPressed), for: .touchUpInside)
        return button
    }()
    
    private lazy var headerView: UIView = {
        let containerView = UIView()
        
        let stackView = UIStackView.create(withAxis: .vertical, spacing: 8.0)
        
        // Close button
        let closeButtonContainerView = UIView()
        closeButtonContainerView.addSubview(self.closeButton)
        self.closeButton.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .trailing)
        stackView.addArrangedSubview(closeButtonContainerView)

        stackView.addLabel(withText: "Audio Recording",
                           fontStyle: .title,
                           colorType: .primaryText)
        
        stackView.addLineSeparator(lineColor: ColorPalette.color(withType: .secondaryMenu), space: 0, isVertical: false)
        
        containerView.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 25.0,
                                                                  left: Constants.Style.DefaultHorizontalMargins/2,
                                                                  bottom: 0,
                                                                  right: Constants.Style.DefaultHorizontalMargins/2))
        return containerView
    }()
    
    private lazy var textView: UITextView = {
        
        // Text View
        let textView = UITextView()
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 8
        textView.typingAttributes = [.foregroundColor: ColorPalette.color(withType: .primaryText),
                                     .font: FontPalette.fontStyleData(forStyle: .header3).font,
                                     .paragraphStyle: style]
        textView.delegate = self
        textView.layer.borderWidth = 1
        textView.tintColor = ColorPalette.color(withType: .primary)
        textView.layer.borderColor = ColorPalette.color(withType: .inactive).cgColor
        textView.layer.cornerRadius = 8
        textView.clipsToBounds = true
        
        // Toolbar
        let toolBar = UIToolbar()
        toolBar.barStyle = .default
        toolBar.isTranslucent = true
        toolBar.tintColor = ColorPalette.color(withType: .primary)
        toolBar.sizeToFit()
        
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(self.doneButtonPressed))
        let spaceButton = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolBar.setItems([spaceButton, doneButton], animated: false)
        textView.inputAccessoryView = toolBar
        
        return textView
    }()
    
    private lazy var placeholderLabel: UILabel = {
        let label = UILabel()
        label.text = "Insert your note here"
        label.font = FontPalette.fontStyleData(forStyle: .paragraph).font
        label.textColor = ColorPalette.color(withType: .inactive)
        label.sizeToFit()
        return label
    }()
    
    private var limitLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .right
        label.font = FontPalette.fontStyleData(forStyle: .header3).font
        label.textColor = ColorPalette.color(withType: .inactive)
        return label
    }()
    
    private lazy var slider: UISlider = {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 100
        return slider
    }()
    
    private lazy var footerView: GenericButtonView = {
        
        let buttonView = GenericButtonView(withTextStyleCategory: .transparentBackground(shadow: false ))
        buttonView.addTarget(target: self, action: #selector(self.saveButtonPressed))
        
        return buttonView
    }()
    
    private lazy var timeLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        return label
    }()
    
    private lazy var scrollView: UIScrollView = {
        let scrollView = TPKeyboardAvoidingScrollView()
        scrollView.keyboardDismissMode = .interactive
        return scrollView
    }()
    
    private var storage: CacheService
    private let dataPointID: String?
    private let maxCharacters: Int = 500
    
    init(withDataPointID dataPointID: String?) {
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        self.storage = Services.shared.storageServices
        self.analytics = Services.shared.analytics
        
        self.pageState = dataPointID == nil ? .create : .listen
        self.dataPointID = dataPointID
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("DiaryNoteTextViewController - deinit")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)

        self.view.addSubview(self.scrollView)
        
        // Header Stack View
        let stackView = UIStackView.create(withAxis: .vertical, spacing: 16.0)
        self.view.addSubview(stackView)
        stackView.autoPinEdges(toSuperviewMarginsExcludingEdge: .bottom)
        stackView.addArrangedSubview(self.headerView)
        
        self.refreshUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
    }
    
    // MARK: - Actions
    
    @objc private func closeButtonPressed() {
        self.customBackButtonPressed()
    }
    
    @objc private func doneButtonPressed() {
        self.textView.resignFirstResponder()
    }
    
    @objc private func saveButtonPressed() {}
    
    @objc private func recordButtonTapped() {
        
    }
    
    // MARK: - Private Methods
    
    private func refreshUI() {
        switch self.pageState {
        case .create:
            // StackView
            let containerStackView = UIStackView.create(withAxis: .vertical)
            self.scrollView.addSubview(containerStackView)
            containerStackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0.0,
                                                                      left: Constants.Style.DefaultHorizontalMargins,
                                                                      bottom: 0.0,
                                                                      right: Constants.Style.DefaultHorizontalMargins))
            containerStackView.autoAlignAxis(toSuperviewAxis: .vertical)
            containerStackView.addBlankSpace(space: 50.0)
            
            // Image
            containerStackView.addHeaderImage(image: ImagePalette.image(withName: .audioRecording), height: 80.0)
            containerStackView.addBlankSpace(space: 70)
            // Title
            let timeLabelContainerView = UIView()
            timeLabelContainerView.addSubview(self.timeLabel)
            self.timeLabel.autoPinEdgesToSuperviewEdges()
            self.timeLabel.autoAlignAxis(toSuperviewAxis: .vertical)
            self.timeLabel.autoAlignAxis(toSuperviewAxis: .horizontal)
            
            self.timeLabel.setTime(currentTime: Int(self.recordDurationTime),
                                   totalTime: Int(totalTime),
                                   attributedTextStyle: self.totalTimeLabelAttributedTextStyle,
                                   currentTimeAttributedTextStyle: self.currentTimeLabelAttributedTextStyle)
            containerStackView.addArrangedSubview(timeLabelContainerView)
            
            containerStackView.addBlankSpace(space: 120)
            
            let recordButton = UIButton()
            let recordButtonImage = ImagePalette.image(withName: .audioRecButton)
            recordButton.setImage(recordButtonImage, for: .normal)
            recordButton.imageView?.contentMode = .scaleAspectFit
            recordButton.addTarget(self, action: #selector (recordButtonTapped), for: .touchUpInside)
            recordButton.contentEdgeInsets = UIEdgeInsets(top: 4.0, left: 4.0, bottom: 4.0, right: 4.0)
            recordButton.autoSetDimension(.height, toSize: 68)
            
            containerStackView.addArrangedSubview(recordButton)
            
            // Footer
            self.view.addSubview(self.footerView)
            footerView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero, excludingEdge: .top)
            
            self.scrollView.autoPinEdge(.top, to: .bottom, of: self.headerView)
            self.scrollView.autoPinEdge(.leading, to: .leading, of: self.view)
            self.scrollView.autoPinEdge(.trailing, to: .trailing, of: self.view)
            self.scrollView.autoPinEdge(.bottom, to: .top, of: self.footerView)
            footerView.setButtonText("Save")
            
        case .listen:
            // StackView
            let containerStackView = UIStackView.create(withAxis: .vertical)
            self.scrollView.addSubview(containerStackView)
            containerStackView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0.0,
                                                                      left: Constants.Style.DefaultHorizontalMargins,
                                                                      bottom: 0.0,
                                                                      right: Constants.Style.DefaultHorizontalMargins))
            containerStackView.autoAlignAxis(toSuperviewAxis: .vertical)
            containerStackView.addBlankSpace(space: 24.0)
            let playButton = UIButton()
            let recordButtonImage = ImagePalette.image(withName: .audioPlayButton)
            playButton.setImage(recordButtonImage, for: .normal)
            playButton.imageView?.contentMode = .scaleAspectFit
            playButton.addTarget(self, action: #selector (recordButtonTapped), for: .touchUpInside)
            playButton.contentEdgeInsets = UIEdgeInsets(top: 4.0, left: 4.0, bottom: 4.0, right: 4.0)
            playButton.autoSetDimension(.height, toSize: 68)
            
            containerStackView.addArrangedSubview(playButton)
            
            containerStackView.addBlankSpace(space: 24.0)
            
            // Title
            let timeLabelContainerView = UIView()
            timeLabelContainerView.addSubview(self.timeLabel)
            self.timeLabel.autoPinEdgesToSuperviewEdges()
            self.timeLabel.autoAlignAxis(toSuperviewAxis: .vertical)
            self.timeLabel.autoAlignAxis(toSuperviewAxis: .horizontal)
            
            self.timeLabel.setTime(currentTime: Int(self.recordDurationTime),
                                   totalTime: Int(totalTime),
                                   attributedTextStyle: self.totalTimeLabelAttributedTextStyle,
                                   currentTimeAttributedTextStyle: self.currentTimeLabelAttributedTextStyle)
            containerStackView.addArrangedSubview(timeLabelContainerView)
            
            containerStackView.addBlankSpace(space: 60)
            
            containerStackView.addArrangedSubview(self.slider)
            self.slider.autoPinEdge(.leading, to: .leading, of: containerStackView, withOffset: 12.0)
            self.slider.autoPinEdge(.trailing, to: .trailing, of: containerStackView, withOffset: 12.0)
            
            containerStackView.addBlankSpace(space: 60)
            
            let containerTextView = UIView()
            containerTextView.addSubview(self.textView)
            
            self.textView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 0,
                                                                          left: 12.0,
                                                                          bottom: 0,
                                                                          right: 12.0))
            // Limit label
            containerTextView.addSubview(self.limitLabel)
            self.limitLabel.textColor = .lightGray
            self.limitLabel.autoPinEdge(.top, to: .bottom, of: self.textView)
            self.limitLabel.autoPinEdge(.right, to: .right, of: self.textView)
            self.limitLabel.autoPinEdge(.left, to: .left, of: self.textView)
            self.limitLabel.text = "\(self.textView.text.count) / \(self.maxCharacters)"
            containerStackView.addArrangedSubview(containerTextView)
  
            // Placeholder label
            self.textView.addSubview(self.placeholderLabel)
            self.placeholderLabel.isHidden = !textView.text.isEmpty
            self.placeholderLabel.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: CGFloat(self.textView.font!.pointSize/2),
                                                                                  left: 5,
                                                                                  bottom: 10,
                                                                                  right: 10))
            
            // Footer
            self.view.addSubview(self.footerView)
            footerView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero, excludingEdge: .top)
            
            self.scrollView.autoPinEdge(.top, to: .bottom, of: self.headerView)
            self.scrollView.autoPinEdge(.leading, to: .leading, of: self.view)
            self.scrollView.autoPinEdge(.trailing, to: .trailing, of: self.view)
            self.scrollView.autoPinEdge(.bottom, to: .top, of: self.footerView)
            footerView.setButtonText("Delete")
            
            containerTextView.autoPinEdge(.top, to: .bottom, of: self.slider, withOffset: 30)
            containerTextView.autoPinEdge(.leading, to: .leading, of: self.view)
            containerTextView.autoPinEdge(.trailing, to: .trailing, of: self.view)
            containerTextView.autoPinEdge(.bottom, to: .top, of: self.footerView, withOffset: -30)
        }
    }
}

extension DiaryNoteAudioViewController: UITextViewDelegate {
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        self.placeholderLabel.isHidden = !textView.text.isEmpty
    }
    
    func textViewDidChange(_ textView: UITextView) {
        self.placeholderLabel.isHidden = !textView.text.isEmpty
        self.limitLabel.text = "\(textView.text.count) / \(self.maxCharacters)"
        if textView.text.count <= self.maxCharacters {
            textView.layer.borderColor = ColorPalette.color(withType: .inactive).cgColor
            self.limitLabel.textColor = ColorPalette.color(withType: .inactive)
        } else {
            textView.layer.borderColor = UIColor.red.cgColor
            self.limitLabel.textColor = .red
        }
    }
}

extension DiaryNoteAudioViewController: UITextFieldDelegate {

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let newString = textField.getNewString(forRange: range, replacementString: string)
        return !(newString.count > self.maxCharacters)

    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.view.endEditing(true)
    }
}