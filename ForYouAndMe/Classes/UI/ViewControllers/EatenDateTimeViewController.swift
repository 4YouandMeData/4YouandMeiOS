//
//  EatenDateTimeViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 15/05/25.
//

import UIKit
import PureLayout

protocol EatenDateTimeViewControllerDelegate: AnyObject {
    /// Called when user taps “Next” with both type and date selected
    func eatenDateTimeViewController(_ vc: EatenDateTimeViewController,
                                     didSelect type: EatenTypeViewController.EntryType,
                                     at date: Date)
    
    /// Called when user dismisses this screen (e.g. via back)
    func eatenDateTimeViewControllerDidCancel(_ vc: EatenDateTimeViewController)
}

class EatenDateTimeViewController: UIViewController {

    // MARK: – Public API
    
    /// Type passed from the previous screen
    var selectedType: EatenTypeViewController.EntryType!
    private let storage: CacheService
    private let navigator: AppNavigator
    private let variant: FlowVariant
    weak var delegate: EatenDateTimeViewControllerDelegate?

    // MARK: – Subviews

    private let scrollStackView = ScrollStackView(
        axis: .vertical,
        horizontalInset: Constants.Style.DefaultHorizontalMargins
    )

    private let subtitleLabel: UILabel = {
        let lbl = UILabel()
        lbl.numberOfLines = 0
        return lbl
    }()
    
    private let sectionHeader: UILabel = {
        let lbl = UILabel()
        lbl.font = FontPalette.fontStyleData(forStyle: .paragraph).font
        lbl.textColor = ColorPalette.color(withType: .primary)
        return lbl
    }()
    
    private let dateRow: UIControl = {
        let ctrl = UIControl()
        ctrl.backgroundColor = .clear
        ctrl.tintColor = ColorPalette.color(withType: .primary)
        return ctrl
    }()
    private let dateValueLabel: UILabel = {
        let lbl = UILabel()
        lbl.font = .preferredFont(forTextStyle: .body)
        lbl.textColor = ColorPalette.color(withType: .primaryText)
        return lbl
    }()
    private let dateIcon: UIImageView = {
        let img = ImagePalette.templateImage(withName: .clockIcon)
        let iv = UIImageView(image: img)
        iv.tintColor = ColorPalette.color(withType: .primary)
        return iv
    }()
    private let underline: UIView = {
        let view = UIView()
        view.backgroundColor = ColorPalette.color(withType: .primary)
        return view
    }()
    
    private let datePicker: UIDatePicker = {
        let dp = UIDatePicker()
        dp.datePickerMode = .dateAndTime
        dp.preferredDatePickerStyle = .inline
        dp.tintColor = ColorPalette.color(withType: .primary)
        dp.maximumDate = Date()
        return dp
    }()
    
