//
//  Services.swift
//  ForYouAndMe
//
//  Created by Leonardo Passeri on 24/04/2020.
//  Copyright © 2020 Balzo srl. All rights reserved.
//

import UIKit
import RxSwift
#if SENSORKIT
import SensorKit
#endif

protocol InitializableService {
    var isInitialized: Bool { get }
    func initialize() -> Single<()>
}

struct ServicesSetupData {
    let showDefaultUserInfo: Bool
    let enableLocationServices: Bool
    let healthReadDataTypes: [HealthDataType]
    let appleWatchAlternativeIntegrations: [Integration]
    let defaultDoseType: DoseType?
}

class Services {
    
    static let shared = Services()
    
    private var services: [Any] = []
    
    private(set) var repository: Repository!
    private(set) var navigator: AppNavigator!
    private(set) var healthService: HealthService!
    private(set) var analytics: AnalyticsService!
    private(set) var storageServices: CacheService!
    private(set) var mirSpirometryService: MirSpirometryService!
    private(set) var deeplinkService: DeeplinkService!
    private(set) var deviceService: DeviceService!
#if TERRA
    private(set) var terraService: TerraService!
#endif
#if SENSORKIT
    private(set) var sensorKitService: SensorKitService?
#endif
    private(set) var defaultDoseType: DoseType?
    private var window: UIWindow?
    
    // MARK: - Public Methods
    
    func setup(withWindow window: UIWindow, servicesSetupData: ServicesSetupData) {
        self.window = window
        self.defaultDoseType = servicesSetupData.defaultDoseType
        
        let studyId = Constants.Network.StudyId
        
        let storage = CacheManager()
        self.services.append(storage)
        
        let mirSpirometryService = MirSpirometryManager()
        self.services.append(mirSpirometryService)
        
        let reachabilityService = ReachabilityManager()
        self.services.append(reachabilityService)
        
        let deeplinkService = DeeplinkManager()
        self.services.append(deeplinkService)
        
        let notificationService = NotificationManager(withNotificationDeeplinkHandler: deeplinkService)
        self.services.append(notificationService)
        
        #if DEBUG
        let networkApiGateway =
            Constants.Test.NetworkStubsEnabled
                ? TestNetworkApiGateway(studyId: studyId, reachability: reachabilityService, storage: storage)
                : NetworkApiGateway(studyId: studyId, reachability: reachabilityService, storage: storage)
        #else
        let networkApiGateway = NetworkApiGateway(studyId: studyId, reachability: reachabilityService, storage: storage)
        #endif
        self.services.append(networkApiGateway)
        
        let analytics = AnalyticsManager(api: networkApiGateway)
        self.services.append(analytics)

        // Register Telemetry sinks. JamLog (always), AnalyticsService bridge
        // (mirrors a small set of events to Firebase Analytics), Crashlytics
        // (mirrors `error:*` events as non-fatal records). Host apps can
        // append their own sinks afterwards via `Telemetry.register(...)`.
        Telemetry.setSinks([
            JamLogSink(),
            AnalyticsServiceSink(analytics: analytics),
            CrashlyticsSink()
        ])

        // Lifecycle event — replaces the FUAM-3074 smoke-test FYAMLog.info
        // line with a structured Telemetry event now that sinks are wired up.
        let podVersion = PodUtils.getPodResourceBundle(withName: "ForYouAndMe")?
            .infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let hostBundleId = Bundle.main.bundleIdentifier
        Telemetry.Lifecycle.frameworkStart(podVersion: podVersion, hostBundleId: hostBundleId)
        
        #if HEALTHKIT
        let healthService = HealthManager(withReadDataTypes: servicesSetupData.healthReadDataTypes,
                                          analyticsService: analytics,
                                          storage: storage,
                                          reachability: reachabilityService)
        #else
        let healthService = DummyHealthManager()
        #endif
        services.append(healthService)

        #if TERRA
        let terraService = TerraManager()
        self.services.append(terraService)
        #endif

        #if SENSORKIT
        var sensorKitService: SensorKitManager?
        if NSClassFromString("SRSensorReader") != nil {
            var skMappers: [SRSensor: SensorSampleMapper] = [:]
            // FUAM-3945 round 7 — enabled sensor set.
            // `.accelerometer` and `.rotationRate` are DISABLED: raw high-rate motion streams.
            // The volume kills the pipeline (24h windows x archive-rate samples, the whole window
            // buffered in memory before batching), so re-enabling either one first needs
            // minute-scale windows, a per-window sample cap and a real on-disk queue store.
            // `.pedometerData`, `.ambientLightSensor` and `.ambientPressure` are low-rate and are
            // enabled here; round 8 then intersects this list with the host's own entitlement
            // below, so a host that is not entitled to a sensor (Our Transitions covers pedometer
            // but neither ambient sensor) never asks for it in the first place.
            if #available(iOS 16.4, *) {
                skMappers = [
                    //            .accelerometer: AccelerometerMapper(),
                    //            .mediaEvents: MediaEventsMapper(),
                    //            .rotationRate: RotationRateMapper(),
                    .ambientLightSensor: AmbientLightMapper(),
                    .ambientPressure: AmbientPressureMapper(),
                    .visits: VisitsMapper(),
                    .pedometerData: PedometerMapper(),
                    .deviceUsageReport: DeviceUsageReportMapper(),
                    .phoneUsageReport: PhoneUsageReportMapper(),
                    .messagesUsageReport: MessagesUsageReportMapper(),
                    .keyboardMetrics: KeyboardMetricsMapper()
                ]
            } else {
                // Same set as above, minus `.mediaEvents` (iOS 16.4+ only).
                skMappers = [
                    //            .accelerometer: AccelerometerMapper(),
                    //            .rotationRate: RotationRateMapper(),
                    .ambientLightSensor: AmbientLightMapper(),
                    .ambientPressure: AmbientPressureMapper(),
                    .visits: VisitsMapper(),
                    .pedometerData: PedometerMapper(),
                    .deviceUsageReport: DeviceUsageReportMapper(),
                    .phoneUsageReport: PhoneUsageReportMapper(),
                    .messagesUsageReport: MessagesUsageReportMapper(),
                    .keyboardMetrics: KeyboardMetricsMapper()
                ]
            }

            // FUAM-3945 round 8: the host's own SensorKit entitlement is the CEILING of what we
            // request. iOS never prompts for an unentitled sensor — it auto-declines instantly and
            // the sensor stays `.notDetermined` forever, which used to wedge the Permissions row on
            // "Setup" and made the re-ask loop misdiagnose the system-wide switch as OFF.
            // Unreadable entitlement => `nil` => fail open (today's behaviour); a readable but empty
            // one genuinely means "entitled to nothing".
            let skEntitled = SensorKitEntitlement.entitledSensors()
            let skConfigured = Constants.SensorKit.RequestedSensors.intersection(Set(skMappers.keys))
            let skSensors: [SRSensor] = Array(SensorKitEntitlement.effectiveSensors(
                requested: Constants.SensorKit.RequestedSensors,
                mapped: Set(skMappers.keys),
                entitled: skEntitled))

            // A host misconfiguration must be visible, not silent: one event per launch listing the
            // sensors we would have asked for and cannot.
            let skDropped = skConfigured.subtracting(skSensors)
            if !skDropped.isEmpty {
                let dropped = SensorKitEntitlement.droppedSensorsParameter(skDropped.map { $0.shortSubsource })
                analytics.track(event: .sensorEntitlementMissing(sensors: dropped.list, count: dropped.count))
            }

            // `SensorKitManager` requires a non-empty sensor set; an entitlement covering none of
            // the configured sensors means there is no SensorKit service to build at all.
            if !skSensors.isEmpty {
                let skStorage: SensorKitManagerStorage = DefaultsSensorStorage()
                let skReachability: SensorKitManagerReachability = NWPathReachability()

                let skManager = SensorKitManager(
                    withReadSensors: skSensors,
                    analyticsService: analytics,
                    storage: skStorage,
                    reachability: skReachability,
                    mappers: skMappers
                )

                self.services.append(skManager)
                sensorKitService = skManager
            }
        }
        #endif
        
