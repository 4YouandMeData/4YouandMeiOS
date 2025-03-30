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
    /// Called when the scanning is completed and the user taps "Continue".
    var onTestCompleted: ((SOResults) -> Void)?
    
    var onDeviceDisconnected: (() -> Void)?

//    /// Called when the user cancels the scanning operation.
//    var onCancelled: (() -> Void)?

    // MARK: - UI Elements
    
    /// Flag to know if the test is running or not.
    private var isPEFTestRunning = false
    
    /// Button to trigger connection (demo).
    private lazy var footerView: GenericButtonView = {
        let buttonView = GenericButtonView(withTextStyleCategory: .secondaryBackground(shadow: true ))
        return buttonView
    }()
    
    private let targetBarView = SpyroBar()
    private let actualBarView = SpyroBar()
    
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
        self.checkBluetoothState()
    }

    // MARK: - UI Setup using PureLayout
    
    /// Configures and adds UI elements to the view using PureLayout.
    private func setupUI() {
  
        let containerView = UIView()
        view.addSubview(containerView)

        view.addSubview(self.footerView)
        
        // Footer pinned to bottom, left, right
        self.footerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .top)
        // Set the initial button text
        self.footerView.setButtonText(StringsProvider.string(forKey: .spiroNext))
        
        containerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        containerView.autoPinEdge(.bottom, to: .top, of: footerView)
                
        containerView.addSubview(targetBarView)
        containerView.addSubview(actualBarView)
        
        targetBarView.configureBar(
            text: "TARGET",
            topColor: UIColor(red: 0.9, green: 1.0, blue: 0.9, alpha: 1.0),   // chiaro
            bottomColor: UIColor(red: 0.4, green: 0.8, blue: 0.4, alpha: 1.0) // scuro
        )
        actualBarView.configureBar(
            text: "ACTUAL",
            topColor: UIColor(red: 1.0, green: 0.88, blue: 0.69, alpha: 1.0),  // chiaro
            bottomColor: UIColor(red: 1.0, green: 0.65, blue: 0.0, alpha: 1.0) // scuro
        )
        
        targetBarView.autoAlignAxis(.horizontal, toSameAxisOf: containerView)
        actualBarView.autoAlignAxis(.horizontal, toSameAxisOf: containerView)
        
        targetBarView.autoAlignAxis(.vertical, toSameAxisOf: containerView, withOffset: -48)
        actualBarView.autoAlignAxis(.vertical, toSameAxisOf: containerView, withOffset: 48)
    }
    
    @objc private func willEnterForeground() {
        self.checkBluetoothState()
    }
    
    /// Checks if Bluetooth is active. If not, shows an error alert.
    private func checkBluetoothState() {
        if service.isPoweredOn() == false {
            self.handleDeviceDisconnected()
        }
    }
    
    private func handleDeviceDisconnected() {
        if isPEFTestRunning {
            stopPEFTest()
        }
        self.onDeviceDisconnected?()
        self.footerView.setButtonEnabled(enabled: false)
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

        service.onDeviceDisconnected = { [weak self] in
           DispatchQueue.main.async {
               guard let self = self else { return }
               self.handleDeviceDisconnected()
           }
        }
        
        service.onBluetoothStateChanged = { [weak self] newState in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if newState != .poweredOn {
                    // Bluetooth spento / non disponibile => disconnessione
                    self.handleDeviceDisconnected()
                }
            }
        }
        // Called when the test actually starts
        service.onTestDidStart = { [weak self] in
            guard let self = self else { return }
            
            self.isPEFTestRunning = true
            self.footerView.setButtonEnabled(enabled: false)
        }
        
        // Called when the test produces final results (JSON)
        service.onTestResults = { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.isPEFTestRunning = false
                self.footerView.setButtonText("Next")
                self.onTestCompleted?(result)
            }
        }
        
        service.onFlowValueUpdated = { [weak self] (soDevice, flowValue, isFirstPackage) in
            // Calculate actual and target from soPatient
            // Animate the bars
            self?.handleFlowValue(soDevice, flowValue: flowValue, isFirstPackage: isFirstPackage)
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
    }
    
    /// Called when user taps "Stop PEF".
    private func stopPEFTest() {
        // As an example, let's assume we do:
        service.disconnect()
        
        isPEFTestRunning = false
        footerView.setButtonText("Start PEF")
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
    func handleFlowValue(_ soDevice: SODevice, flowValue: Float, isFirstPackage: Bool) {
        guard let patient = soPatient else { return }

        // Compute Actual & Target
        let actual = patient.actualPercentageOfTarget(withFlow: flowValue,
                                                      volumeStep: soDevice.volumeStep,
                                                      isFirstPackage: isFirstPackage)
        let target = patient.predictedPercentageOfTarget(withFlow: flowValue,
                                                         volumeStep: soDevice.volumeStep,
                                                         isFirstPackage: isFirstPackage)
        
        print("FlowValue: \(flowValue)")
        print("Volume Step: \(soDevice.volumeStep)")
        print("Actual: \(actual)")
        print("Target: \(target)")
        
        self.targetBarView.updatePercentage(CGFloat(target))
        self.actualBarView.updatePercentage(CGFloat(actual))
    }
}
