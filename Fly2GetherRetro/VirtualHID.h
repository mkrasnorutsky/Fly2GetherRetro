#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface VirtualHID : NSObject
+ (BOOL)isDriverLoaded;
- (nullable instancetype)initWithDescriptor:(NSData *)descriptor;
- (BOOL)sendReport:(NSData *)report;
@end

NS_ASSUME_NONNULL_END
