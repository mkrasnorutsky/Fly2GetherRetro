// SPDX-License-Identifier: MIT

#import <Foundation/Foundation.h>

@interface VHIDButtonCollection : NSObject
{
    @private
        NSUInteger       m_ButtonCount;
        NSData          *m_Descriptor;
        NSMutableData   *m_State;
}

+ (NSUInteger)maxButtonCount;

- (id)initWithButtonCount:(NSUInteger)buttonCount;

- (NSUInteger)buttonCount;

- (BOOL)isButtonPressed:(NSUInteger)buttonIndex;
- (void)setButton:(NSUInteger)buttonIndex pressed:(BOOL)pressed;
- (void)reset;

- (NSData*)descriptor;
- (NSData*)state;

@end
