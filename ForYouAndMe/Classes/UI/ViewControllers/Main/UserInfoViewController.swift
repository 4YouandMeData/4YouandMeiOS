//
//  UserInfoViewController.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 16/09/2020.
//

import UIKit
import RxSwift
import RxCocoa
import TPKeyboardAvoiding

class UserInfoViewController: UIViewController {
    
    fileprivate enum PageState { case read, edit }
    
    private let headerView = UserInfoHeaderView()
    
    private lazy var textFieldStackView: UIStackView = {
        let stackView = UIStackView.create(withAxis: .vertical)
        return stackView
    }()
    
    private var textFieldDataPickerMap: [UITextField: DataPickerHandler<UserInfoParameterItem>] = [:]
    private var textFieldDatePickerMap: [UITextField: DatePickerHandler] = [:]
    private var parameterTextFieldMap: [UserInfoParameter: UITextField] = [:]
    
    private lazy var scrollView: TPKeyboardAvoidingScrollView = {
        let scrollView = TPKeyboardAvoidingScrollView()
        scrollView.delegate = self
        return scrollView
    }()
    
    private let pageTitle: String
    private var userInfoParameters: [UserInfoParameter]
    
    private let pageState: BehaviorRelay<PageState> = BehaviorRelay<PageState>(value: .read)
    private let navigator: AppNavigator
    private let repository: Repository
    
    private let disposeBag = DisposeBag()
    
