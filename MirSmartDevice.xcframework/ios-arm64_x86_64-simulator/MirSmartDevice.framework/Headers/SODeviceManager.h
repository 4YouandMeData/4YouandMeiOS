//
//  SOCommManager.h
//  SmartOneKit-Playground
//
//  Created by Marco Fiaschini & Tereshkin Sergey on 01/10/15.
//  Copyright © 2015 MIR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SODeviceInfo.h"
#import "SODevice.h"

@class SODeviceManager;


@protocol SODeviceManagerDelegate <NSObject>

//---------------------------------------
// ATTENTION: remember that any delegate method of SODeviceManager (as any other SmartOneKit class) will be called simultaneously for each active viewcontroller that is a delegate of it (and, of course, has implemented that method). This because of the multiple delegation pattern used
//---------------------------------------

@optional

/*!
 *  @method deviceManager:didDiscoverDeviceWithInfo:
 *
 *  @param deviceManager    The deviceManager providing this information.
 *  @param deviceInfo       The info about the device that has been discovered.
 *
 *  @discussion             This method is invoked each time the discovery process finds a SMART ONE device.
 *
 */
- (void)deviceManager:(SODeviceManager *)deviceManager didDiscoverDeviceWithInfo:(SODeviceInfo *)deviceInfo;


/*!
 *  @method deviceManager:didConnectDevice:
 *
 *  @param deviceManager    The deviceManager providing this information.
 *  @param device           The device that has connected.
 *
 *  @discussion             This method is invoked when a connection initiated by {@link connect:} has succeeded..
 *
 */
- (void)deviceManager:(SODeviceManager *)deviceManager didConnectDevice:(SODevice *)device;


/*!
 *  @method deviceManager:didDisconnectDevice:
 *
 *  @param deviceManager    The deviceManager providing this information.
 *  @param device           The device that has disconnected.
 *
 *  @discussion             This method is invoked upon the disconnection of a device that was connected by {@link connect:}.
 *
 */
- (void)deviceManager:(SODeviceManager *)deviceManager didDisconnectDevice:(SODevice *)device;


/*!
 *  @method deviceManager:didFailToConnectDeviceWithInfo:
 *
 *  @param deviceManager    The deviceManager providing this information.
 *  @param deviceInfo       The device that has disconnected.
 *
 *  @discussion             This method is invoked upon the disconnection of a device that was connected by {@link connect:}
 *                          This method is invoked when the disconnection was not initiated by {@link disconnect}
 *
 *
 */
- (void)deviceManager:(SODeviceManager *)deviceManager didFailToConnectDeviceWithInfo:(SODeviceInfo *)deviceInfo;


/*!
 *  @method deviceManager:didUpdateBluetoothWithState:
 *
 *  @param deviceManager    The deviceManager providing this information.
 *  @param state            The state of the Bluetooth.
 *
 *  @discussion     Invoked whenever the Bluetooth state has been updated. Commands should only be issued when the state is
 *                  <code>CBCentralManagerStatePoweredOn</code>. A state below <code>CBCentralManagerStatePoweredOn</code>
 *                  implies that scanning has stopped and any connected peripherals have been disconnected. If the state moves below
 *                  <code>CBCentralManagerStatePoweredOff</code>, all <code>SODevice</code> objects obtained from this central
 *                  manager become invalid and must be retrieved or discovered again.
 *
 *  @see            state
 *
 */
- (void)deviceManager:(SODeviceManager *)deviceManager didUpdateBluetoothWithState:(CBCentralManagerState)state;


/*!
 *  @method deviceManager:didReceiveWriteRequestError:forCharacteristic:
 *
 *  @param deviceManager    The deviceManager providing this information.
 *  @param error                       The error received after a request to write a value on a characteristic
 *  @param characteristic    The characteristic that was going to be written
 *
 *  @discussion     Invoked whenever a request to write a characteristic is denied because of an error.
 *                  This delegate method is called only if the method @link writeValue: forCharacteristic: type:
 *                  was called with the parameter type = CBCharacteristicWriteWithResponse
 *
 */
