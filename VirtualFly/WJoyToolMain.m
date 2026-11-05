// SPDX-License-Identifier: MIT

#import "VFlyToolInterface.h"

#import <sys/stat.h>

typedef enum
{
    WorkModeRepairRights,
    WorkModeLoadDriver,
    WorkModeUnloadDriver,
    WorkModeError
} WorkMode;

#define KEXTLoadCommand     "/sbin/kextload"
#define KEXTUnloadCommand   "/sbin/kextunload"
#define DESTINATION_PATH @"/Users/Shared"

static int copyToDestination(const char *path)
{
    NSString* p = [NSString stringWithUTF8String:path];
    NSString* newPath = [DESTINATION_PATH stringByAppendingPathComponent:[p lastPathComponent]];
    
    if (![[NSFileManager defaultManager]fileExistsAtPath:DESTINATION_PATH])
    {
        printf(">>>>> 4\n");
        
        if (![[NSFileManager defaultManager]createDirectoryAtPath:DESTINATION_PATH attributes:[NSDictionary dictionary]])
        {
            printf(">>>>> 5\n");
            
            return EXIT_FAILURE;
        }
    }
    
    printf(">>>>> 6\n");
    
    if (![[NSFileManager defaultManager]fileExistsAtPath:newPath])
    {
        printf(">>>>> 7\n");
        
        if (![[NSFileManager defaultManager]copyPath:p toPath:newPath handler:nil])
        {
            printf(">>>>> 8\n");
            
            return EXIT_FAILURE;
        }
    }
    
    printf(">>>>> 9\n");
    
    return EXIT_SUCCESS;
}

static int repairRights(const char *path)
{
    if (EXIT_SUCCESS != copyToDestination(path))
    {
        return EXIT_FAILURE;
    }
    
    NSString* p = [NSString stringWithUTF8String:path];
    NSString* newPath = [DESTINATION_PATH stringByAppendingPathComponent:[p lastPathComponent]];
    
    if(seteuid(0) != 0)
        return EXIT_FAILURE;

    if(chmod(newPath.UTF8String, 04755) != 0)
        return EXIT_FAILURE;

    if(chown(newPath.UTF8String, 0, 0) != 0)
        return EXIT_FAILURE;

    return EXIT_SUCCESS;
}

static int doCommandWithPath(const char *cmd, const char *path)
{
    NSString *command = [NSString stringWithFormat:@"%@ \"%@\"",
                                        [NSString stringWithUTF8String:cmd],
                                        [NSString stringWithUTF8String:path]];

    return system([command UTF8String]);
}

static BOOL repairDriverRihts(const char *path)
{
    if(doCommandWithPath("chmod -R 755", path) != EXIT_SUCCESS)
        return NO;

    if(doCommandWithPath("chown -R 0:0", path) != EXIT_SUCCESS)
        return NO;

    return YES;
}

static int loadDriver(const char *path)
{
    NSString* p = [NSString stringWithUTF8String:path];
    NSString* newPath = [DESTINATION_PATH stringByAppendingPathComponent:[p lastPathComponent]];
    
    printf(">>>>> 1\n");
    if(seteuid(0) != 0 || setuid(0) != 0)
    {
        printf(">>>>> 2\n");
        return EXIT_FAILURE;
    }
    
    printf(">>>>> 3\n");
    
    copyToDestination(path);

    if(!repairDriverRihts([newPath UTF8String]))
    {
        printf(">>>>> 10\n");
        
        return EXIT_FAILURE;
    }

    return doCommandWithPath(KEXTLoadCommand, [newPath UTF8String]);
}

static int unloadDriver(const char *path)
{
    if(seteuid(0) != 0 || setuid(0) != 0)
        return EXIT_FAILURE;

    NSString* p = [NSString stringWithUTF8String:path];
    NSString* newPath = [DESTINATION_PATH stringByAppendingPathComponent:[p lastPathComponent]];
    if(!repairDriverRihts([newPath UTF8String]))
        return EXIT_FAILURE;

    return doCommandWithPath(KEXTUnloadCommand, [newPath UTF8String]);
}

static WorkMode parseCommandLine(int argC, char *argV[])
{
    if(argC != 2 && argC != 3)
        return WorkModeError;

    if(strcmp([VFlyToolRepairRightsCommand UTF8String], argV[1]) == 0)
    {
        if(argC == 3)
            return WorkModeError;

        return WorkModeRepairRights;
    }

    if(strcmp([VFlyToolLoadDriverCommand UTF8String], argV[1]) == 0)
    {
        if(argC == 2)
            return WorkModeError;

        return WorkModeLoadDriver;
    }

    if(strcmp([VFlyToolUnloadDriverCommand UTF8String], argV[1]) == 0)
    {
        if(argC == 2)
            return WorkModeError;

        return WorkModeUnloadDriver;
    }

    return WorkModeError;
}

int main(int argC, char *argV[])
{
    printf(">>>>>>>>>>> %s %s %s\n", argV[0], argV[1], argV[2]);
    
    NSAutoreleasePool  *pool    = [[NSAutoreleasePool alloc] init];
    WorkMode            mode    = parseCommandLine(argC, argV);
    int                 result  = EXIT_FAILURE;
    
    switch(mode)
    {
        case WorkModeRepairRights:
            result = repairRights(argV[0]);
            break;

        case WorkModeLoadDriver:
            result = loadDriver(argV[2]);
            break;

        case WorkModeUnloadDriver:
            result = unloadDriver(argV[2]);
            break;

        default:
            break;
    }

    [pool release];
    return result;
}
