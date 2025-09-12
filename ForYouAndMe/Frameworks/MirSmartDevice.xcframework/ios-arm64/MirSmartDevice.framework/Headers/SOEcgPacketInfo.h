//
//  SOEcgPacketInfo.h
//  SpirobankSmartKit-Playground
//
//  Created by Davide Balistreri on 12/05/2021.
//  Copyright © 2021 MIR. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SOEcgPacketInfo : NSObject

// Number of packet
@property (nonatomic) int numberOfPacket;

// BPM (see PACKET INFO if BPM >255)
@property (nonatomic) int bpmValue;

// QUALITY_SIGNAL -> Bit0=1 means low quality signal for bluetooth trasmission
@property (nonatomic) BOOL isErrorCommunication;

// QUALITY_SIGNAL -> Bit1=0 means low quality signal
@property (nonatomic) BOOL isLowQualitySignal;

// IMPEDENCE -> Bit2=1 lead-off detected
@property (nonatomic) BOOL isLeadOffDetected;

// MOVEMENT -> Bit3=1 movement detected
@property (nonatomic) BOOL isMovementDetected;

// POSITION -> Bit4=1 supine position detected
@property (nonatomic) BOOL isSupinePositionDetected;

// SATURATED_ECG -> Bit5=1 ECG out of range
@property (nonatomic) BOOL isEcgOutOfRange;

// masc_HW_FAULT -> Bit6=0 means hardware error during test
@property (nonatomic) BOOL isHWFault;

// masc_TRASMITTED -> Bit7=0 means record già trasmesso
@property (nonatomic) BOOL isAlreadyTransmitted;

@end

NS_ASSUME_NONNULL_END
