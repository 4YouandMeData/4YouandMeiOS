//
//  SODevice.h
//  SmartOneKit-Playground
//
//  Created by Marco Fiaschini & Tereshkin Sergey on 02/10/15.
//  Copyright © 2015 MIR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "SODeviceInfo.h"
#import "SOResults.h"
#import "PublicDefs.h"
#import "SOResultsOximetry.h"
#import "SOResultsFvcPlus.h"
#import "SOResultsVc.h"
#import "SOResultsEcg.h"
#import "SOEcgPacketInfo.h"
#import "SODeviceStatus.h"
#import "SOCardionicaDeviceStatus.h"
#import "hrCurvePoint.h"
#import "SOResultsMvv.h"


@class SODevice;


@protocol SODeviceDelegate <NSObject>

// ---------------------------------------
// ATTENTION: remember that any delegate method of SODevice (as any other SmartOneKit class) will be called simultaneously for each active viewcontroller that is a delegate of it (and, of course, has implemented that method). This because of the multiple delegation pattern used
// ---------------------------------------

@required

// /**
// vers 2.6.0 - 1.3.0
// *  @method soDeviceWillRestartTest
// *
// *  @discussion             This method is invoked when the device has performed an inhalation
//                            after a valid inhalation
// */
// - (void)soDeviceWillRestartTest:(SODevice *)soDevice;


/*!
 *  @method soDeviceDidRestartTest:
 *
 *  @param soDevice         The device providing this information.
 *
 *  @discussion             This method is invoked with a delay after that soDevice:didUpdateResults: has been fired
 *                          It is meant to be used to reset your graphical interface between expiration manouvers without sending the command to stop and (re)start the test
 *
 */
- (void)soDeviceDidRestartTest:(SODevice *)soDevice;


/*!
 *  @method soDeviceDidStopTest:
 *
 *  @param soDevice         The device providing this information.
 *
 *  @discussion             This method is invoked when the device has stopped the test after a timeout because of user inactivity.
 *                          After this method is fired, noone of the delegated methods will be fired anymore:
 *                          {soDevice:didUpdateFlowValue:isFirstPackage:, soDevice:didUpdateResults:, soDevice:didUpdateResults:, soDeviceDidRestartTest:, soDeviceDidStopTest:}
 *
 */
- (void)soDeviceDidStopTest:(SODevice *)soDevice;


/**
 vers 2.6.0 - 1.3.0
 *  @method soDeviceDidStartTest
 *
 *  @discussion             This method is invoked when the device is actually REAY to read values.
 *                          when this method is called, the client app can tell the user to start exhaling / blowing
 */
- (void)soDeviceDidStartTest:(SODevice *)soDevice;


@optional

/*!
 *  @method soDevice:didUpdateFlowValue:isFirstPackage:
 *
 *  @param soDevice         The device providing this information.
 *  @param value            The measured flow value in cL
 *  @param isFirstPackage   It is == YES when the received value (flow) is the first one of the test
 *
 *  @discussion             This method is invoked each time a flow value is received.
 *
 */
- (void)soDevice:(SODevice *)soDevice didUpdateFlowValue:(float)value isFirstPackage:(BOOL)isFirstPackage;


/*!
 *  @method soDevice:didUpdateResults:
 *
 *  @param soDevice         The device providing this information.
 *  @param results          It includes the measured values (Peak Flow, FEV1, Time to Peak Flow, Extrapolated Volume and Quality code)
 *
 *  @discussion             This method is invoked each time a complete expiration manouver (at least 1 second) is taken.
 *
 */
- (void)soDevice:(SODevice *)soDevice didUPdateResults:(SOResults *)results;


- (void)soDevice:(SODevice *)soDevice didUpdateLastCommandStatus:(BOOL)isSucceded;


- (void)soDevice:(SODevice *)soDevice didUpdateDeviceStatus:(SODeviceStatus *)deviceStatus;


/**
 vers 2.1.0 firmwareUpdate
 Invoked when there is a progress in the firmware update procedure.
 
 @param soDevice The device providing this information.
 @param progress The percentage value of the update progress
 @param status The update status code
 @param description If an error occurred, the cause of the failure, `nil` otherwise.
 
 */
