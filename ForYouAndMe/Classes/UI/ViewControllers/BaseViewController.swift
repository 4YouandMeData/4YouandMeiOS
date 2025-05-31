//
//  BaseViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 31/05/25.
//

import UIKit
import RxSwift
import JJFloatingActionButton
import PureLayout

/// A UIViewController subclass that sets up a floating action button (FAB)
/// with the three “dose / noticed / eaten” items in a single place.
/// All subclasses automatically inherit the same FAB behavior.
class BaseViewController: UIViewController {
    
    // MARK: – Common Dependencies
    
    /// Use the shared services everywhere
    let navigator: AppNavigator
    let repository: Repository
    let analytics: AnalyticsService
    let deeplinkService: DeeplinkService
    var cacheService: CacheService
    
    let disposeBag = DisposeBag()
    
    // MARK: – Floating Action Button
    
    /// Single JJFloatingActionButton instance, configurato una volta
    lazy var floatingButton: JJFloatingActionButton = {
        let button = JJFloatingActionButton()
        // Automatically close the menu when an item is tapped:
        button.closeAutomatically = true
        return button
    }()
    
    // MARK: – Inizializzazione
    
    init() {
        self.navigator       = Services.shared.navigator
        self.repository      = Services.shared.repository
        self.analytics       = Services.shared.analytics
        self.deeplinkService = Services.shared.deeplinkService
        self.cacheService    = Services.shared.storageServices
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        print("\(type(of: self)) deinit")
    }
    
    // MARK: – Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = ColorPalette.color(withType: .secondary)
        setupFloatingButton()
    }
    
    override func viewDidLayoutSubviews() {
         super.viewDidLayoutSubviews()
         // Ensure FAB is always on top of any other subview
         view.bringSubviewToFront(floatingButton)
     }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Force-close the FAB menu when this controller disappears (e.g. on tab switch)
        floatingButton.close(animated: false)
    }
    
    // MARK: – Private Methods
    
    /// Crea, aggiunge alla view e fa layout del FAB, quindi popola gli item “di default”
    private func setupFloatingButton() {
        
        view.addSubview(floatingButton)
        
        floatingButton.autoPinEdge(toSuperviewSafeArea: .bottom, withInset: 16)
        floatingButton.autoPinEdge(toSuperviewSafeArea: .trailing, withInset: 16)
        
        addDefaultFabItems()
        
        floatingButton.buttonColor      = ColorPalette.color(withType: .fabColorDefault)
        floatingButton.buttonImageColor = .black
        
        floatingButton.layoutIfNeeded()
        let borderView = CircleBorderView(
            frame: floatingButton.circleView.frame,
            color: ColorPalette.color(withType: .fabOutlineColor),
            borderWidth: 1.0
        )
        floatingButton.addSubview(borderView)
    }
    
    func setFabHidden(_ hidden: Bool) {
        floatingButton.isHidden = hidden
    }
    
    private func addDefaultFabItems() {
        // ‣ First item: “Doses”
        let actionInsulin = floatingButton.addItem()
        actionInsulin.titleLabel.text      = StringsProvider.string(forKey: .diaryNoteFabDoses)
        actionInsulin.titleLabel.textColor = ColorPalette.color(withType: .fabTextColor)
        actionInsulin.imageView.image      = ImagePalette.templateImage(withName: .siringeIcon)
        actionInsulin.imageView.tintColor  = ColorPalette.color(withType: .primaryText)
        actionInsulin.buttonColor          = ColorPalette.color(withType: .secondary)
        actionInsulin.action = { [weak self] _ in
            // Navigate to MyDoses from whichever subclass stia mostrando il FAB
            guard let self = self else { return }
            self.navigator.openMyDosesViewController(presenter: self)
            // (closeAutomatically = true già fa la chiusura, ma volendo si potrebbe forzare)
            // self.floatingButton.close(animated: true, completion: nil)
        }
        
        // ‣ Second item: “Noticed”
        let actionNoticed = floatingButton.addItem()
        actionNoticed.titleLabel.text      = StringsProvider.string(forKey: .diaryNoteFabNoticed)
        actionNoticed.titleLabel.textColor = ColorPalette.color(withType: .fabTextColor)
        actionNoticed.imageView.image      = ImagePalette.image(withName: .noteGeneric)
        actionNoticed.imageView.tintColor  = ColorPalette.color(withType: .primaryText)
        actionNoticed.buttonColor          = ColorPalette.color(withType: .secondary)
        actionNoticed.action = { [weak self] _ in
            guard let self = self else { return }
            self.navigator.openNoticedViewController(presenter: self)
        }
        
        // ‣ Third item: “Eaten”
        let actionEaten = floatingButton.addItem()
        actionEaten.titleLabel.text      = StringsProvider.string(forKey: .diaryNoteFabEaten)
        actionEaten.titleLabel.textColor = ColorPalette.color(withType: .fabTextColor)
        actionEaten.imageView.image      = ImagePalette.templateImage(withName: .eatenIcon)
        actionEaten.imageView.tintColor  = ColorPalette.color(withType: .primaryText)
        actionEaten.buttonColor          = ColorPalette.color(withType: .secondary)
        actionEaten.action = { [weak self] _ in
            guard let self = self else { return }
            self.navigator.openEatenViewController(presenter: self)
        }
    }
}
