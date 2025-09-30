//
//  SOCardionicaDeviceStatus.h
//  SpirobankSmartKit-Playground
//
//  Created by Davide Balistreri on 27/04/21.
//  Copyright © 2021 MIR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SODeviceStatus.h"

NS_ASSUME_NONNULL_BEGIN

@interface SOCardionicaDeviceStatus : SODeviceStatus

// Bit 15 MODE -> 1 = App mode, 0 = Device mode
@property (nonatomic) BOOL isAppMode;

// Bit 10 TEST_ON -> 1 = Device in test
@property (nonatomic) BOOL isTestRunning;


// Bit 0 LIS_ERROR -> 1 = Sensor position fault
@property (nonatomic) BOOL isLisError;

// Bit 1 MEM_ERROR -> 1 = Memory fault
@property (nonatomic) BOOL isMemoryError;

// Bit 2 MAX_ERROR -> 1 = Sensor ECG fault
@property (nonatomic) BOOL isEcgError;

// Bit 14 ARCHIVE_ERROR -> 1 = Error in archive
@property (nonatomic) BOOL isArchiveError;


// Bit 3 LED_G_ERROR -> 1 = Green led fault
@property (nonatomic) BOOL isGreenLedError;

// Bit 4 LED_G_ERROR -> 1 = Red led fault
@property (nonatomic) BOOL isRedLedError;

// Bit 5 LED_G_ERROR -> 1 = Yellow led fault
@property (nonatomic) BOOL isYellowLedError;

// Bit 8 LED_O_ERROR -> 1 = Orange led fault
@property (nonatomic) BOOL isOrangeLedError;

// Bit 9 DATA_FAULT -> 1 = Invalid Data
@property (nonatomic) BOOL isInvalidData;


// Bit 13 BATTERY_LOW -> 1 = Battery low
@property (nonatomic) BOOL isBatteryLow;

// Bit 11 BATTERY_LOW_ARC -> 1 = Battery low to send archive
@property (nonatomic) BOOL isBatteryLowForArchive;

// Bit 12 ARC_NEW -> 1 = Archive empty
@property (nonatomic) BOOL isArchiveEmpty;

@end

NS_ASSUME_NONNULL_END