    init(withTitle title: String, userInfoParameters: [UserInfoParameter]) {
        self.navigator = Services.shared.navigator
        self.repository = Services.shared.repository
        self.pageTitle = title
        self.userInfoParameters = userInfoParameters
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        // ScrollView
        self.view.addSubview(self.scrollView)
        self.scrollView.autoPinEdgesToSuperviewSafeArea()
        
        // Main StackView
        let stackView = UIStackView.create(withAxis: .vertical)
        self.scrollView.addSubview(stackView)
        stackView.autoPinEdgesToSuperviewEdges()
        stackView.autoAlignAxis(toSuperviewAxis: .vertical)
        
        // Header View
        self.headerView.setTitle(self.pageTitle)
        stackView.addArrangedSubview(self.headerView)
        stackView.addArrangedSubview(self.textFieldStackView,
                                     horizontalInset: Constants.Style.DefaultHorizontalMargins)
        
        self.textFieldStackView.addBlankSpace(space: 16.0)
        self.userInfoParameters.forEach { parameter in
            self.textFieldStackView.addBlankSpace(space: 4.0)
            self.addTextFieldView(forUserInfoParameter: parameter)
        }
        
        self.pageState.subscribe(onNext: { [weak self] newPageState in
            self?.updateEditButton(pageState: newPageState)
            self?.updateTextFields(pageState: newPageState)
            self?.view.endEditing(true)
        }).disposed(by: self.disposeBag)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.headerView.refreshUI()
        
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: false).style)
        self.addCustomBackButton()
    }
    
    // MARK: - Private Methods
    
    private func addTextFieldView(forUserInfoParameter parameter: UserInfoParameter) {
        self.textFieldStackView.addLabel(withText: parameter.name,
                           fontStyle: .paragraph,
                           colorType: .fourthText,
                           textAlignment: .left)
        self.textFieldStackView.addBlankSpace(space: 8.0)
        let descriptionKeyText = Constants.UserInfo.getUserInfoParameterDescriptionFormat(userInfoParameterId: parameter.identifier)
        let descriptionText = StringsProvider.fullStringMap[descriptionKeyText].nilIfEmpty
        let textFieldView = GenericTextFieldView(keyboardType: .default, styleCategory: .primary)
        textFieldView.delegate = self
        
        switch parameter.type {
        case .string:
            textFieldView.text = parameter.currentStringValue ?? ""
        case .items:
            let dataPicker = DataPickerHandler<UserInfoParameterItem>(textField: textFieldView.textField,
                                                                      tintColor: ColorPalette.color(withType: .primary))
            let initialValue = parameter.items.first(where: { $0.identifier == parameter.currentItemIdentifier })
            dataPicker.updateData(with: parameter.items, initialValue: initialValue)
            self.textFieldDataPickerMap[textFieldView.textField] = dataPicker
        case .date:
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            let datePicker = DatePickerHandler(textField: textFieldView.textField,
                                               tintColor: ColorPalette.color(withType: .primary),
                                               dateFormatter: dateFormatter,
                                               datePickerMode: .date)
            datePicker.update(withMinDate: nil, maxDate: nil, initialDate: parameter.currentDate)
            self.textFieldDatePickerMap[textFieldView.textField] = datePicker
        }
        
        self.textFieldStackView.addArrangedSubview(textFieldView)
        
        if let descriptionText = descriptionText {
            self.textFieldStackView.addLabel(withText: descriptionText,
                                             fontStyle: .paragraph,
                                             colorType: .fourthText,
                                             textAlignment: .left)
            
        }
        
        self.parameterTextFieldMap[parameter] = textFieldView.textField
    }
    
    private func updateEditButton(pageState: PageState) {
        let button = UIButton()
        button.apply(style: ButtonTextStyleCategory.edit.style)
        switch pageState {
        case .edit:
            button.contentEdgeInsets = UIEdgeInsets(top: 2.0, left: 12.0, bottom: 2.0, right: 12.0)
            button.setTitle(StringsProvider.string(forKey: .userInfoButtonSubmit), for: .normal)
            button.addTarget(self, action: #selector(self.submitButtonPressed), for: .touchUpInside)
        case .read:
            button.setInsets(forContentPadding: UIEdgeInsets(top: 2.0, left: 12.0, bottom: 2.0, right: 16.0),
                             imageTitlePadding: 12.0)
            button.swapImageAndTitle()
            button.setTitle(StringsProvider.string(forKey: .userInfoButtonEdit), for: .normal)
            button.setImage(ImagePalette.templateImage(withName: .editSmall), for: .normal)
            button.imageView?.tintColor = ColorPalette.color(withType: .secondaryText)
            button.imageView?.contentMode = .scaleAspectFit
            button.addTarget(self, action: #selector(self.editButtonPressed), for: .touchUpInside)
        }
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(customView: button)
    }
    
    private func updateTextFields(pageState: PageState) {
        self.textFieldStackView.arrangedSubviews.forEach { view in
            if let textFieldView = view as? GenericTextFieldView {
                textFieldView.update(withPageState: self.canEditField(textField: textFieldView.textField)
                                     ? pageState
                                     : .read)
            }
        }
    }
    
    private func canEditField(textField: UITextField) -> Bool {
        // User Info Parameters belonging to the current phase cannot be edited. Design choice.
        let userInfoParameter = self.parameterTextFieldMap.keys
            .first(where: { self.parameterTextFieldMap[$0] == textField })
        
        if let phaseIndex = userInfoParameter?.phaseIndex,
           let currentPhaseIndex = self.repository.currentPhaseIndex,
           phaseIndex == currentPhaseIndex {
            return false
        }
        return true
    }
    
    private func submit(userInfoParameterRequests: [UserInfoParameterRequest]) {
        let currentPhaseIndex = self.repository.currentPhaseIndex
        
        self.repository.sendUserInfoParameters(userParameterRequests: userInfoParameterRequests)
            .addProgress()
            .subscribe(onSuccess: { [weak self] _ in
                guard let self = self else { return }
                self.pageState.accept(.read)
                self.headerView.refreshUI()
                if let newPhaseIndex = self.repository.currentPhaseIndex, newPhaseIndex != currentPhaseIndex {
                    self.navigator.showSwitchPhaseAlert(presenter: self)
                }
                }, onError: { [weak self] error in
                    guard let self = self else { return }
                    self.navigator.handleError(error: error, presenter: self)
            }).disposed(by: self.disposeBag)
    }
    
    // MARK: - Actions
    
    @objc private func editButtonPressed() {
        self.pageState.accept(.edit)
    }
    
    @objc private func submitButtonPressed() {
        
        let userInfoParameterRequests: [UserInfoParameterRequest] = self.parameterTextFieldMap.keys.compactMap { parameter in
            guard let textField = self.parameterTextFieldMap[parameter] else { return nil }
            var value: String?
            if let dataPicker = self.textFieldDataPickerMap[textField] {
                value = dataPicker.getSelectedData()?.identifier
            } else if let datePicker = self.textFieldDatePickerMap[textField] {
                if let selectedDate = datePicker.selectedDate {
                    value = DateStrategy.dateFormatter.string(from: selectedDate)
                }
            } else {
                value = textField.text
            }
            return UserInfoParameterRequest(parameter: parameter, value: value)
        }
        
        let isPermanentChange: Bool = userInfoParameterRequests.contains(where: { userInfoParameterRequest in
            if nil == self.userInfoParameters
                .first(where: { userInfoParameterRequest.parameter.identifier == $0.identifier })?.value.nilIfEmpty,
               nil != userInfoParameterRequest.value.nilIfEmpty,
               let phaseIndex = userInfoParameterRequest.parameter.phaseIndex,
               let currentPhaseIndex = self.repository.currentPhaseIndex,
               phaseIndex != currentPhaseIndex {
                return true
            } else {
                return false
            }
        })
        
        if isPermanentChange {
            let actions: [UIAlertAction] = [
                UIAlertAction(title: StringsProvider.string(forKey: .userInfoPermanentAlertConfirm),
                              style: .default,
                              handler: { [weak self] _ in self?.submit(userInfoParameterRequests: userInfoParameterRequests) }),
                UIAlertAction(title: StringsProvider.string(forKey: .userInfoPermanentAlertCancel),
                              style: .cancel,
                              handler: nil)
            ]
            self.showAlert(withTitle: StringsProvider.string(forKey: .userInfoPermanentAlertTitle),
                           message: StringsProvider.string(forKey: .userInfoPermanentAlertMessage),
                           actions: actions)
        } else {
            self.submit(userInfoParameterRequests: userInfoParameterRequests)
        }
    }
}

extension UserInfoViewController: UIScrollViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.view.endEditing(true)
    }
}

extension UserInfoViewController: GenericTextFieldViewDelegate {
    func genericTextFieldShouldReturn(textField: GenericTextFieldView) -> Bool {
        self.view.endEditing(true)
    }
    
    func genericTextFieldDidChange(textField: GenericTextFieldView) {}
}

private extension GenericTextFieldView {
    func update(withPageState pageState: UserInfoViewController.PageState) {
        switch pageState {
        case .edit:
            self.overrideValidIconShowLogic(isValid: false)
            self.textField.isEnabled = true
        case .read: self.overrideValidIconShowLogic(isValid: true)
            self.textField.isEnabled = false
        }
    }
}

extension UserInfoParameterItem: DataPickerItem {
    var displayText: String { self.value }
}
