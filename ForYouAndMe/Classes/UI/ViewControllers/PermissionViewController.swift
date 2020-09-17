//
//  PermissionViewController.swift
//  ForYouAndMe
//
//  Created by Giuseppe Lapenta on 14/09/2020.
//

import PureLayout
import RxSwift

public class PermissionViewController: UIViewController {
    
    private var titleString: String
    private let navigator: AppNavigator
    private let disposeBag: DisposeBag = DisposeBag()
    
    private lazy var scrollStackView: ScrollStackView = {
        let scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: 0.0)
        return scrollStackView
    }()
    
    init(withTitle title: String) {
        self.titleString = title
        self.navigator = Services.shared.navigator
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        
        // Header View
        let headerView = InfoDetailHeaderView(withTitle: self.titleString )
        self.view.addSubview(headerView)
        headerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        headerView.backButton.addTarget(self, action: #selector(self.backButtonPressed), for: .touchUpInside)
        // ScrollStackView
        self.scrollStackView = ScrollStackView(axis: .vertical, horizontalInset: Constants.Style.DefaultHorizontalMargins)
        self.view.addSubview(scrollStackView)
        self.scrollStackView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        self.scrollStackView.autoPinEdge(.top, to: .bottom, of: headerView, withOffset: 30)
        self.scrollStackView.stackView.spacing = 30
        
        let permissionCamera: Permission = .camera
        let status: Bool = permissionCamera.isNotDetermined
        let locationItem = PermissionItemView(withTitle: "The BUMP app needs access to your phone’s location"/*StringsProvider.string(forKey: .studyInfoRewardsItem)*/,
            permission: permissionCamera,
            iconName: .locationIcon,
            gestureCallback: { [weak self] in
                guard let self = self else { return }
                permissionCamera.request().subscribe(onSuccess: { _ in
                    //TODO: Check is not first time authorization
                    if permissionCamera.isDenied, status == false {
                        self.showAlert(withTitle: "Permission denied", message: "Please, go to Settings and allow permission.",
                                       actions: [UIAlertAction(title: "Cancel", style: .cancel, handler: nil),
                                                 UIAlertAction(title: "Settings", style: .default, handler: { _ in
                                                    PermissionsOpener.openSettings()
                                                 })])
                    }
                }, onError: { error in
                    self.navigator.handleError(error: error, presenter: self)
                }).disposed(by: self.disposeBag)
        })
        self.scrollStackView.stackView.addArrangedSubview(locationItem)
        
        let permissionMicrophone: Permission = .microphone
        let pushItem = PermissionItemView(withTitle: "Microphone"/*StringsProvider.string(forKey: .studyInfoRewardsItem)*/,
            permission: permissionMicrophone,
            iconName: .pushNotificationIcon,
            gestureCallback: { [weak self] in
                if permissionMicrophone.isDenied {
                    print("is Denied")
                }
        })
        pushItem.autoSetDimension(.height, toSize: 72, relation: .greaterThanOrEqual)
        
        self.scrollStackView.stackView.addArrangedSubview(pushItem)
        self.scrollStackView.stackView.addBlankSpace(space: 40.0)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.navigationBar.apply(style: NavigationBarStyleCategory.primary(hidden: true).style)
    }
    
    // MARK: Actions
    @objc private func backButtonPressed() {
        self.navigationController?.popViewController(animated: true)
    }
}
