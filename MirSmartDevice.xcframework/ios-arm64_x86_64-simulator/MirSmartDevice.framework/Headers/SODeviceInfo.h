//
//  SODeviceInfo.h
//  SmartOneKit-Playground
//
//  Created by Marco Fiaschini & Tereshkin Sergey on 02/10/15.
//  Copyright © 2015 MIR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "PublicDefs.h"

@interface SODeviceInfo : NSObject

@property (nonatomic, strong) NSString *deviceID; //Unique identifier of the device
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *protocol; //protocol supported by the device
@property (nonatomic, strong) NSString *serialNumber;
@property (nonatomic, strong) NSNumber *RSSI; //signal strenght in Db of the device
@property (nonatomic) NSInteger *CurrentTestType; //ver 2.0.0 the test requested to current instance of device
@property (nonatomic, strong) NSString *advertisementData;//ver 2.0.1 new deviceInfo property: AdvertisementData (sent by device during discovery)
@property (nonatomic, strong) NSString *nameCached;//ver 2.4.0

// vers 2.5.2 - 1.2.2 for iSpirometry ***************
@property (nonatomic, strong) NSString *shortName;
//***************************************************

//vers 2.7.2
@property (nonatomic, strong) NSString *bootID; //first 2 letters (ie. SO, SM, SX, SE, SC)

//*****ATS2019 ************************************
@property (nonatomic) AtsStandard AtsStandardSupported;
//***************************************************


//VC TEST °°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°
@property (nonatomic) CheckState FvcPlusEnableStatus;
@property (nonatomic) CheckState VcEnableSatus;

//°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°°



@end
