// SPDX-License-Identifier: MIT

#import "VFlyDeviceImpl.h"

#ifndef DEVICE_CLIENT_FRAMEWORK
#import "VFlyTool.h"
#endif

#define VFlyDeviceDriverID @"com_mkrasnorutsky_driver_VirtualFly"

@interface VFlyDeviceImpl (PrivatePart)

+ (void)registerAtExitCallback;

+ (io_service_t)findService;
+ (io_connect_t)createNewConnection;

+ (BOOL)isDriverLoaded;
+ (BOOL)loadDriver;
+ (BOOL)unloadDriver;

@end

@implementation VFlyDeviceImpl

+ (BOOL)prepare
{
    if(![VFlyDeviceImpl loadDriver])
        return NO;

    [VFlyDeviceImpl registerAtExitCallback];
    return YES;
}

- (id)init
{
    self = [super init];
    if(self == nil)
        return nil;

    if(![VFlyDeviceImpl prepare])
    {
        [self release];
        return nil;
    }

    m_Connection = [VFlyDeviceImpl createNewConnection];
    if(m_Connection == IO_OBJECT_NULL)
    {
        [self release];
        return nil;
    }

    return self;
}

- (void)dealloc
{
    if(m_Connection != IO_OBJECT_NULL)
        IOServiceClose(m_Connection);

    [super dealloc];
}

- (BOOL)call:(VFlyDeviceMethodSelector)selector
{
    return [self call:selector data:nil];
}

- (BOOL)call:(VFlyDeviceMethodSelector)selector data:(NSData*)data
{
    return (IOConnectCallMethod(
                            m_Connection,
                            selector,
                            NULL,
                            0,
                            [data bytes],
                            [data length],
                            NULL,
                            NULL,
                            NULL,
                            NULL) == KERN_SUCCESS);
}

- (BOOL)call:(VFlyDeviceMethodSelector)selector string:(NSString*)string
{
    const char *data = [string UTF8String];
    size_t      size = strlen(data) + 1; // zero-terminator

    return [self call:selector data:[NSData dataWithBytes:data length:size]];
}

@end

@implementation VFlyDeviceImpl (Methods)

- (BOOL)setDeviceProductString:(NSString*)string
{
    return [self call:VFlyDeviceMethodSelectorSetDeviceProductString string:string];
}

- (BOOL)setDeviceSerialNumberString:(NSString*)string
{
    return [self call:VFlyDeviceMethodSelectorSetDeviceSerialNumberString string:string];
}

- (BOOL)setDeviceVendorID:(uint32_t)vendorID productID:(uint32_t)productID
{
    char data[sizeof(uint32_t) * 2] = { 0 };

    memcpy(data, &vendorID, sizeof(uint32_t));
    memcpy(data + sizeof(uint32_t), &productID, sizeof(uint32_t));

    return [self call:VFlyDeviceMethodSelectorSetDeviceVendorAndProductID
                 data:[NSData dataWithBytes:data length:sizeof(data)]];
}

- (BOOL)enable:(NSData*)HIDDescriptor
{
    return [self call:VFlyDeviceMethodSelectorEnable data:HIDDescriptor];
}

- (BOOL)disable
{
    return [self call:VFlyDeviceMethodSelectorDisable];
}

- (BOOL)updateState:(NSData*)HIDState
{
    return [self call:VFlyDeviceMethodSelectorUpdateState data:HIDState];
}

@end

@implementation VFlyDeviceImpl (PrivatePart)

static void onApplicationExit(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [VFlyDeviceImpl unloadDriver];
    [pool release];
}

+ (void)registerAtExitCallback
{
    static BOOL isRegistred = NO;

    if(isRegistred)
        return;

    atexit(onApplicationExit);
    isRegistred = YES;
}

+ (io_service_t)findService
{
    io_service_t	result = IO_OBJECT_NULL;
    io_iterator_t 	iterator;

    if(IOServiceGetMatchingServices(
                                 kIOMasterPortDefault,
                                 IOServiceMatching([VFlyDeviceDriverID UTF8String]),
                                &iterator) != KERN_SUCCESS)
    {
        return result;
    }
    
    result = IOIteratorNext(iterator);
    IOObjectRelease(iterator);
    return result;
}

+ (io_connect_t)createNewConnection
{
    io_connect_t result    = IO_OBJECT_NULL;
    io_service_t service   = [VFlyDeviceImpl findService];

    if(service == IO_OBJECT_NULL)
        return result;

    if(IOServiceOpen(service, mach_task_self(), 0, &result) != KERN_SUCCESS)
        result = IO_OBJECT_NULL;

    IOObjectRelease(service);
    return result;
}

+ (BOOL)isDriverLoaded
{
    io_service_t service = [VFlyDeviceImpl findService];
    BOOL         result  = (service != IO_OBJECT_NULL);

    IOObjectRelease(service);
    return result;
}

+ (BOOL)loadDriver
{
    if([self isDriverLoaded])
        return YES;

#ifndef DEVICE_CLIENT_FRAMEWORK
    return [VFlyTool loadDriver];
#else
    return NO;
#endif
}

+ (BOOL)unloadDriver
{
    if(![self isDriverLoaded])
        return YES;

#ifndef DEVICE_CLIENT_FRAMEWORK
    return [VFlyTool unloadDriver];
#else
    return NO;
#endif
}

@end
