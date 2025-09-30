//
//  PublicDefs.h
//  SpirobankSmartKit-Playground
//
//  Created by Marco Fiaschini on 29/03/17.
//  Copyright © 2017 MIR. All rights reserved.
//

#ifndef PublicDefs_h
#define PublicDefs_h

typedef enum : NSInteger {
    NoTest = -1,
    TestFVC = 0,
    TestPeakFlowFev1 = 1,
    // SMART ONE OX: vers 2.7 - 1.4 - 1.0 OXIMETRY TEST -----------------------
    TestOximetry = 2,
    TestFTmonitor = 3,
    // 2.9 - 1.5 - 1.3 OXIMETRY TEST -----------------------
    TestFVCPlus = 4,
    //-------------------------------------------------------------------------
    //VC TEST °°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
    TestVC = 5,
    //°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
    // ***** Cardionica *****
    TestECG = 6,
    //MVV TEST °°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
    TestMVV = 7
    //°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
} SOTestType;

/**
 Defines the status codes for firmware update progress notifications
 */
typedef NS_ENUM(NSInteger, UpdateStatus) {
    UpdateIdle,
    UpdateInProgress,
    UpdateError,
    UpdateComplete
};

typedef enum : NSUInteger {
    Reusable = 0,
    Disposable = 1
} SOTurbineType;

// SMART ONE OX: vers 2.8 - 1.5 - 2.0 OXIMETRY TEST -----------------------

typedef enum : NSUInteger {
    NoWarning = 0,
    DefectiveSensor = 1,
    BatteryLow = 2,
    NoFinger = 3,
    PulseSearching = 4,
    PulseSearchingTooLong = 5,
    LossOfPulse= 6,
    LowSignalQuality= 7,
    LowPerfusion= 8,
    ArtifactDetected= 9
    
} SOOximetryWarnings;

typedef NS_ENUM(NSInteger, ResponseType) {
    NoResponse,
    ResponseSuccess,
    ResponseFailure
};

//*****ATS2019 ************************************
typedef NS_ENUM(NSInteger, EndOfForcedExpirationIndicator) {
    PlateauReached,
    ExpiratoryTimeReached
};
//***************************************************

typedef enum : NSUInteger {
    SOEthnicGroupCaucasian = 18,
    SOEthnicGroupAfricanAmerican = 19,
    SOEthnicGroupNorthEastAsian = 20,
    SOEthnicGroupSouthEastAsian = 21,
    SOEthnicGroupOther = 22,
    SOEthnicGroupJapanese = 23,
    SOEthnicGroupNotDefined = 18
} SOEthnicGroup;

typedef enum : NSUInteger {
    SOGenderMale = 0,
    SOGenderFemale = 1
} SOGender;

typedef enum : NSInteger {
    SOQualityMessageNotAvailable = -1,
    SOQualityMessageDontEsitate = 0,
    SOQualityMessageBlowOutFaster = 1,
    SOQualityMessageBlowOutLonger = 2,
    SOQualityMessageAbruptEnd = 3,
    SOQualityMessageGoodBlow = 4,
    SOQualityMessageDontStartTooEarly =  5,
    SOQualityMessageAvoidCoughing = 6,
    //SOQualityMessageGoodSession = 7 vers 2.0 (out of context)
//*****ATS2019 ************************************
    SOQualityMessageHesitationAtMaxVolume = 8,
    SOQualityMessageSlowFilling = 9,
    SOQualityMessageLowFinalInspiration = 10 ,
    SOQualityMessageIncompleteInspirationPriorToFvc = 11,
    SOQualityMessageLowForcedExpirationVolume = 12
//***************************************************
} SOQualityMessage;


//*****ATS2019 ************************************
typedef enum : NSUInteger {
    
        None = 0,
        RelaxButKeepPushing = 1,
        DrinkWaterBeforeNextBlow = 2,
        KeepGoingUntilCompletelyEmpty = 3,
        BlastOutImmediatelyWhenCompletelyFull = 4,
        BlastOutWhenCompletelyFull = 5,
        BreathInFasterBeforeBlastingOut = 6,
        BreathInBackToTheTopAfterEmptyingYourLungs = 7,
        FillLungsCompletelyBeforeBlastingOut = 8 ,
        TakeDeepestBreathPossibleAndKeepGoingUntilempty = 9
    
} SOQualityInstruction;

typedef enum : NSInteger {
        UNKNONWN = -1,
        ATS_2015 = 0,
        ATS_2019 = 1,
    
} AtsStandard;


typedef enum : NSUInteger {
    
        NotApplicable = 0,
        Acceptable = 1,
        NotAcceptable = 2,
        NotAcceptableAndUsable = 3,
        NotAcceptableAndNotUsable = 4
    
} AcceptabilityStatus;
//***************************************************


typedef enum : NSInteger {
    UNKNOWN = -1,
    ENABLED = 0,
    DISABLED = 1,
    REQUEST_TIMED_OUT = 2,
    FIRMWARE_UPDATE_NEEDED = 3,
    TEST_NOT_SUPPORTED = 4
    
} CheckState;

