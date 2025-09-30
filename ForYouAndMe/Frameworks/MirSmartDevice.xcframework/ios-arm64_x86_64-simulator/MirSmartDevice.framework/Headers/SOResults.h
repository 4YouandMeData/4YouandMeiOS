//
//  SOResults.h
//  SmartOneKit-Playground
//
//  Created by Marco Fiaschini & Tereshkin Sergey on 02/10/15.
//  Copyright © 2015 MIR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PublicDefs.h"

@interface SOResults : NSObject


@property (nonatomic) int pef_cLs; //Peak Flow in Centileters per seconds
@property (nonatomic) int fev1_cL; //Forced Expiratory Volume after 1 second in Centiliters
@property (nonatomic) int fvc_cL; //Forced Expiratory Capacity in Centiliters
@property (nonatomic) float fev1_fvc_pcnt; //Fev1% in percentage
@property (nonatomic) int qualityCode; //code of the qulity (acceptability) message  to display
// vers 1.3 ----------
//@property (nonatomic) int eVol_mL; //Extrapolated volume in Milliliters
//@property (nonatomic) int pefTime_sec; // time (in seconds) to reach the Peak Flow value
@property (nonatomic) int fev6_cL; //forced Expiratory Volume after 6 second in Centiliters
@property (nonatomic) int fef2575_cLs; // Maximum mid-expiratory flow
// vers 2.0 -----------
@property (nonatomic) int eVol_mL; //Extrapolated volume in Milliliters
@property (nonatomic) int pefTime_sec DEPRECATED_MSG_ATTRIBUTE("Use pefTime_ms instead."); // time (in milliseconds) to reach the Peak Flow value
@property (nonatomic) SOTestType resultTestType; // type of test which retrieved this result
@property (nonatomic) int pefTime_ms; // time (in milliseconds) to reach the Peak Flow value
// vers 1.9 ------------

//*****ATS2019 ************************************
@property (nonatomic) AtsStandard deviceAtsStandard;
//***************************************************

//***************************************************
@property (nonatomic) PeripheralType deviceType;
//***************************************************

@end
