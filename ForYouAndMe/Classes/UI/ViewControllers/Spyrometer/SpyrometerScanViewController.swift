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
class SpyrometerScanViewController: UIViewController {
    
    // MARK: - Properties
    
    /// The spirometry service used to discover and connect to devices.
    var service: MirSpirometryService
    
    /// Called when the scanning is completed and the user taps "Continue".
    var onScanCompleted: (() -> Void)?
    
    /// Called when the user cancels the scanning operation.
    var onCancelled: (() -> Void)?
        
    /// Indicates whether a device has been successfully connected.
    private var isDeviceConnected: Bool = false {
        didSet {
            // Enable the continue button only if a device is connected.
            footerView.setButtonEnabled(enabled: isDeviceConnected)
        }
    }

    private lazy var noBluetoothView = BluetoothOffView(withTopOffset: 8.0)
    private lazy var noDevicesFound = BluetoothNoDevices(withTopOffset: 8.0)
    
    /// Table view to list discovered devices.
    private lazy var devicesTableView: UITableView = {
        let tableView = UITableView()
        tableView.tableFooterView = UIView() // removes extra empty cells
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.rowHeight = 80
        return tableView
    }()
        
    /// An array to store the discovered devices, displayed in the table view.
    private var discoveredDevices: [SODeviceInfo] = []
    
    /// The ID of the device that is currently connected, if any.
    private var connectedDeviceID: String?
    
    /// The ID of the device that the user selected to connect to.
    private var selectedDeviceID: String?
    
    /// A timer to stop scanning after a certain duration.
    private var scanTimer: Timer?
    
    // MARK: - UI Elements
    