- (void)soDevice:(SODevice *)soDevice didReceiveSoftwareUpdateProgress:(NSUInteger)progress withStatus:(UpdateStatus)status error:(NSString *)description;

// SMART ONE OX: vers 2.7 - 1.4 - 1.0 OXIMETRY TEST -----------------------

/*!
 *  @method soDevice:didUpdateOximetryValues:(Byte)signal spO2Value:(Byte) spo2 bpmValue: (int) bpm;
 *  @param soDevice         The device providing this information.
 *  @param signal           The signal strenght (range 0 --> 8)
 *  @param spO2             The spO2 value % (range 70--> 99)
 *  @param bpm              The Heart rate bpm (range 30 --> 300)
 *  @param fingerOn           retrieves YES if the finger is detected by the oximetry sensor, NO if it isn't.
 *
 *  @discussion             This method is invoked each time an oximetry value is received.
 *
 * *  @discussion             This method  has been deprecated  a new method must be called now,
 *                          didUpdateOximetryRealTimeValuesWithSignal:spO2Value:bpmValue:warning:isDataValid
 */
- (void)soDevice:(SODevice *)soDevice didUpdateOximetryRealTimeValuesWithSignal:(int)signal
       spO2Value:(int)spO2
        bpmValue:(int)bpm
      isFingerOn:(BOOL)fingerOn
isSearchingForPulse:(BOOL)searchingForPulse
     isDataValid:(BOOL)dataValid
    isBatteryLow:(BOOL)batteryLow DEPRECATED_MSG_ATTRIBUTE("use didUpdateOximetryRealTimeValuesWithSignal:spO2Value:bpmValue:warning:isDataValid instead");


// SMART ONE OX: vers 2.8 - 1.5 - 2.0 OXIMETRY TEST -----------------------

/*!
 *  @method soDevice:didUpdateOximetryValues:(Byte)signal spO2Value:(Byte) spo2 bpmValue: (int) bpm;
 *  @param soDevice           The device providing this information.
 *  @param signal               The signal strenght (range 0 --> 8)
 *  @param spO2                    The spO2 value % (range 70--> 99)
 *  @param bpm                      The Heart rate bpm (range 30 --> 300)
 *  @param warning              retrieves a warning  that explains what error occurred (no error = NoWarning)
 *  @param isdatavalid     = No when data are not reliable (independently by the warning). In such case data are not used to calcularte the results.
 *                      If you youse a Timer for the test duration count, it should be stopped when isvaliddata = NO
 *
 *  @discussion             This method is invoked each time an oximetry value is received.
 *
 */
- (void)soDevice:(SODevice *)soDevice didUpdateOximetryRealTimeValuesWithSignal:(int)signal
       spO2Value:(int)spO2
        bpmValue:(int)bpm
         warning:(SOOximetryWarnings)warning
     isDataValid:(BOOL)isdatavalid;

// SMART ONE OX: vers 2.8 - 1.5 - 2.0 OXIMETRY TEST -----------------------
/*!
 *  @discussion             This method is invoked  when a test is started with battery low level
 */
- (void)TestWillStopForBatteryLow:(SODevice *)soDevice;


/**
 *  @method soDeviceHeartBeatDetected
 *
 *  @discussion             This method is invoked each time an heart beat is detected by the oximeter
 *
 */
- (void)soDevice:(SODevice *)soDevice heartBeatDetected:(int)bpm;


/*!
 *  @method soDevice:didUpdateOximetryResults:
 *
 *  @param soDevice         The device providing this information.
 *  @param oximetryResults          It includes the measured values (SpO2mean, SpO2max, SpO2min, heartRateMean, heartRateMax, heartRateMin)
 *
 *  @discussion             This method is invoked AFTER the Oximetry ends
 *
 */
- (void)soDevice:(SODevice *)soDevice didUpdateOximetryResults:(SOResultsOximetry*)oximetryResults;


/*!
 *  @method soDevice:(SODevice *)soDevice didUpdateOximetryPletismographicValues: (int) ppmSignal:
 *
 *  @param soDevice         The device providing this information.
 *  @param ppmSignal        The singol point to plot the Pletismographic curve
 *
 *  @discussion             This method is invoked, in real time, during the oximetry
 *
 */
