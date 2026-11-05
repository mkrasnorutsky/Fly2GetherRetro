#import "VirtualHID.h"
#import <VirtualFlyClient/VFlyDevice.h>

@implementation VirtualHID {
    VFlyDevice *_device;
}

+ (BOOL)isDriverLoaded {
    return [VFlyDevice isDriverLoaded];
}

- (nullable instancetype)initWithDescriptor:(NSData *)descriptor {
    self = [super init];
    if (self) {
        _device = [[VFlyDevice alloc] initWithHIDDescriptor:descriptor
                                            productString:@"Fly2Gether Retro Joystick"];
        if (!_device) return nil;
    }
    return self;
}

- (BOOL)sendReport:(NSData *)report {
    return [_device updateHIDState:report];
}
@end
