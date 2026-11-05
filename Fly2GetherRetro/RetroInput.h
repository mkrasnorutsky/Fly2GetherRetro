#import <Foundation/Foundation.h>

@interface RetroInput : NSObject
@property(nonatomic, readonly) NSString *owner;
- (instancetype)initWithPort:(uint16_t)port error:(NSError **)error;
- (BOOL)pollAtTime:(NSTimeInterval)now error:(NSError **)error;
- (BOOL)hasActiveInputAtTime:(NSTimeInterval)now;
- (int16_t)axisAtIndex:(NSUInteger)index;
- (BOOL)buttonAtIndex:(NSUInteger)index;
- (NSData *)report;
+ (NSData *)safeReport;
+ (NSData *)descriptor;
@end