- (void)soDevice:(SODevice *)soDevice didUpdateOximetryPletismographicValue:(int)ppmSignal;


/*!
 *  @method soDevice:(SODevice *)soDevice didUpdateFlowTimeMonitoringValue: (int) value:
 *
 *  @param soDevice         The device providing this information.
 *  @param value            The measured flow value in cL
 *
 *  @discussion             This method is invoked, in real time, during the flowTime Monitoring test
 *
 */
- (void)soDevice:(SODevice *)soDevice didUpdateFlowTimeMonitoringValue:(int)value;


/*!
 *  @method soDevice:(SODevice *)soDevice didUpdateFlowTimeMonitoringValue: (int) value: timeMilliseconds:(long)timeMilliseconds;
 *
 *  @param soDevice         The device providing this information.
 *  @param value            The measured flow value in cL
 *  @param timeMilliseconds            The timestamp of this method when is invoked
 *
 *  @discussion             This method is invoked, in real time, during the flowTime Monitoring test
 *
 */
- (void)soDevice:(SODevice *)soDevice didUpdateFlowTimeMonitoringValue:(int)value timeMilliseconds:(long)timeMilliseconds;



/*!
 *  @method soDevice:didUpdateFlowValue:isFirstPackage:
 *
 *  @param soDevice          The device providing this information.
 *  @param fvPoint             The measured flow value in L and volume value in L
 *  @param isFirstPackage   = YES when the received values (flow-volume) are the first ones of the test
 *
 *  @discussion             This method is invoked each time a flow value is received.
 *
 */
- (void)soDevice:(SODevice *)soDevice didUpdateFvcPlusFlowVolumePoint:(flowVolmePoint *)fvPoint isFirstPackage:(BOOL)isFirstPackage;


/*!
 *  @method soDevice:didUpdateResults:∫
 *
 *  @param soDevice         The device providing this information.
 *  @param results          It includes the measured values (Peak Flow, FEV1, Time to Peak Flow, Extrapolated Volume and Quality code)
 *
 *  @discussion             This method is invoked each time a complete expiration manouver  is taken.
 *
 */
- (void)soDevice:(SODevice *)soDevice didUPdateFvcPlusResults:(SOResultsFvcPlus *)results;

// - (void)soDevice:(SODevice *)soDevice DeviceDidRespondToFvcPlusEnabling:(ResponseType)deviceResponse;

//----------------------------------------------------

// vers 2.9  -----------------------
/*!
 *  @discussion      This method is invoked  when the device was disconnected itself
 */
- (void)deviceWasDisconnected:(SODevice *)soDevice;


/*!
 *  @discussion      This method is invoked when an indicator of the End Of Forced Expiration
 *                   (a Plateau OR the 15 secods of expiation time) have been received from the device
 */
//*****ATS2019 ************************************
- (void)soDevice:(SODevice *)soDevice didReceiveEndOfForcedExpirationIndicator:(EndOfForcedExpirationIndicator)eofeIndicator;
//***************************************************


/*!
 *  @method soDevice:didUpdateVcVolumeTimePoint:isFirstPackage:
 *
 *  @param soDevice          The device providing this information.
 *  @param vcVtPoint        The measured volume time values in L and seconds
 *  @param isFirstPackage   = YES when the received values (flow-volume) are the first ones of the test
 *
 *  @discussion         This method is invoked each time a volume value is received during a VC test
 */
- (void)soDevice:(SODevice *)soDevice didUpdateVcVolumeTimePoint:(volumeTimePoint *)vcVtPoint isFirstPackage:(BOOL)isFirstPackage;

/*!
 *  @method soDevice:didUpdateMvvVolumeTimePoint:isFirstPackage:
 *
 *  @param soDevice          The device providing this information.
 *  @param mvvVtPoint        The measured volume time values in L and seconds
 *  @param isFirstPackage   = YES when the received values (flow-volume) are the first ones of the test
 *
 *  @discussion         This method is invoked each time a volume value is received during an MVV test
 */
- (void)soDevice:(SODevice *)soDevice didUpdateMvvVolumeTimePoint:(volumeTimePoint *)mvvVtPoint isFirstPackage:(BOOL)isFirstPackage;