        let repository = RepositoryImpl(api: networkApiGateway,
                                        storage: storage,
                                        notificationService: notificationService,
                                        analyticsService: analytics,
                                        showDefaultUserInfo: servicesSetupData.showDefaultUserInfo,
                                        appleWatchAlternativeIntegrations: servicesSetupData.appleWatchAlternativeIntegrations)
        self.services.append(repository)
        
        let navigator = AppNavigator(withRepository: repository, analytics: analytics, deeplinkService: deeplinkService, window: window)
        self.services.append(navigator)
        
        let deviceService = DeviceManager(repository: repository,
                                          locationServicesAvailable: servicesSetupData.enableLocationServices,
                                          storage: storage,
                                          reachability: reachabilityService)
        self.services.append(deviceService)
        
        // Add services circular dependences
        deeplinkService.delegate = navigator
        notificationService.notificationTokenDelegate = repository
        #if HEALTHKIT
        healthService.networkDelegate = repository
        healthService.clearanceDelegate = repository
        #endif

        #if TERRA
        self.terraService = terraService
        #endif

        #if SENSORKIT
        if let sensorKitService = sensorKitService {
            sensorKitService.networkDelegate = repository
            sensorKitService.clearanceDelegate = repository
            self.sensorKitService = sensorKitService
        }
        #endif
        
        // Assign concreate services
        self.repository = repository
        self.navigator = navigator
        self.healthService = healthService
        self.analytics = analytics
        self.storageServices = storage
        self.mirSpirometryService = mirSpirometryService
        self.deeplinkService = deeplinkService
        self.deviceService = deviceService
        
        self.navigator.showSetupScreen()
    }
    
    func initializeServices() -> Observable<Float> {
        // Create an observable sequence that return the progress percentage
        // representing number of initialized services over the total initializable services
        let requests = self.services.compactMap { $0 as? InitializableService }
            .reduce([]) { (result, initializableService) -> [Single<()>] in
                var result = result
                if false == initializableService.isInitialized {
                    result.append(initializableService.initialize())
                }
                return result
        }
        
        return Observable.concat(requests.enumerated()
            .map { (index, request) in
                request.map { Float(index) / Float(requests.count) }.asObservable()
        })
    }
}