- (void)deviceManager:(SODeviceManager *)deviceManager didReceiveWriteRequestError:(NSError *)error forCharacteristic:(CBCharacteristic *)characteristic;

@end


@interface SODeviceManager : NSObject

@property (nonatomic, strong) NSNumber *connectionTimeoutInSeconds;
@property (nonatomic, strong) SODevice *connectedDevice;


/*!
 *  @method sharedManager
 *
 *  @discussion             This method is invoked to get a shared instance of SODeviceManager to be used
 *                          from anywhere and during the whole app lifecycle
 *
 */
+(instancetype)sharedManager;


/*!
 *  @method initBluetooth
 *
 *  @discussion             This method is invoked to initialised the Bluetooth. It must be called once during the app lifecycle,
 *                          when the bluetooth state is CBCentralManagerStateUnknown
 *
 */
-(void)initBluetooth;


/*!
*  @method bluetoothState
*
*  @discussion             This method is invoked to get the Bluetooth state. if state is CBCentralManagerStateUnknown the 
*                          InitBluetooth method can be called
*
*/
-(CBCentralManagerState) bluetoothState;


/*!
 *  @method lastConnectedDeviceID
 *
 *  @discussion             This method is invoked to get the deviceInfo of the last device that has been connected
 *                          It returns nil if the bluetooth has not been initialised OR if there is no previous device connected
 *
 */
-(SODeviceInfo *)lastConnectedDeviceInfo;


/*!
 *  @method addDelegate:
 *
 *  @param delegate         to receive the instance of the delagated object
 *
 *  @discussion             This method is invoked to subscribe as a delegate of SODeviceManager
 *
 */
-(void)addDelegate:(id<SODeviceManagerDelegate>) delegate;


/*!
 *  @method removeDelegate:
 *
 *  @param delegate         to receive the instance of the delagated object
 *
 *  @discussion             This method is invoked to unsubscribe as a delegate of SODeviceManager
 *
 */
-(void)removeDelegate:(id<SODeviceManagerDelegate>) delegate;


/*!
 *  @method startDiscovery
 *
 *
 *  @discussion         Starts scanning for SMART ONE device that are advertising the supported services.
 *
 *  @see                deviceManager:didDiscoverDeviceWithInfo:deviceInfo:
 *
 */
-(void)startDiscovery;



/*!
 *  @method stopDiscovery:
 *
 *  @discussion         Stops scanning for SMART ONE devices.
 *
 */
-(void)stopDiscovery;


/*!
 *  @method isDevice:compatibleWithBootIds:
 *
 *  @param deviceId     The ID of the device to check. Device ID can be found in deviceInfo object passed by deviceManager:didDiscoverDeviceWithInfo:
 *                      or it can be get from method lastConnectedDeviceID
 *  @param bootIds      The list of compatible boot ids (ie. SO, SM, SX, SE).
 *
 *  @discussion         Returns YES if the given device ID is compatible with the specified boot ids.
 */
-(BOOL)isDevice:(NSString *)deviceId compatibleWithBootIds:(NSArray<NSString *> *)bootIds;


/*!
 *  @method connect:
 *
 *  @param deviceId     The ID of the device to be connected to. Device ID can be found in deviceInfo object passed by deviceManager:didDiscoverDeviceWithInfo:
 *                      or it can be get from method lastConnectedDeviceID
 *
 *  @discussion         Initiates a connection to the device with Id passed by deviceId parameter.
 *
 *  @see                deviceManager:didConnectDevice:
 *  @see                deviceManager:didFailToConnectDeviceWithInfo:
 *
 */
-(void)connect:(NSString *)deviceId;


/*!
 *  @method disconnect
 *
 *
 *  @discussion         Cancels an active or pending connection to the connecting or connected device. Note that this is non-blocking, and any SODevice
 *                      commands that are still pending may or may not complete.
 *
 *  @see                deviceManager:didDisconnectDevice:
 *
 */
-(void)disconnect;

@property (nonatomic, strong) NSMutableDictionary *discoveredPeripherals;

-(void) setLogEnabled:(BOOL)enabled;
-(BOOL) isLogEnabled;

- (void)initEcg;

@end
