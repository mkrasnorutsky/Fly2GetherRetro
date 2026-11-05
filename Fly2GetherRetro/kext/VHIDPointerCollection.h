// SPDX-License-Identifier: MIT

#import <Foundation/Foundation.h>

@interface VHIDPointerCollection : NSObject
{
    @private
        NSUInteger       m_PointerCount;
        BOOL             m_IsRelative;
        NSData          *m_Descriptor;
        NSMutableData   *m_State;
}

+ (NSUInteger)maxPointerCount;

- (id)initWithPointerCount:(NSUInteger)pointerCount isRelative:(BOOL)isRelative;

- (BOOL)isRelative;
- (NSUInteger)pointerCount;

// [-1, +1] ;)
- (NSPoint)pointerPosition:(NSUInteger)pointerIndex;
- (void)setPointer:(NSUInteger)pointerIndex position:(NSPoint)position;
- (void)reset;

- (NSData*)descriptor;
- (NSData*)state;

@end
