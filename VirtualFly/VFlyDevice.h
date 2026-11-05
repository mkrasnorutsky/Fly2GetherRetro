// SPDX-License-Identifier: MIT

#import <Foundation/Foundation.h>

@class VFlyDeviceImpl;

#ifndef FOUNDATION_EXTERN
#define FOUNDATION_EXTERN extern
#endif

FOUNDATION_EXTERN NSString *VFlyDeviceVendorIDKey;           // NSNumber (NSUInteger as uint32_t)
FOUNDATION_EXTERN NSString *VFlyDeviceProductIDKey;          // NSNumber (NSUInteger as uint32_t)
FOUNDATION_EXTERN NSString *VFlyDeviceProductStringKey;      // NSString
FOUNDATION_EXTERN NSString *VFlyDeviceSerialNumberStringKey; // NSString

@interface VFlyDevice : NSObject
{
    @private
        VFlyDeviceImpl *m_Impl;
        NSDictionary   *m_Properties;
}

+ (BOOL)prepare;

- (id)initWithHIDDescriptor:(NSData*)HIDDescriptor;
- (id)initWithHIDDescriptor:(NSData*)HIDDescriptor productString:(NSString*)productString;
- (id)initWithHIDDescriptor:(NSData*)HIDDescriptor properties:(NSDictionary*)properties;

- (NSDictionary*)properties;

- (BOOL)updateHIDState:(NSData*)HIDState;

+ (BOOL)isDriverLoaded;

@end
