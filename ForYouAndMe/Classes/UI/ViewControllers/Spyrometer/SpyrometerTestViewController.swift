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
    
//    // MARK: - Properties
//    
//    /// The spirometry service used to discover and connect to devices.
    var service: MirSpirometryService
//    
//    /// Called when the scanning is completed and the user taps "Continue".
//    var onScanCompleted: (() -> Void)?
//    
//    /// Called when the user cancels the scanning operation.
//    var onCancelled: (() -> Void)?
//        
//    /// Indicates whether a device has been successfully connected.
//    private var isDeviceConnected: Bool = false {
//        didSet {
//            // Enable the continue button only if a device is connected.
//            footerView.setButtonEnabled(enabled: isDeviceConnected)
//        }
//    }
//
//    private lazy var noBluetoothView = BluetoothOffView(withTopOffset: 8.0)
//    private lazy var noDevicesFound = BluetoothNoDevices(withTopOffset: 8.0)
//    
//    /// Table view to list discovered devices.
//    private lazy var devicesTableView: UITableView = {
//        let tableView = UITableView()
//        tableView.tableFooterView = UIView() // removes extra empty cells
//        tableView.contentInsetAdjustmentBehavior = .never
//        tableView.rowHeight = 80
//        return tableView
//    }()
//        
//    /// An array to store the discovered devices, displayed in the table view.
//    private var discoveredDevices: [SODeviceInfo] = []
//    
//    /// The ID of the device that is currently connected, if any.
//    private var connectedDeviceID: String?
//    
//    /// The ID of the device that the user selected to connect to.
//    private var selectedDeviceID: String?
//    
//    /// A timer to stop scanning after a certain duration.
//    private var scanTimer: Timer?
//    
//    // MARK: - UI Elements
//    
//    /// Label: "Select your device"
//    private let selectDeviceLabel: UILabel = {
//        let label = UILabel()
//        label.text = "Select your device"
//        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
//        label.numberOfLines = 1
//        return label
//    }()
//    
//    /// Button to trigger connection (demo).
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
//        setupServiceCallbacks()
//        setupTableView()
//        addObservers()
    }

    
    // MARK: - UI Setup using PureLayout
    
    /// Configures and adds UI elements to the view using PureLayout.
    private func setupUI() {
        
        let containerView = UIView()
        let stackView = UIStackView.create(withAxis: .vertical, spacing: 16.0)
        
        self.view.addSubview(containerView)
        containerView.addSubview(stackView)
        
        // Footer
        self.view.addSubview(self.footerView)
        
        containerView.autoPinEdgesToSuperviewEdges(with: .zero, excludingEdge: .bottom)
        stackView.autoPinEdgesToSuperviewSafeArea(with: UIEdgeInsets(top: 25.0,
                                                                     left: Constants.Style.DefaultHorizontalMargins,
                                                                     bottom: 0,
                                                                     right: Constants.Style.DefaultHorizontalMargins))
        
        // Connect button constraints.
        self.footerView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero, excludingEdge: .top)
        self.footerView.setButtonText(StringsProvider.string(forKey: .spiroNext))
    }
    
    // MARK: - Actions Setup
    
    /// Configures target-action for the buttons.
    private func setupActions() {
        self.footerView.setButtonEnabled(enabled: false)
//        self.footerView.addTarget(target: self, action: #selector(self.startScanDevices))
    }
    
