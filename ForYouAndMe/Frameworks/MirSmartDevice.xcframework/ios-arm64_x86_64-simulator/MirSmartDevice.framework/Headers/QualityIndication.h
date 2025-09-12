//
//  QualityIndications.h
//  SpirobankSmartKit-Playground
//
//  Created by Marco Fiaschini on 24/01/2021.
//  Copyright © 2021 MIR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PublicDefs.h"

NS_ASSUME_NONNULL_BEGIN

@interface QualityIndication : NSObject

    @property (nonatomic) SOQualityMessage warning;
    @property (nonatomic) SOQualityInstruction instructionToPatient;

    - (id)initWithWarning:(SOQualityMessage)pWarning Instruction:(SOQualityInstruction)pInstruction;
@end

NS_ASSUME_NONNULL_END
