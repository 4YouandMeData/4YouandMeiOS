//
//  SODeviceStatus.h
//  SpirobankSmartKit-Playground
//
//  Created by Davide Balistreri on 27/04/21.
//  Copyright © 2021 MIR. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SODeviceStatus : NSObject

// Bit 6 LAST_COMMAND -> 1 = Last command executed successfully, 0 = Command NOT recognised
@property (nonatomic) BOOL isLastCommandValid;

// Bit 7 READY -> 1 = Ready for new command, 0 = Busy
@property (nonatomic) BOOL isDeviceReady;

@end

NS_ASSUME_NONNULL_END
