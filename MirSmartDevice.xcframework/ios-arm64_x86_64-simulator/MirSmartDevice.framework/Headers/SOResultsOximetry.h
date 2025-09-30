//
//  SOResultsOximetry.h
//  SpirobankSmartKit-Playground
//
//  Created by Marco Fiaschini on 12/07/2018.
//  Copyright © 2018 MIR. All rights reserved.
//



#import <Foundation/Foundation.h>

// SMART ONE OX: vers 2.7 - 1.4 - 1.0 OXIMETRY TEST -----------------------
@interface SOResultsOximetry : NSObject

@property (nonatomic) float spo2Mean; //Average SpO2 value (%)
@property (nonatomic) int spo2Max; //Maximum SpO2 value (%)
@property (nonatomic) int spo2Min; //Minimum SpO2 value (%)
@property (nonatomic) float heartRateMean; //Average heart rate frequency (beats per minute)
@property (nonatomic) int heartRateMax; //Maximum heart rate (beats per minute)
@property (nonatomic) int heartRateMin; //Minimum heart rate (beats per minute)

@property (nonatomic) int analysisTimeHours;
@property (nonatomic) int analysisTimeMin;
@property (nonatomic) int analysisTimeSec;
@property (nonatomic) int recordingTimeHours;
@property (nonatomic) int recordingTimeMin;
@property (nonatomic) int recordingTimeSec;
@property (nonatomic) int spO2Baseline;
@property (nonatomic) int bpmBaseline;
@property (nonatomic) int t90hours;
@property (nonatomic) int t90min;
@property (nonatomic) int t90sec;
@property (nonatomic) int t89hours;
@property (nonatomic) int t89min;
@property (nonatomic) int t89sec;
@property (nonatomic) int eventSpO2Less89;
@property (nonatomic) int tachycardiaEvents;
@property (nonatomic) int bradycardiaEvents;
@property (nonatomic) int t88hours;
@property (nonatomic) int t88min;
@property (nonatomic) int t88sec;
@property (nonatomic) int t87hours;
@property (nonatomic) int t87min;
@property (nonatomic) int t87sec;
@property (nonatomic) int t5hours;
@property (nonatomic) int t5min;
@property (nonatomic) int t5sec;
@property (nonatomic) int t40hours;
@property (nonatomic) int t40min;
@property (nonatomic) int t40sec;
@property (nonatomic) int t120hours;
@property (nonatomic) int t120min;
@property (nonatomic) int t120sec;
@property (nonatomic) int deltaIndex12sec;
@property (nonatomic) int atrialFibrillation;

@property (nonatomic, strong) NSArray* heartRatePoints; // heart rate points (beats per minute)
@property (nonatomic, strong) NSArray*  spo2Points; //SpO2 points (%)

@end
// --------------------------------------------------------------------------
