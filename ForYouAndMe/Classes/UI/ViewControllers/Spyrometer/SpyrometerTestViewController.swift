//
//  SpyrometerViewController.swift
//  Pods
//
//  Created by Giuseppe Lapenta on 17/03/25.
//

import UIKit
import PureLayout
import MirSmartDevice

/// This view controller is responsible for scanning and connecting to MIR spirometer devices.
/// Navigation to the next step is triggered only by tapping the footer "Continue" button.
/// Before starting the scan, it checks if Bluetooth is active.
class SpyrometerTestViewController: UIViewController {
    
    // MARK: - Properties
    
    // MARK: - Device & Patient
    var soDevice: SODevice?
    var soPatient: SOPatient?
    
    /// The spirometry service used to discover and connect to devices.
    var service: MirSpirometryService
    
    // MARK: - Callbacks
//    /// Called when the scanning is completed and the user taps "Continue".
//    var onTestCompleted: (() -> Void)?
//
//    /// Called when the user cancels the scanning operation.
//    var onCancelled: (() -> Void)?

    // MARK: - UI Elements
    
    /// A label to display the current "Target: X% | Actual: Y%".
    private let valuesLabel = UILabel()
    
    /// A container for our bars.
    private let barsContainerView = UIView()
    
    /// The "actual" bar that grows in height according to the Actual %.
    private let actualBar = UIView()
    
    /// The "target" bar that grows in height according to the Target %.
    private let targetBar = UIView()
    
    /// The constraints for the bars' heights, so we can animate them easily.
    private var actualBarHeightConstraint: NSLayoutConstraint!
    private var targetBarHeightConstraint: NSLayoutConstraint!
    
    /// The maximum height (in points) for the bars when they reach 100%.
    private let maxBarHeight: CGFloat = 200.0
    
    /// Flag to know if the test is running or not.
    private var isPEFTestRunning = false
    
