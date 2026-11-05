#import "DriverInstaller.h"
#import <sys/sysctl.h>

@implementation DriverInstaller
+ (BOOL)supportsArchitecture {
#if defined(__x86_64__)
    int translated = 0;
    size_t size = sizeof(translated);
    sysctlbyname("sysctl.proc_translated", &translated, &size, NULL, 0);
    return translated == 0;
#else
    return NO;
#endif
}

+ (void)loadWithCompletion:(void (^)(NSString *))completion {
    NSURL *driver = [NSBundle.mainBundle URLForResource:@"vfly" withExtension:@"kext"];
    if (!driver) {
        completion(@"This build is missing the High Sierra VirtualFly driver.");
        return;
    }
    NSString *command =
        @"set -eu\n"
        "stage=$(/usr/bin/mktemp -d /Users/Shared/.Fly2GetherRetro.XXXXXX)\n"
        "trap '/bin/rm -rf \"$stage\"' EXIT\n"
        "/usr/bin/ditto --norsrc \"$1\" \"$stage/vfly.kext\"\n"
        "/usr/sbin/chown -Rh root:wheel \"$stage/vfly.kext\"\n"
        "/bin/chmod -R u+rwX,go+rX,go-w \"$stage/vfly.kext\"\n"
        "/sbin/kextload \"$stage/vfly.kext\"";
    NSString *script =
        @"on run argv\n"
        "    set installer to quoted form of item 1 of argv\n"
        "    set driverPath to quoted form of item 2 of argv\n"
        "    do shell script (\"/bin/sh -c \" & installer & \" Fly2GetherRetro \" & driverPath) with administrator privileges without altering line endings\n"
        "end run";
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        NSTask *task = [[NSTask alloc] init];
        NSPipe *output = [NSPipe pipe];
        task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/osascript"];
        task.arguments = @[@"-e", script, command, driver.path];
        task.standardOutput = output;
        task.standardError = output;

        NSString *message;
        NSError *error;
        if (![task launchAndReturnError:&error]) {
            message = [@"Driver loading could not start. " stringByAppendingString:error.localizedDescription];
        } else {
            NSData *data = [output.fileHandleForReading readDataToEndOfFile];
            [task waitUntilExit];
            NSString *details = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (task.terminationStatus == 0) {
                message = @"VirtualFly loaded.";
            } else if ([details containsString:@"(-128)"]) {
                message = @"Driver loading canceled.";
            } else {
                message = [NSString stringWithFormat:@"macOS could not load VirtualFly. %@",
                           [details stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] ?: @""];
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{ completion(message); });
    });
}
@end
