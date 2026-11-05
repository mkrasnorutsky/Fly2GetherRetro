// SPDX-License-Identifier: MIT

#import <Foundation/Foundation.h>
#import <Security/Security.h>

@interface VFlyAdminToolRight : NSObject
{
    @private
        AuthorizationRef m_AuthRef;
}

- (BOOL)isObtained;
- (BOOL)obtain;
- (void)discard;

- (AuthorizationRef)authRef;

@end
