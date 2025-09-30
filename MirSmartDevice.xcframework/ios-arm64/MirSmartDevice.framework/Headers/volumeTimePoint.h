//
//  volumeTimePoint.h
//  SpirobankSmartKit-Playground
//
//  Created by Sviluppo1 on 30/05/2020.
//  Copyright © 2020 MIR. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface volumeTimePoint : NSObject

@property float volume_L;
@property float time_s;

-(instancetype)initWithVolume_L:(float) volume_L
                     time_s:(float) time_s;

@end

NS_ASSUME_NONNULL_END
