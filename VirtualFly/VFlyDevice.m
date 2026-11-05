// SPDX-License-Identifier: MIT

#import "VFlyDevice.h"

#import "VFlyDeviceImpl.h"

NSString *VFlyDeviceVendorIDKey             = @"VFlyDeviceVendorIDKey";
NSString *VFlyDeviceProductIDKey            = @"VFlyDeviceProductIDKey";
NSString *VFlyDeviceProductStringKey        = @"VFlyDeviceProductStringKey";
NSString *VFlyDeviceSerialNumberStringKey   = @"VFlyDeviceSerialNumberStringKey";

@implementation VFlyDevice

+ (BOOL)prepare
{
    return [VFlyDeviceImpl prepare];
}

- (id)init
{
    [[super init] release];
    return nil;
}

- (id)initWithHIDDescriptor:(NSData*)HIDDescriptor
{
    return [self initWithHIDDescriptor:HIDDescriptor properties:nil];
}

- (id)initWithHIDDescriptor:(NSData*)HIDDescriptor productString:(NSString*)productString
{
    NSDictionary *properties = [NSDictionary
                                        dictionaryWithObject:productString
                                                      forKey:VFlyDeviceProductStringKey];

    return [self initWithHIDDescriptor:HIDDescriptor properties:properties];
}

- (id)initWithHIDDescriptor:(NSData*)HIDDescriptor properties:(NSDictionary*)properties
{
    self = [super init];
    if(self == nil)
        return nil;

    uint32_t     vendorID           = [[properties objectForKey:VFlyDeviceVendorIDKey] unsignedIntegerValue];
    uint32_t     productID          = [[properties objectForKey:VFlyDeviceProductIDKey] unsignedIntegerValue];
    NSString    *productString      = [properties objectForKey:VFlyDeviceProductStringKey];
    NSString    *serialNumberString = [properties objectForKey:VFlyDeviceSerialNumberStringKey];

    m_Impl = [[VFlyDeviceImpl alloc] init];
    if(m_Impl == nil)
    {
        [self release];
        return nil;
    }

    if(productString != nil)
        [m_Impl setDeviceProductString:productString];

    if(serialNumberString != nil)
        [m_Impl setDeviceSerialNumberString:serialNumberString];

    if(vendorID != 0 || productID != 0)
        [m_Impl setDeviceVendorID:vendorID productID:productID];

    if(![m_Impl enable:HIDDescriptor])
    {
        [self release];
        return nil;
    }

    m_Properties = [properties copy];
    return self;
}

- (void)dealloc
{
    [m_Properties release];
    [m_Impl release];
    [super dealloc];
}

- (NSDictionary*)properties
{
    return [[m_Properties retain] autorelease];
}

- (BOOL)updateHIDState:(NSData*)HIDState
{
    return [m_Impl updateState:HIDState];
}

+ (BOOL)isDriverLoaded
{
    return VFlyDeviceImpl.isDriverLoaded;
}

@end
