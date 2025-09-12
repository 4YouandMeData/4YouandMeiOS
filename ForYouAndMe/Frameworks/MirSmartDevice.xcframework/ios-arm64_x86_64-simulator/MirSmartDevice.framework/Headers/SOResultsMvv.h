//
//  SOResultsMvv.h
//  SpirobankSmartKit-Playground
//
//  Created by Marco Fiaschini on 16/04/23.
//  Copyright © 2023 MIR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "volumeTimePoint.h"
#import "PublicDefs.h"

NS_ASSUME_NONNULL_BEGIN

@interface SOResultsMvv : NSObject
@property (nonatomic) float mvv_Lm;
@property (nonatomic, strong) NSMutableArray * MVV_Curve;
//
@property (nonatomic) AtsStandard deviceAtsStandard;

//***************************************************
@property (nonatomic) PeripheralType deviceType;
//***************************************************

@end

NS_ASSUME_NONNULL_END
