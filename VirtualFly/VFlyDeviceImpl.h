// SPDX-License-Identifier: MIT

#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>

typedef enum
{
    VFlyDeviceMethodSelectorEnable                      = 0,
    VFlyDeviceMethodSelectorDisable                     = 1,
    VFlyDeviceMethodSelectorUpdateState                 = 2,
    VFlyDeviceMethodSelectorSetDeviceProductString      = 3,
    VFlyDeviceMethodSelectorSetDeviceSerialNumberString = 4,
    VFlyDeviceMethodSelectorSetDeviceVendorAndProductID = 5
} VFlyDeviceMethodSelector;

@interface VFlyDeviceImpl : NSObject
{
    @private
        io_connect_t m_Connection;
}

+ (BOOL)prepare;

- (BOOL)call:(VFlyDeviceMethodSelector)selector;
- (BOOL)call:(VFlyDeviceMethodSelector)selector data:(NSData*)data;
- (BOOL)call:(VFlyDeviceMethodSelector)selector string:(NSString*)string;

@end

@interface VFlyDeviceImpl (Methods)

- (BOOL)setDeviceProductString:(NSString*)string;
- (BOOL)setDeviceSerialNumberString:(NSString*)string;
- (BOOL)setDeviceVendorID:(uint32_t)vendorID productID:(uint32_t)productID;

- (BOOL)enable:(NSData*)HIDDescriptor;
- (BOOL)disable;

- (BOOL)updateState:(NSData*)HIDState;

+ (BOOL)isDriverLoaded;

@end