typedef enum : NSUInteger {
    SUCCEEDED = 0,
    FAILED = 1,
    NOT_NECESSARY = 2
    
} FixFvcPlusResult;

typedef enum {
    PeripheralTypeSpirobankSmart,
    PeripheralTypeSpirobankOxi,
    PeripheralTypeSpirobankNoxi,
    PeripheralTypeSmartone,
    PeripheralTypeSmartoneOxi,
    PeripheralTypeSmartoneNoxi,
    PeripheralTypeDigitalSpiro,
    PeripheralTypeSpirobank_II_Smart,
    PeripheralTypeUndefined
} PeripheralType;

// ***** vers 3.0.7 ************************************
typedef NS_OPTIONS(NSUInteger, SOParserCallbackMode) {
    SOParserCallbackModeRaw,
    SOParserCallbackModeManaged,
};
typedef NS_OPTIONS(NSUInteger, SOParserRawPacketType) {
    SOParserRawPacketType_Cod_ON                    = 0x00,
    SOParserRawPacketType_Cod_FVC                   = 0x08,
    SOParserRawPacketType_Cod_VC                    = 0x02,
    SOParserRawPacketType_Cod_CALIBRATION           = 0x86,
    SOParserRawPacketType_Cod_OXY                   = 0x20,
    SOParserRawPacketType_Cod_TX_CALIBRATION        = 0x85,
    SOParserRawPacketType_Cod_FVC_LAST_RT           = 0xA2,
    SOParserRawPacketType_Cod_VC_LAST_RT            = 0xF2,
    SOParserRawPacketType_Cod_OXY_RESULTS           = 0xD0,
    SOParserRawPacketType_Cod_TX_SETTING_DATE       = 0xD6,
    SOParserRawPacketType_Cod_ERASE                 = 0xD3,
    SOParserRawPacketType_Cod_INFO_FVC_LAST_RT_1    = 0xD1,
    SOParserRawPacketType_Cod_FVC_LAST_RT_2_P1      = 0x31,
    SOParserRawPacketType_Cod_FVC_LAST_RT_2_P2      = 0x32,
    SOParserRawPacketType_Cod_FVC_LAST_RT_2_P3      = 0x33,
    SOParserRawPacketType_Cod_FVC_LAST_RT_2_P4      = 0x34,
    SOParserRawPacketType_Cod_FVC_LAST_RT_2_P5      = 0x35,
    SOParserRawPacketType_Cod_FVC_LAST_RT_2_P6      = 0x36,
    SOParserRawPacketType_Cod_SPIRO_LAST_RT_VT      = 0xD3,
    SOParserRawPacketType_Cod_VC_LAST_RT_P1         = 0x91,
    SOParserRawPacketType_Cod_VC_LAST_RT_P2         = 0x92,
    SOParserRawPacketType_Cod_VC_LAST_RT_P3         = 0x93,
    SOParserRawPacketType_Cod_OXY_RESULTS_BASE      = 0x51,
    SOParserRawPacketType_Cod_OXY_RESULTS_BASE2     = 0x52,
    SOParserRawPacketType_Cod_OXY_RESULTS_CURVE     = 0xF3,
    SOParserRawPacketType_Cod_MVV                   = 0x04,
    SOParserRawPacketType_Cod_MVV_LAST_RT           = 0xF3,
    SOParserRawPacketType_Cod_MVV_LAST_RT_P1        = 0x94,
    SOParserRawPacketType_Cod_CURVE_10MS            = 0xD8,
    SOParserRawPacketType_Cod_CURVE_10MS_FLOWS      = 0xD9,
};
typedef NS_OPTIONS(NSUInteger, SOParserRawPacketIdentifier) {
    SOParserRawPacketIdentifier_Cod_TEMPERATURE         = 0x50,
    SOParserRawPacketIdentifier_Cod_BATTERY             = 0x51,
    SOParserRawPacketIdentifier_Cod_STEP_VOL            = 0x30,
    SOParserRawPacketIdentifier_Cod_STEP_T              = 0x40,
    SOParserRawPacketIdentifier_Cod_FLOW                = 0x10,
    SOParserRawPacketIdentifier_Cod_VOL                 = 0x20,
    SOParserRawPacketIdentifier_Cod_6SEC                = 0x06,
    SOParserRawPacketIdentifier_Cod_BTPS                = 0x87,
    SOParserRawPacketIdentifier_Cod_ATTO_INS            = 0xA3,
    SOParserRawPacketIdentifier_Cod_ATTO_EXP            = 0xA1,
    SOParserRawPacketIdentifier_Cod_SpO2                = 0xED,
    SOParserRawPacketIdentifier_Cod_BPM                 = 0xEE,
    SOParserRawPacketIdentifier_Cod_PLETISMO            = 0xFC,
    SOParserRawPacketIdentifier_Cod_SIGNAL              = 0xFB,
    SOParserRawPacketIdentifier_Cod_SENSOR_UNPLUGGED    = 0xF9,
    SOParserRawPacketIdentifier_Cod_INSERT_FINGER       = 0xFA,
};
// ******************************************************


#endif /* PublicDefs_h */
