//
//  SOResultsFvcExtended.h
//  SpirobankSmartKit-Playground
//
//  Created by Sviluppo1 on 27/05/2020.
//  Copyright © 2020 MIR. All rights reserved.
//

#import <Foundation/Foundation.h>
//#import "SOResults.h"
#import "flowVolmePoint.h"
#import "volumeTimePoint.h"
#import "PublicDefs.h"


@interface SOResultsFvcPlus : NSObject


@property (nonatomic) float qualityCode; //inherited
@property (nonatomic) float fvc_L;  //inherited
@property (nonatomic) float fev1_L;  //inherited
@property (nonatomic) float pef_Ls;  //inherited
@property (nonatomic) float fef2575_Ls;  //inherited
@property (nonatomic) float fev6_L;  //inherited
@property (nonatomic) float eVol_mL;  //inherited
@property (nonatomic) float pefTime_ms;  //inherited
@property (nonatomic) float fev1_fvc_pcnt;  //inherited



@property (nonatomic) int stepVol_mL; //mL
@property (nonatomic) float ampliFlow;
//@property (nonatomic) int curveStartPoint;
@property (nonatomic) float fef75_Ls;
@property (nonatomic) float fet_cs;
@property (nonatomic) float fef25_Ls;
@property (nonatomic) float fef50_Ls;
@property (nonatomic) float fivc_Ls DEPRECATED_MSG_ATTRIBUTE("Use fivc_L instead.");
@property (nonatomic) float fiv1_Ls DEPRECATED_MSG_ATTRIBUTE("Use fiv1_L instead.");
//MEASURE UNITS FIXED -------------
@property (nonatomic) float fivc_L;
@property (nonatomic) float fiv1_L;
//---------------------------------
@property (nonatomic) float pif_Ls;
@property (nonatomic) float fev3_L;
@property (nonatomic) float fev05_L;
@property (nonatomic) float fev075_L;
@property (nonatomic) float fev2_L;
@property (nonatomic) float fef7585_Ls;
@property (nonatomic) float fif25_Ls;
@property (nonatomic) float fif50_Ls;
@property (nonatomic) float fif75_Ls;

//calculated values

@property (nonatomic) float fev1_fev6_perc;
@property (nonatomic) float fev6_fvc_perc;
@property (nonatomic) float fiv1_fivc_perc;
@property (nonatomic) float fev3_fvc_perc;
@property (nonatomic) float fev05_fvc_perc;
@property (nonatomic) float fev075_fvc_perc;
@property (nonatomic) float fev2_fvc_perc;


@property (nonatomic) int numOfFvcCurvePoints;
@property (nonatomic) int numOfFvcCurveExpPoints;
@property (nonatomic) int numOfFvcCurveInsPoints;
@property (nonatomic, strong) NSMutableArray * FVC_Curve;
@property (nonatomic, strong) NSMutableArray * VT_Curve;

//*****ATS2019 ************************************
@property (nonatomic) AtsStandard deviceAtsStandard;
//***************************************************

// from Spirobank II BLE Protocol 001
@property (nonatomic) float r50_perc;
@property (nonatomic) float ei_perc;
@property (nonatomic) float mvvCalc_L;

//*****ATS2019forAZ_STEP1***************************
@property (nonatomic) float hesitationTime_s;
//***************************************************

//***************************************************
@property (nonatomic) PeripheralType deviceType;
//***************************************************

//***************************************************
@property (nonatomic) NSInteger temperature;
//***************************************************

//***************************************************
@property (nonatomic) double btps;
//***************************************************

@end