    private lazy var footerView: GenericButtonView = {
        let buttonView = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: false))
        let buttonKey = (variant == .standalone)
        ? StringsProvider.string(forKey: .diaryNoteEatenNextButton)
        : StringsProvider.string(forKey: .noticedStepNextButton)
        buttonView.setButtonText(buttonKey)
        buttonView.setButtonEnabled(enabled: false)
        buttonView.addTarget(target: self, action: #selector(self.nextTapped))
        
        return buttonView
    }()

    // MARK: – State

    private var chosenDate: Date? {
        didSet {
            // Enable Next only when a date is chosen
            footerView.setButtonEnabled(enabled: chosenDate != nil)
            if let date = chosenDate {
                let fmt = DateFormatter()
                fmt.dateStyle = .short
                fmt.timeStyle = .short
                dateValueLabel.text = fmt.string(from: date)
            }
        }
    }
    
    private lazy var messages: [MessageInfo] = {
        let messages = self.storage.infoMessages?.messages(withLocation: .pageIHaveEeaten)
        return messages ?? []
    }()

    // MARK: – Lifecycle
    
    init(variant: FlowVariant) {
        self.navigator = Services.shared.navigator
        self.storage = Services.shared.storageServices
        self.variant = variant
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        print("DiaryNoteViewController - deinit")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ColorPalette.color(withType: .secondary)
        setupLayout()
        setupActions()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.secondary(hidden: false).style)
        self.addCustomBackButton()
    }

    // MARK: – Setup

    private func setupLayout() {
        
        // Create a bar button item with your info image
        let comingSoonItem = UIBarButtonItem(
            image: ImagePalette.templateImage(withName: .infoMessage),
            style: .plain,
            target: self,
            action: #selector(infoButtonPressed)
        )
        comingSoonItem.tintColor = ColorPalette.color(withType: .primary)
        self.navigationItem.rightBarButtonItem = (self.messages.count < 1)
            ? nil
            : comingSoonItem
        
        // Scroll + stack
        view.addSubview(scrollStackView)
        scrollStackView.autoPinEdgesToSuperviewSafeArea(with: .zero, excludingEdge: .bottom)
        
        // Transform input text to bold using attributed string
        
        let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
        
        let titleKey = (variant == .standalone)
        ? StringsProvider.string(forKey: .diaryNoteEatenStepThreeTitle)
        : StringsProvider.string(forKey: .noticedStepSevenTitle)
        let boldAttrsTitle: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: FontPalette.fontStyleData(forStyle: .header2).font.pointSize),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraphStyle
        ]
        let boldString = NSAttributedString(string: titleKey, attributes: boldAttrsTitle)
        
        // Subtitle: normal + bold
        let baseKey = (variant == .standalone)
        ? StringsProvider.string(forKey: .diaryNoteEatenStepThreeMessage)
        : StringsProvider.string(forKey: .noticedStepSevenMessage)
        
        let base = baseKey
        let boldPart = " " + selectedType.rawValue.lowercased()
        
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        
        let normalAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraph
        ]
        let boldAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize),
            .foregroundColor: ColorPalette.color(withType: .primaryText),
            .paragraphStyle: paragraph
        ]
        
        let att = NSMutableAttributedString(string: base, attributes: normalAttrs)
        att.append(NSAttributedString(string: boldPart, attributes: boldAttrs))
        subtitleLabel.attributedText = att
        
        scrollStackView.stackView.addLabel(attributedString: boldString, numberOfLines: 1)

        scrollStackView.stackView.addBlankSpace(space: 36)
        
        // Subtitle
        scrollStackView.stackView.addArrangedSubview(subtitleLabel)
        scrollStackView.stackView.addBlankSpace(space: 70)
        
        // Section header
        sectionHeader.text = (variant == .standalone)
        ? StringsProvider.string(forKey: .diaryNoteEatenStepThreeTime)
        : StringsProvider.string(forKey: .noticedStepSevenTime)
        
        scrollStackView.stackView.addArrangedSubview(sectionHeader)
        scrollStackView.stackView.addBlankSpace(space: 8)
        
        // Date row
        scrollStackView.stackView.addArrangedSubview(dateRow)
        dateRow.autoSetDimension(.height, toSize: 44)
        dateRow.addSubview(dateValueLabel)
        dateRow.addSubview(dateIcon)
        dateRow.addSubview(underline)
        
        dateValueLabel.autoAlignAxis(toSuperviewAxis: .horizontal)
        dateValueLabel.autoPinEdge(.leading, to: .leading, of: dateRow)
        
        dateIcon.autoAlignAxis(.horizontal, toSameAxisOf: dateValueLabel)
        dateIcon.autoPinEdge(.trailing, to: .trailing, of: dateRow)
        dateIcon.autoSetDimensions(to: CGSize(width: 15, height: 15))
        
        underline.autoPinEdge(.bottom, to: .bottom, of: dateRow)
        underline.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        underline.autoSetDimension(.height, toSize: 1)
        
        // Inline date picker (hidden initially)
        scrollStackView.stackView.addArrangedSubview(datePicker)
        datePicker.isHidden = true
        
        // Footer
        self.view.addSubview(self.footerView)
        footerView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero, excludingEdge: .top)
        scrollStackView.scrollView.autoPinEdge(.bottom, to: .top, of: footerView)
    }
    
    private func setupActions() {
        // Toggle picker on row tap
        dateRow.addTarget(self, action: #selector(rowTapped), for: .touchUpInside)
        // Capture date changes
        datePicker.addTarget(self, action: #selector(pickerChanged(_:)), for: .valueChanged)
    }

    // MARK: – Actions

    @objc private func rowTapped() {
        datePicker.isHidden.toggle()
    }

    @objc private func pickerChanged(_ dp: UIDatePicker) {
        chosenDate = dp.date
    }

    @objc private func nextTapped() {
        guard let date = chosenDate else { return }
        delegate?.eatenDateTimeViewController(self,
                                              didSelect: selectedType,
                                              at: date)
    }
    
    @objc private func infoButtonPressed() {
        self.navigator.openMessagePage(withLocation: .pageIHaveEeaten, presenter: self)
    }
}