/*!
 *  @method soDevice:didPerformVentilatoryProfile:
 *
 *  @param soDevice          The device providing this information.
 *
 *  @discussion         This method is invoked when the user has performed the ventilatory profile (= 3 similar breaths at rest).
 *                      After this method is invoked the patient can start the slow and deep exhalation or inhalation that is the VC test
 */
- (void)didPerformVentilatoryProfile:(SODevice *)soDevice;


/*!
 *  @method soDevice:didUPdateVcResults:
 *
 *  @param soDevice        The device providing this information.
 *  @param results          It includes the measured values (EVC, IVC, IC, SET or SIT,  VolumeTume curve points)
 *
 *  @discussion       This method is invoked each time a complete Slow Vital Capacity manouver  is taken.
 */
- (void)soDevice:(SODevice *)soDevice didUPdateVcResults:(SOResultsVc *)results;

/*!
 *  @method soDevice:didUPdateMvvResults:
 *
 *  @param soDevice        The device providing this information.
 *  @param results          It includes the measured values (MVV and  VolumeTume curve points)
 *
 *  @discussion       This method is invoked each time a complete MVV manouver  is taken.
 */
- (void)soDevice:(SODevice *)soDevice didUPdateMvvResults:(SOResultsMvv *)results;



- (void)soDevice:(SODevice *)soDevice didAttemptToFixFvcPlusActivation:(FixFvcPlusResult)result;

/*!
 *  @method soDevice:didReceiveRawPacket:
 *
 *  @param soDevice        The device providing this information.
 *  @param packetData    raw data bytes packet
 *  @param packetType    parsed type from SOParser (typically byte at index 1)
 *
 *  @discussion       This method is invoked when the device has SOParserCallbackModeRaw callback mode from parser
 */
- (void)soDevice:(SODevice *)soDevice didReceiveRawPacket:(NSData*)packetData withType:(SOParserRawPacketType)packetType;



// MARK: - ECG Test

NS_ASSUME_NONNULL_BEGIN

- (void)soDeviceEcgTestShouldBeStarted:(SODevice *)soDevice;

- (void)soDevice:(SODevice *)soDevice didReceiveEcgInfo:(SOEcgPacketInfo *)info;

- (void)soDevice:(SODevice *)soDevice didReceiveEcgValues:(NSArray<NSNumber *> *)values;

- (void)soDevice:(SODevice *)soDevice didUpdateEcgResults:(SOResultsEcg *)results;

- (void)soDevice:(SODevice *)soDevice didReceiveEcgProgress:(float)progress;

- (void)soDevice:(SODevice *)soDevice didUpdateEcgResultsList:(NSArray<SOResultsEcg *> *)resultsList;

NS_ASSUME_NONNULL_END

//MARK: HIGH RESOLUTION CURVE

- (void)soDevice:(SODevice *)soDevice didUpdateHighResolutionCurvePoints:(NSMutableArray<hrCurvePoint *> *_Nullable)curvePoints;

@end


@interface SODevice : NSObject

@property (nonatomic, strong, nullable) SODeviceStatus *deviceStatus;

@property (nonatomic, strong) SODeviceInfo *deviceInfo;
@property (nonatomic) NSInteger batteryLevel;
@property (nonatomic) NSInteger volumeStep;
@property (nonatomic, strong) NSString *softwareVersion;
@property (nonatomic, strong) NSString *bluetoothVersion;

@property (nonatomic) SOTestType currentTestMode; //vers 2.0
// vers. 2.9.0 ------------------------------------------------
@property (nonatomic, strong) NSString *serialNumberWithoutLeadingLetter;
// vers. 2.9.8 -------------------------------------------------
@property (nonatomic, strong) NSString *modelNumber;
// VC TEST °°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
@property (nonatomic) int timeStep_ms;
// °°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
// MVV TEST °°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
@property (nonatomic) int timeStep_MVV_ms;
// °°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°

- (instancetype)initWithID:(id)reganam;


/*!
 *  @method addDelegate:
 *
 *  @param delegate         to receive the instance of the delagated object
 *
 *  @discussion             This method is invoked to subscribe as a delegate of SODevice
 *
 */
