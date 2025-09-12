//
//  flowVolmePoint.h
//  SpirobankSmartKit-Playground
//
//  Created by Sviluppo1 on 30/05/2020.
//  Copyright © 2020 MIR. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface flowVolmePoint : NSObject

@property float flow_L;
@property float volume_L;

-(instancetype)initWithFlow_L:(float) flow_L
                     volume_L:(float) volume_L;

@end

NS_ASSUME_NONNULL_END
