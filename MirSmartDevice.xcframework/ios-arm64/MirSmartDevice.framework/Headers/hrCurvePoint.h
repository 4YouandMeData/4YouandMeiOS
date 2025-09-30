//
//  hrCurvePoint.h
//  SpirobankSmartKit
//
//  Created by Marco Fiaschini on 27/10/22.
//  Copyright © 2022 MIR. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface hrCurvePoint : NSObject

@property float volume_L;
@property float flow_Ls;
@property float time_s;


-(instancetype)initWithVolume_L:(float) volume_L
                     flow_Ls: (float) flow_Ls
                     time_s:(float) time_s;


@end

NS_ASSUME_NONNULL_END