- (void)addDelegate:(id<SODeviceDelegate>)delegate;


/*!
 *  @method removeDelegate:
 *
 *  @param delegate         to receive the instance of the delagated object
 *
 *  @discussion             This method is invoked to unsubscribe as a delegate of SODevice
 *
 */
- (void)removeDelegate:(id<SODeviceDelegate>)delegate;


/*!
 *  @method startTest:
 *
 *
 *  @discussion             This method (invoked to start test) has been deprecated since when the device started supporting
 *                          more than one test type (FVC, Peak Flow ...) a new method must be called now,
 *                          startTestWithTestType:(SOTestType)
 *                          Nevertheless this method is still working to start an FVC test
 *
 *                           */
- (void)startTest DEPRECATED_MSG_ATTRIBUTE("use startTestWithTestType instead");


/*!
 *  @method startTestWithTestType:
 *  @param testType                                                 The test to start
 *
 *  @discussion                           This method is invoked to start the test specified by the parameter "testType"
 *
 */
- (void)startTestWithTestType:(SOTestType)testType;


/*!
 *  @method startTestWithTestType:endOfTestTimeout:
 *
 *  @param testType                                                 The test to start
 *  @param endOfTestTimeout                               The EOT timeout is the number of seconds after which the test is automatically ended by the spirometer
 *                                       (if the user was not been blowing at all since the test started).
                                         The valid range for the "timeout" is 15s - 120s.
 *                                       If a value < 15 is passed, the spirometer sets the timeout to 15s.
 *                                       If a value > 120 is passed, the spirometer sets the timeout to 120s
 *
 *  @discussion                           This method is invoked to start the test specified by the parameter "testType"
 *
 */
- (void)startTestWithTestType:(SOTestType)testType endOfTestTimeout:(Byte)timeoutInSeconds;


/*!
 *  @method startTestWithTestType:endOfTestTimeout:turbineType:
 *
 *  @param testType                                                 The test to start
 *  @param endOfTestTimeout                               The EOT timeout is the number of seconds after which the test is automatically ended by the spirometer
 *                                       (if the user was not been blowing at all since the test started).
                                         The valid range for the "timeout" is 15s - 120s.
 *                                       If a value < 15 is passed, the spirometer sets the timeout to 15s.
 *                                       If a value > 120 is passed, the spirometer sets the timeout to 120s
 *
 *
 *  @param turbineType                                             The turbine currently in use.  The turbine type passed to this method affects the measurament of the resuls

 *
 *  @discussion                           This method is invoked to start the test specified by the parameter "testType"
 */
- (void)startTestWithTestType:(SOTestType)testType endOfTestTimeout:(Byte)timeoutInSeconds turbineType:(SOTurbineType)turbine;



/*!
 *  @method startTestWithTestType:endOfTestTimeout:turbineType:AmbientTemperatureCelsius:
 *
 *  @param testType                                                 The test to start
 *  @param endOfTestTimeout                               The EOT timeout is the number of seconds after which the test is automatically ended by the spirometer
 *                                       (if the user was not been blowing at all since the test started).
                                         The valid range for the "timeout" is 15s - 120s.
 *                                       If a value < 15 is passed, the spirometer sets the timeout to 15s.
 *                                       If a value > 120 is passed, the spirometer sets the timeout to 120s
 *
 *
 *  @param turbineType                                            The turbine currently in use.  The turbine type passed to this method affects the measurament of the resuls
 *  @param AmbientTemperatureCelsius             The temperature of the ambient where the test is performed. This parameter is needed only for spirometry tests.
 *                                        In that case it is used by the medical device to perform the BTPS correction ( convert flow and volume measured at ambient conditions to the conditions within the lungs)
 *                                        The valid range for the CelsiusDegree  is 10 - 40.
 *                                        If a value < 10 is passed, the spirometer sets the temperature to default value of 25 celsius degree
 *                                        If a value > 40 is passed, the spirometer sets the temperature to default value of 25 celsius degree
 *
 *  @discussion                           This method is invoked to start the test specified by the parameter "testType"
 *
 */
- (void)startTestWithTestType:(SOTestType)testType endOfTestTimeout:(Byte)timeoutInSeconds turbineType:(SOTurbineType)turbine ambientTemperatureCelsius:(Byte) celsiusDegree;


