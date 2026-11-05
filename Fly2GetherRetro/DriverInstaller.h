#import <Foundation/Foundation.h>

@interface DriverInstaller : NSObject
+ (BOOL)supportsArchitecture;
+ (void)loadWithCompletion:(void (^)(NSString *message))completion;
@end