    /// Button to trigger connection (demo).
    private lazy var footerView: GenericButtonView = {
        let buttonView = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: true ))
        return buttonView
    }()
    
    // MARK: - Initialization
    
    /// Initializes the view controller with the given spirometry service.
    init() {
        self.service = Services.shared.mirSpirometryService
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - View Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = ColorPalette.color(withType: .secondary)

        setupUI()
        setupActions()
        setupManagerCallbacks()
    }

    // MARK: - UI Setup using PureLayout
    
    /// Configures and adds UI elements to the view using PureLayout.
    private func setupUI() {
        // 1) Create a container view that will hold the stackView (which contains label & bars),
        //    and pin this container above the footer.
        let containerView = UIView()
        view.addSubview(containerView)

        // 2) Create a vertical stackView and set alignment = .center for a nice centered layout
        let stackView = UIStackView.create(withAxis: .vertical, spacing: 16.0)
        stackView.alignment = .center
        
        containerView.addSubview(stackView)

        // 3) Create the footer (button) at the bottom edge
        view.addSubview(self.footerView)
        
        // Footer pinned to bottom, left, right
        self.footerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        // Set the initial button text
        self.footerView.setButtonText(StringsProvider.string(forKey: .spiroNext))
        
        // 4) Pin containerView to fill the area above the footer
        containerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        containerView.autoPinEdge(.bottom, to: .top, of: footerView)
        
        // 5) Pin the stackView to the edges of containerView (top safe area + horizontal margins).
        stackView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets(top: 25.0,
                                                                     left: Constants.Style.DefaultHorizontalMargins,
                                                                     bottom: 0,
                                                                     right: Constants.Style.DefaultHorizontalMargins))

        // 6) Add our UI elements to the stackView as arranged subviews.
        //    First the label, then the bars container.
        
        // Label
        valuesLabel.textAlignment = .center
        valuesLabel.text = "PEF Test"
        stackView.addArrangedSubview(valuesLabel)
        
        // barsContainerView (fixed size 200x250)
        stackView.addArrangedSubview(barsContainerView)
        barsContainerView.autoSetDimensions(to: CGSize(width: 200, height: 250))
        
        // 7) Inside barsContainerView, place actualBar and targetBar.
        barsContainerView.addSubview(actualBar)
        barsContainerView.addSubview(targetBar)
        
        // anchor them to the bottom so they grow upwards
        actualBar.autoPinEdge(.bottom, to: .bottom, of: barsContainerView)
        targetBar.autoPinEdge(.bottom, to: .bottom, of: barsContainerView)
        
        // set widths
        let barWidth: CGFloat = 50
        actualBar.autoSetDimension(.width, toSize: barWidth)
        targetBar.autoSetDimension(.width, toSize: barWidth)
        
        // initial heights = 0
        actualBarHeightConstraint = actualBar.autoSetDimension(.height, toSize: 0)
        targetBarHeightConstraint = targetBar.autoSetDimension(.height, toSize: 0)
        
        // We position the bars symmetrically around the centerX of barsContainerView.
        // e.g., left bar is slightly left, right bar is slightly right.
        actualBar.autoAlignAxis(.vertical, toSameAxisOf: barsContainerView, withOffset: -30)
        targetBar.autoAlignAxis(.vertical, toSameAxisOf: barsContainerView, withOffset: 30)
        
        // bar colors
        actualBar.backgroundColor = .systemBlue
        targetBar.backgroundColor = .systemRed
    }
    
    // MARK: - Actions Setup
    
    /// Configures target-action for the buttons.
    private func setupActions() {
        self.footerView.setButtonEnabled(enabled: true)
        self.footerView.addTarget(target: self, action: #selector(self.startTest))
    }
    
    @objc private func startTest() {
        // Toggle between Start/Stop
        if isPEFTestRunning {
            stopPEFTest()
        } else {
            startPEFTest()
        }
    }
    
    // MARK: - Manager Callbacks

    /// Sets up the main callbacks from the MirSpirometryService (MirSpirometryManager).
    private func setupManagerCallbacks() {
                
        // Called when the test actually starts
        service.onTestDidStart = { [weak self] in
            DispatchQueue.main.async {
                self?.valuesLabel.text = "Start blowing!"
            }
        }
        
        // Called when the test produces final results (JSON)
        service.onTestResults = { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.valuesLabel.text = "PEF Test completed"
                self.isPEFTestRunning = false
                self.footerView.setButtonText("Start PEF")
                
                // Here you can parse 'json' if you want or store it.
                // You may also want to reset the bar heights to 0 or keep them.
                UIView.animate(withDuration: 0.3) {
                    self.actualBarHeightConstraint.constant = 0
                    self.targetBarHeightConstraint.constant = 0
                    self.view.layoutIfNeeded()
                }
            }
        }
        
        service.onFlowValueUpdated = { [weak self] (flowValue, isFirstPackage) in
            // Calculate actual and target from soPatient
            // Animate the bars
            self?.handleFlowValue(flowValue, isFirstPackage: isFirstPackage)
        }
    }
    
    // MARK: - PEF Test Logic
        
    /// Called when user taps "Start PEF". We create or update the SOPatient, then run the test.
    private func startPEFTest() {
        
        // Create or update the patient
        if soPatient == nil {
            soPatient = createNewPatient()
        } else if let patient = soPatient {
            updatePatient(patient)
        }
        
        // Start the test via manager
        service.runTestPeakFlowFev1()
        
        isPEFTestRunning = true
        footerView.setButtonText("Stop PEF")
        valuesLabel.text = "PEF Test started"
    }
    
    /// Called when user taps "Stop PEF".
    private func stopPEFTest() {
        // The manager doesn't define a "stopTest()" directly, but you can disconnect or
        // call "device.stopTest()" if you have direct access.
        // A quick approach is: service.disconnect() or manager's connect logic.
        // Ideally, you'd add a method to MirSpirometryService to stop the test.
        
        // As an example, let's assume we do:
        service.disconnect()
        
        isPEFTestRunning = false
        footerView.setButtonText("Start PEF")
        valuesLabel.text = "PEF Test stopped"
        
        // Optionally reset bar heights
        UIView.animate(withDuration: 0.3) {
            self.actualBarHeightConstraint.constant = 0
            self.targetBarHeightConstraint.constant = 0
            self.view.layoutIfNeeded()
        }
    }
    
    // MARK: - Patient Management
        
    private func createNewPatient() -> SOPatient {
        // Example defaults
        let age = 33
        let height = 175
        let weight = 80
        return SOPatient(age: Float(age),
                         height: Float(height),
                         weight: Float(weight),
                         ethnic: SOEthnicGroupCaucasian,
                         gender: SOGenderMale)
    }
    
    private func updatePatient(_ patient: SOPatient) {
        // If you have UI textfields or user inputs, read them here.
        patient.age = 33
        patient.height = 175
        patient.weight = 80
    }
}

extension SpyrometerTestViewController {

    /// Example function to handle real-time flow updates from the manager (if implemented).
    func handleFlowValue(_ flowValue: Float, isFirstPackage: Bool) {
        guard let patient = soPatient else { return }

        // Compute Actual & Target
        var actual = patient.actualPercentageOfTarget(withFlow: flowValue,
                                                      volumeStep: soDevice?.volumeStep ?? Int(0.03),
                                                      isFirstPackage: isFirstPackage)
        let target = patient.predictedPercentageOfTarget(withFlow: flowValue,
                                                         volumeStep: soDevice?.volumeStep ?? Int(0.03),
                                                         isFirstPackage: isFirstPackage)
        
        print("FlowValue: \(flowValue)")
        print("Volume Step: \(soDevice?.volumeStep ?? 10000)")
        print("Actual: \(actual)")
        print("Target: \(target)")
        
        actual = 30
        // Clamp 0...100
        let actualClamped = max(min(actual, 100), 0)
        let targetClamped = max(min(target, 100), 0)
        
        // Convert to bar height
        let actualHeight = CGFloat(actualClamped / 100) * maxBarHeight
        let targetHeight = CGFloat(targetClamped / 100) * maxBarHeight
        
        DispatchQueue.main.async {
            self.valuesLabel.text = String(format: "Target: %.0f%% | Actual: %.0f%%", targetClamped, actualClamped)
            
            UIView.animate(withDuration: 0.2) {
                self.actualBarHeightConstraint.constant = actualHeight
                self.targetBarHeightConstraint.constant = targetHeight
                self.view.layoutIfNeeded()
            }
        }
    }
}