/*!
 *  @method stopTest:
 *
 *
 *  @discussion             This method is invoked to stop the test
 *
 */
- (void)stopTest;


/**
 vers 2.1.0 firmwareUpdate
 Starts the device software update.
 
 When the software update has started, the SODevice object notifies its subscribers by calling the [soDevice:didReceiveSoftwareUpdateProgress:withStatus:error:] method.
 
 @param newSoftware The content of the software update binary file.
 */
- (void)startSoftwareUpdate:(NSData *_Nonnull)newSoftware;

/**
 Starts the device software update NORDIC or CSR.
 
 When the software update has started, the SODevice object notifies its subscribers by calling the [soDevice:didReceiveSoftwareUpdateProgress:withStatus:error:] method.
 
 @param newSoftware The content url of the software update binary file.
 */

- (void) startSoftwareUpdateWithUrl: (NSURL *_Nonnull) url;

// MARK: - FVC Plus Test

// vers 2.9.0
// enable spirobankSmart with compatible firmware to the FVC Plus test
- (void)enableFvcPlusWithPassCode:(NSString *)passCode completeBlock:(void(^)(BOOL isSuccess, NSError *error))boolCompletion;

// check if SpirobankSmart is enabled to the FVCPlus test type
- (void)isDeviceEnabledToFvcPlus:(void(^)(CheckState checkState))checkStateCompletion;

// disable spirobankSmart with compatible firmware to the FVC Plus test
- (void)DisableFvcPlusWithAdminKey:(NSString *)key completeBlock:(void(^)(BOOL isSuccess, NSError *error))boolCompletion;

-(void)fixFvcPlusActivation;

// MARK: - VC Test

// enable spirobankSmart with compatible firmware to the VC test
- (void)enableVcWithPassCode:(NSString *)passCode completeBlock:(void(^)(BOOL isSuccess, NSError *error))boolCompletion;

// check if SpirobankSmart is enabled to the VC test type
- (void)isDeviceEnabledToVc:(void(^)(CheckState checkState))checkStateCompletion;

// disable spirobankSmart with compatible firmware to the VC test
- (void)DisableVcWithAdminKey:(NSString *)key completeBlock:(void(^)(BOOL isSuccess, NSError *error))boolCompletion;
//- (void)DisableVcWithOutAdminKey:(void(^)(BOOL isSuccess, NSError *error))boolCompletion; To disable the VC immediately (only for the production)
// reset spirobankSmart to factory default (DISABLE ALL)
-(void) DisableAllTestTypeWIthAdminKey :(NSString *) key completeBlock:(void(^)(BOOL isSuccess, NSError *error)) boolCompletion;


// MARK: - ECG Test

- (void)getResultsForRunningEcg;

- (void)getResultsWithCurveForLastEcg;

- (void)getHighResolutionCurveForLastEcg;

- (void)getResultsWithoutCurveForLastEcg;

- (void)getResultsWithoutCurveForEcg:(int)ecgTestId;

- (void)getResultsWithoutCurveForAllEcg:(BOOL)onlyUntrasmittedResults;

- (void)getResultsWithCurveForEcg:(int)ecgTestId;

- (void)clearEcgDeviceMemory;

- (void)setEcgDeviceDateAndTime;

// MARK - HIGH RESOLUTION CURVE
/**
 send a request to the device to send the high resolution curve points os the LAST spirometry test (FVC, FVC PLUS or SVC) performed.
 the high resolution curve is received in the delegateMethod didUpdateHighResolutionCurveForLastSpirometryTest
 */

-(void) getHighResolutionCurveForLastSpirometryTest;
-(void) getHighResolutionCurveForLastSpirometryTestWithInspiration;

-(void) writeCalibration:(unsigned char*)nsPacket;

// Call this method to get the device type that has performed the test
// this is usefull to set the device type of the results object
- (PeripheralType)peripheralTypeFor:(SODevice *)device;

// Call this method when you want to check if the device is ready without for retrying 10 seconds
-(void)checkIfDeviceIsReady:(void(^_Nonnull)(BOOL isReady))completion;

@end
