// SPDX-License-Identifier: MIT

#import "VFlyTool.h"
#import "VFlyToolInterface.h"
#import "VFlyAdminToolRight.h"

#define VFlyDeviceDriverName @"vfly.kext"
#define DESTINATION_PATH @"/Users/Shared"

@interface VFlyTool (PrivatePart)

+ (NSBundle*)bundle;
+ (NSString*)toolPath;
+ (NSString*)driverPath;

+ (BOOL)repairToolRights;
+ (BOOL)doCommand:(NSString*)command argument:(NSString*)argument;
+ (BOOL)doLoadOrUnloadCommand:(NSString*)command;

@end

@implementation VFlyTool

+ (BOOL)loadDriver
{
    return [self doLoadOrUnloadCommand:VFlyToolLoadDriverCommand];
}

+ (BOOL)unloadDriver
{
	return YES;
	// return [self doLoadOrUnloadCommand:VFlyToolUnloadDriverCommand];
}

@end

@implementation VFlyTool (PrivatePart)

+ (NSBundle*)bundle
{
    return [NSBundle bundleForClass:[self class]];
}

+ (NSString*)toolPath
{
    return [[[self bundle] resourcePath]
                stringByAppendingPathComponent:VFlyToolName];
}

+ (NSString*)destinationToolPath
{
    return [DESTINATION_PATH stringByAppendingPathComponent:VFlyToolName];
}

+ (NSString*)driverPath
{
    return [[[self bundle] resourcePath]
                stringByAppendingPathComponent:VFlyDeviceDriverName];
}

+ (NSString*)destinationDriverPath
{
    return [DESTINATION_PATH
                stringByAppendingPathComponent:VFlyDeviceDriverName];
}

+ (BOOL)repairToolRights
{
    return [self runFromRoot:VFlyToolRepairRightsCommand arg:nil];
}

+ (BOOL)runFromRoot:(NSString*)arg1 arg:(NSString*)arg2
{
    VFlyAdminToolRight *rights = [[[VFlyAdminToolRight alloc] init] autorelease];

    if(![rights obtain])
        return NO;

    char *args[] =
    {
        (char*)[arg1 UTF8String],
        (char*)[arg2 UTF8String],
        0
    };

    FILE *toolOutput = NULL;
    if(AuthorizationExecuteWithPrivileges(
                                     [rights authRef],
                                     [[self toolPath] UTF8String],
                                     kAuthorizationFlagDefaults,
                                     args,
                                    &toolOutput) != noErr)
    {
        [rights discard];
        return NO;
    }

    char buffer[64];
    while(YES)
    {
        if(fread(buffer, sizeof(buffer), 1, toolOutput) <= 0)
            break;
    }

    fclose(toolOutput);
    [rights discard];
    return YES;
}

+ (BOOL)doCommand:(NSString*)command argument:(NSString*)argument
{
    NSTask *task = [[NSTask alloc] init];

    [task setLaunchPath:[self destinationToolPath]];
    [task setArguments:[NSArray arrayWithObjects:command, argument, nil]];
    [task launch];
    [task waitUntilExit];

    BOOL result = ([task terminationStatus] == EXIT_SUCCESS);

    [task release];
    return result;
}

+ (BOOL)doLoadOrUnloadCommand:(NSString*)command
{
    if ([self runFromRoot:command arg:[self driverPath]])
        return YES;

    if(![self repairToolRights])
        return NO;

    return [self runFromRoot:command arg:[self driverPath]];
}

- (id)init
{
    [[super init] release];
    return nil;
}

@end