//    // MARK: - Service Callbacks Setup
//    
//    /// Sets up callbacks to handle events from the spirometry service.
//    private func setupServiceCallbacks() {
//        // Update the devices label when new devices are discovered.
//        service.onDeviceDiscovered = { [weak self] devices in
//            guard let self = self else { return }
//            AppNavigator.popProgressHUD()
//            self.footerView.setButtonText(StringsProvider.string(forKey: .spiroScan))
//            self.footerView.addTarget(target: self, action: #selector(self.startScanDevices))
//            DispatchQueue.main.async {
//                // If there are devices, set the header; otherwise, remove it.
//                if devices.isEmpty {
//                    self.devicesTableView.tableHeaderView = nil
//                } else {
//                    self.devicesTableView.tableHeaderView = self.createTableHeaderView()
//                }
//                self.discoveredDevices = devices
//                self.devicesTableView.reloadData()
//            }
//        }
//        
//        // Update UI when a device is connected.
//        service.onDeviceConnected = { [weak self] in
//            DispatchQueue.main.async {
//                AppNavigator.popProgressHUD()
//                guard let self = self else { return }
//                self.connectedDeviceID = self.selectedDeviceID
//                self.isDeviceConnected = true
//                self.footerView.setButtonEnabled(enabled: true)
//                self.footerView.setButtonText(StringsProvider.string(forKey: .spiroNext))
//                self.footerView.addTarget(target: self, action: #selector(self.continueButtonTapped))
//                self.devicesTableView.reloadData()
//            }
//        }
//        
//        // Show an alert if the connection fails.
//        service.onDeviceConnectFailed = { [weak self] error in
//            DispatchQueue.main.async {
//                let message = error?.localizedDescription ?? "Connection Failed"
//                let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
//                alert.addAction(UIAlertAction(title: "OK", style: .default))
//                self?.present(alert, animated: true)
//            }
//        }
//    }
//    
//    // MARK: - Button Actions
//    
//    @objc private func startScanDevices() {
//        // Start discovering devices only if Bluetooth is active.
//        service.startDiscoverDevices()
//        AppNavigator.pushProgressHUD()
//        // Start the timer
//        startScanTimer()
//        self.footerView.setButtonText(StringsProvider.string(forKey: .spiroStop))
//        self.footerView.addTarget(target: self, action: #selector(self.cancelButtonTapped))
//    }
//    
//    /// Schedules a timer that stops scanning after `BluetoothScanDurationSeconds`.
//    private func startScanTimer() {
//        scanTimer?.invalidate()
//        scanTimer = Timer.scheduledTimer(withTimeInterval: Constants.Misc.BluetoothScanDurationSeconds,
//                                         repeats: false,
//                                         block: { [weak self] _ in
//            guard let self = self else { return }
//            
//            // Stop scanning
//            self.service.stopDiscoverDevices()
//            
//            // If no devices were found, show the "no devices" background
//            if self.discoveredDevices.isEmpty {
//                AppNavigator.popProgressHUD()
//                self.footerView.setButtonText(StringsProvider.string(forKey: .spiroScan))
//                self.footerView.setButtonEnabled(enabled: true)
//                self.footerView.addTarget(target: self, action: #selector(self.startScanDevices))
//                self.devicesTableView.backgroundView = self.noDevicesFound
//            }
//        })
//    }
//    
//    /// Called when the cancel button is tapped. Stops device discovery and triggers cancellation.
//    @objc private func cancelButtonTapped() {
//        AppNavigator.popProgressHUD()
//        service.stopDiscoverDevices()
//        self.footerView.setButtonText(StringsProvider.string(forKey: .spiroScan))
//        self.footerView.addTarget(target: self, action: #selector(self.startScanDevices))
//    }
//    
//    /// Called when the footer "Continue" button is tapped.
//    /// Proceeds to the next step only if a device is connected.
//    @objc private func continueButtonTapped() {
//        if isDeviceConnected {
//            onScanCompleted?()
//        } else {
//            let alert = UIAlertController(title: "Warning",
//                                          message: "No device connected. Please connect to a device before continuing.",
//                                          preferredStyle: .alert)
//            alert.addAction(UIAlertAction(title: "OK", style: .default))
//            present(alert, animated: true)
//        }
//    }
//    
//    // MARK: - Cleanup
//    
//    override func viewWillDisappear(_ animated: Bool) {
//        super.viewWillDisappear(animated)
//        service.stopDiscoverDevices()
//    }
}