    /// Label: "Select your device"
    private let selectDeviceLabel: UILabel = {
        let label = UILabel()
        label.text = StringsProvider.string(forKey: .spiroSelectDevice)
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        label.numberOfLines = 1
        return label
    }()
    
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
        setupServiceCallbacks()
        setupTableView()
        addObservers()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        checkBluetoothState()
    }
    
    private func addObservers() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(self.willEnterForeground),
                                               name: UIApplication.didBecomeActiveNotification,
                                               object: nil)
    }
    
    @objc private func willEnterForeground() {
        self.checkBluetoothState()
    }
    
    // MARK: - Bluetooth State Check
    
    /// Checks if Bluetooth is active. If not, shows an error alert.
    private func checkBluetoothState() {
        if service.isPoweredOn() == false {
            self.footerView.setButtonEnabled(enabled: false)
            self.devicesTableView.backgroundView = self.noBluetoothView
        } else {
            self.footerView.setButtonEnabled(enabled: true)
            self.devicesTableView.backgroundView = nil
        }
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
        
        stackView.addLabel(withText: StringsProvider.string(forKey: .spiroTitle),
                           fontStyle: .title,
                           color: ColorPalette.color(withType: .primaryText),
                           textAlignment: .left)
        stackView.addLabel(withText: StringsProvider.string(forKey: .spiroSubtitle),
                           fontStyle: .paragraph,
                           color: ColorPalette.color(withType: .primaryText),
                           textAlignment: .left)
        // Table view
        self.view.addSubview(self.devicesTableView)
        self.devicesTableView.autoPinEdge(.top, to: .bottom, of: stackView, withOffset: 32)
        self.devicesTableView.autoPinEdge(toSuperviewEdge: .leading)
        self.devicesTableView.autoPinEdge(toSuperviewEdge: .trailing)
        self.devicesTableView.autoPinEdge(.bottom, to: .top, of: self.footerView, withOffset: -16)
        
        // Connect button constraints.
        self.footerView.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets.zero, excludingEdge: .top)
        self.footerView.setButtonText(StringsProvider.string(forKey: .spiroScan))
    }
    
    private func setupTableView() {
        devicesTableView.dataSource = self
        devicesTableView.delegate = self
        // Optionally register a custom cell or just use UITableViewCell
        devicesTableView.register(UITableViewCell.self, forCellReuseIdentifier: "DeviceCell")
    }
    
    /// Creates a custom tableHeaderView containing the label "Select your device".
    private func createTableHeaderView() -> UIView {
        let headerContainer = UIView()
        headerContainer.backgroundColor = .clear
        
        let label = UILabel()
        label.text = "Select your device"
        label.font = FontPalette.fontStyleData(forStyle: .header2).font
        label.textColor = ColorPalette.color(withType: .primaryText)
        label.textAlignment = .left
        headerContainer.addSubview(label)
        
        // Use PureLayout inside the header
        label.autoPinEdgesToSuperviewEdges(with: UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12))
        
        // Let Auto Layout calculate the correct height
        headerContainer.layoutIfNeeded()
        let height = headerContainer.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
        
        // Set the frame to the calculated height
        headerContainer.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: height)
        
        return headerContainer
    }
    
    // MARK: - Actions Setup
    
    /// Configures target-action for the buttons.
    private func setupActions() {
        self.footerView.addTarget(target: self, action: #selector(self.startScanDevices))
    }
    
    // MARK: - Service Callbacks Setup
    
    /// Sets up callbacks to handle events from the spirometry service.
    private func setupServiceCallbacks() {
        // Update the devices label when new devices are discovered.
        service.onDeviceDiscovered = { [weak self] devices in
            guard let self = self else { return }
            AppNavigator.popProgressHUD()
            self.footerView.setButtonText(StringsProvider.string(forKey: .spiroScan))
            self.footerView.addTarget(target: self, action: #selector(self.startScanDevices))
            DispatchQueue.main.async {
                // If there are devices, set the header; otherwise, remove it.
                if devices.isEmpty {
                    self.devicesTableView.tableHeaderView = nil
                } else {
                    self.devicesTableView.tableHeaderView = self.createTableHeaderView()
                }
                self.discoveredDevices = devices
                self.devicesTableView.reloadData()
            }
        }
        
        // Update UI when a device is connected.
        service.onDeviceConnected = { [weak self] in
            DispatchQueue.main.async {
                AppNavigator.popProgressHUD()
                guard let self = self else { return }
                self.connectedDeviceID = self.selectedDeviceID
                self.isDeviceConnected = true
                self.footerView.setButtonEnabled(enabled: true)
                self.footerView.setButtonText(StringsProvider.string(forKey: .spiroNext))
                self.footerView.addTarget(target: self, action: #selector(self.continueButtonTapped))
                self.devicesTableView.reloadData()
            }
        }
        
        // Show an alert if the connection fails.
        service.onDeviceConnectFailed = { [weak self] error in
            DispatchQueue.main.async {
                let message = error?.localizedDescription ?? "Connection Failed"
                let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(alert, animated: true)
            }
        }
    }
    
    // MARK: - Button Actions
    
    @objc private func startScanDevices() {
        // Start discovering devices only if Bluetooth is active.
        self.devicesTableView.backgroundView = nil
        service.startDiscoverDevices()
        AppNavigator.pushProgressHUD()
        // Start the timer
        startScanTimer()
        self.footerView.setButtonText(StringsProvider.string(forKey: .spiroStop))
        self.footerView.addTarget(target: self, action: #selector(self.cancelButtonTapped))
    }
    
    /// Schedules a timer that stops scanning after `BluetoothScanDurationSeconds`.
    private func startScanTimer() {
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: Constants.Misc.BluetoothScanDurationSeconds,
                                         repeats: false,
                                         block: { [weak self] _ in
            guard let self = self else { return }
            
            // Stop scanning
            self.service.stopDiscoverDevices()
            
            // If no devices were found, show the "no devices" background
            if self.discoveredDevices.isEmpty {
                AppNavigator.popProgressHUD()
                self.footerView.setButtonText(StringsProvider.string(forKey: .spiroScan))
                self.footerView.setButtonEnabled(enabled: true)
                self.footerView.addTarget(target: self, action: #selector(self.startScanDevices))
                self.devicesTableView.backgroundView = self.noDevicesFound
            }
        })
    }
    
    /// Called when the cancel button is tapped. Stops device discovery and triggers cancellation.
    @objc private func cancelButtonTapped() {
        AppNavigator.popProgressHUD()
        service.stopDiscoverDevices()
        self.footerView.setButtonText(StringsProvider.string(forKey: .spiroScan))
        self.footerView.addTarget(target: self, action: #selector(self.startScanDevices))
    }
    
    /// Called when the footer "Continue" button is tapped.
    /// Proceeds to the next step only if a device is connected.
    @objc private func continueButtonTapped() {
        if isDeviceConnected {
            onScanCompleted?()
        } else {
            let alert = UIAlertController(title: "Warning",
                                          message: "No device connected. Please connect to a device before continuing.",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
    
    // MARK: - Cleanup
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        service.stopDiscoverDevices()
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate

extension SpyrometerScanViewController: UITableViewDataSource, UITableViewDelegate {
    
    /// Number of rows = number of discovered devices
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return discoveredDevices.count
    }
    
    /// Basic cell that shows the device name (or a placeholder if name is nil)
    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "DeviceCell", for: indexPath)
        let deviceInfo = discoveredDevices[indexPath.row]
        let firstLine = deviceInfo.name ?? ""
        let secondLine = deviceInfo.nameCached ?? ""
        let fullText = "\(firstLine)\n\(secondLine)"
        let attributedText = NSMutableAttributedString(string: fullText)

        // Create a paragraph style with increased line spacing
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 10.0 // Adjust this value to increase spacing

        // Apply the paragraph style to the entire string
        attributedText.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attributedText.length))

        cell.textLabel?.attributedText = attributedText
        cell.textLabel?.numberOfLines = 2
        cell.textLabel?.font = FontPalette.fontStyleData(forStyle: .paragraph).font
        cell.textLabel?.textColor = ColorPalette.color(withType: .primaryText)
        cell.separatorInset = UIEdgeInsets(top: 0, left: 22, bottom: 0, right: 22)
        
        // Show a check icon if this device is connected
        if deviceInfo.deviceID == connectedDeviceID {
            cell.accessoryView = UIImageView(image: ImagePalette.image(withName: .deviceConnected))
        } else {
            cell.accessoryView = nil
        }
        return cell
    }
    
    /// Optional: if you want to connect to a device when the user taps a row
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        
        let deviceInfo = discoveredDevices[indexPath.row]
        print("Selected device: \(deviceInfo.name ?? "Unknown")")
        
        // If you want to connect automatically:
        service.stopDiscoverDevices()
        self.footerView.setButtonText(StringsProvider.string(forKey: .spiroNext))
        self.footerView.setButtonEnabled(enabled: false)
        // If your service has a connect(to:) method, pass the deviceID or info
        AppNavigator.pushProgressHUD()
        self.selectedDeviceID = deviceInfo.deviceID
        service.connect(deviceID: deviceInfo.deviceID)
    }
}
