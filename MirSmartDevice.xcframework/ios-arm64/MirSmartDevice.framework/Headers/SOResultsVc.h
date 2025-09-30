//
//  SOResultsVc.h
//  SpirobankSmartKit-Playground
//
//  Created by Sviluppo1 on 13/03/2021.
//  Copyright © 2021 MIR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "volumeTimePoint.h"
#import "PublicDefs.h"

NS_ASSUME_NONNULL_BEGIN

@interface SOResultsVc : NSObject

@property (nonatomic) float evc_L;
@property (nonatomic) float ivc_L;
@property (nonatomic) float ic_L;
@property (nonatomic) float slowExpInsTime_s;
@property (nonatomic, strong) NSMutableArray * VT_Curve;
//*****ATS2019 ************************************
@property (nonatomic) AtsStandard deviceAtsStandard;
//***************************************************
@property (nonatomic) float qualityCode;

// vers 3.0.7 - Parameters from Spirobank II Smart
@property (nonatomic) int irv;
@property (nonatomic) int erv;
@property (nonatomic) int tv;
@property (nonatomic) int mv;
@property (nonatomic) int rr;
@property (nonatomic) int ti;
@property (nonatomic) int te;
@property (nonatomic) int tvTi;
@property (nonatomic) int tiTtot;
// from Spirobank II BLE Protocol 001
@property (nonatomic) int sit;
@property (nonatomic) int set;

//***************************************************
@property (nonatomic) PeripheralType deviceType;
//***************************************************

@end

NS_ASSUME_NONNULL_END
