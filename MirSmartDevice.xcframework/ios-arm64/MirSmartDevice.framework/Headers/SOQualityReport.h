//
//  SOQualityReport.h
//  SpirobankSmartKit-Playground
//
//  Created by Marco Fiaschini on 24/01/2021.
//  Copyright © 2021 MIR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PublicDefs.h"
#import "QualityIndication.h"

NS_ASSUME_NONNULL_BEGIN

@interface SOQualityReport : NSObject
    @property (nonatomic) AtsStandard standardUsedByCurrentDevice;
    @property (nonatomic) AcceptabilityStatus trialAcceptability;
    @property (nonatomic) AcceptabilityStatus fvcAcceptability;
    @property (nonatomic) AcceptabilityStatus fev1Acceptability;
    @property (nonatomic) AcceptabilityStatus fev075Acceptability;
    @property (nonatomic, strong) NSMutableArray<QualityIndication*> * QualityIndications;
@end

NS_ASSUME_NONNULL_END
