#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#import "DriverInstaller.h"
#import "RetroInput.h"
#import "VirtualHID.h"

@interface DashboardDocument : NSView
@end
@implementation DashboardDocument
- (BOOL)isFlipped { return YES; }
@end

static NSColor *Color(uint32_t rgb) {
    return [NSColor colorWithSRGBRed:((rgb >> 16) & 255) / 255.0
                               green:((rgb >> 8) & 255) / 255.0
                                blue:(rgb & 255) / 255.0 alpha:1];
}

static NSStackView *Stack(NSUserInterfaceLayoutOrientation orientation, CGFloat spacing) {
    NSStackView *stack = [[NSStackView alloc] init];
    stack.orientation = orientation;
    stack.spacing = spacing;
    stack.alignment = orientation == NSUserInterfaceLayoutOrientationVertical
        ? NSLayoutAttributeLeading : NSLayoutAttributeCenterY;
    return stack;
}

static void AddFullWidth(NSStackView *stack, NSView *view, CGFloat inset) {
    [stack addArrangedSubview:view];
    [view.widthAnchor constraintEqualToAnchor:stack.widthAnchor constant:-2 * inset].active = YES;
}

static void SetBackground(NSView *view, NSColor *color) {
    view.wantsLayer = YES;
    view.layer.cornerRadius = 10;
    view.layer.backgroundColor = color.CGColor;
}

static NSTextField *Label(NSString *text, CGFloat size, BOOL bold, NSColor *color) {
    NSTextField *field = [NSTextField labelWithString:text];
    field.font = [NSFont systemFontOfSize:size weight:bold ? NSFontWeightSemibold : NSFontWeightRegular];
    field.textColor = color ?: NSColor.whiteColor;
    return field;
}

static NSImageView *Artwork(NSString *name, CGFloat size) {
    NSImageView *view = [[NSImageView alloc] init];
    NSURL *url = [NSBundle.mainBundle URLForResource:name withExtension:@"png"];
    if (url) view.image = [[NSImage alloc] initWithContentsOfURL:url];
    view.imageScaling = NSImageScaleProportionallyUpOrDown;
    [view.widthAnchor constraintEqualToConstant:size].active = YES;
    [view.heightAnchor constraintEqualToConstant:size].active = YES;
    return view;
}

@interface Dashboard : NSObject <NSApplicationDelegate>
@end

@implementation Dashboard {
    NSWindow *_window;
    NSColor *_navy, *_card, *_muted, *_cyan, *_yellow, *_green;
    NSPopUpButton *_simulator;
    NSView *_driverDot, *_phoneDot;
    NSTextField *_driverTitle, *_driverHint, *_phoneTitle, *_phoneHint;
    NSButton *_retry, *_installDriverButton;
    BOOL _installingDriver;
    NSMutableArray<NSLevelIndicator *> *_meters;
    NSMutableArray<NSTextField *> *_values, *_buttons;
    RetroInput *_receiver;
    VirtualHID *_joystick;
    NSData *_lastReport;
    NSTimer *_timer;
    NSString *_networkError, *_driverError;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    _navy = Color(0x0b1220);
    _card = Color(0x142136);
    _muted = Color(0x94a3b8);
    _cyan = Color(0x38bdf8);
    _yellow = Color(0xfbbf24);
    _green = Color(0x34d399);
    _simulator = [[NSPopUpButton alloc] init];
    _driverDot = [[NSView alloc] init];
    _phoneDot = [[NSView alloc] init];
    _driverTitle = [NSTextField labelWithString:@""];
    _phoneTitle = [NSTextField labelWithString:@""];
    _driverHint = [NSTextField wrappingLabelWithString:@""];
    _phoneHint = [NSTextField wrappingLabelWithString:@""];
    _meters = [NSMutableArray array];
    _values = [NSMutableArray array];
    _buttons = [NSMutableArray array];

    _window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 650, 800)
                                        styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                                  NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                                          backing:NSBackingStoreBuffered defer:NO];
    _window.releasedWhenClosed = NO;
    _window.title = @"Fly2GetherRetro";
    _window.minSize = NSMakeSize(500, 500);
    _window.backgroundColor = _navy;
    _window.appearance = [NSAppearance appearanceNamed:@"NSAppearanceNameDarkAqua"]
        ?: [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
    _window.contentView = [self makeContent];
    [_window center];
    [_window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];

    NSMenu *appMenu = [[NSMenu alloc] init];
    [appMenu addItemWithTitle:@"Quit Fly2GetherRetro" action:@selector(terminate:) keyEquivalent:@"q"];
    NSMenuItem *menuItem = [[NSMenuItem alloc] init];
    menuItem.submenu = appMenu;
    NSApp.mainMenu = [[NSMenu alloc] init];
    [NSApp.mainMenu addItem:menuItem];

    [self connect];
    [self modeChanged];
    __weak Dashboard *weakSelf = self;
    _timer = [NSTimer timerWithTimeInterval:0.025 repeats:YES block:^(NSTimer *timer) {
        [weakSelf tick];
    }];
    [NSRunLoop.mainRunLoop addTimer:_timer forMode:NSRunLoopCommonModes];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender { return YES; }

- (void)applicationWillTerminate:(NSNotification *)notification {
    [_timer invalidate];
    [self stopJoystick];
}

- (BOOL)monitorOnly { return _simulator.indexOfSelectedItem == 0; }

- (void)connect {
    NSError *error;
    _receiver = [[RetroInput alloc] initWithPort:4211 error:&error];
    _networkError = _receiver ? nil : error.localizedDescription;
}

- (void)modeChanged {
    [NSUserDefaults.standardUserDefaults setBool:self.monitorOnly forKey:@"monitorXPlane"];
    if (self.monitorOnly) [self stopJoystick];
    else [self prepareJoystick];
    [self updateDriverStatus];
}

- (void)retrySetup {
    if (!_receiver) [self connect];
    if (!self.monitorOnly) [self prepareJoystick];
    [self updateDriverStatus];
}

- (void)installDriver {
    if (self.monitorOnly || _installingDriver || !DriverInstaller.supportsArchitecture) return;
    _installingDriver = YES;
    _driverError = @"Waiting for administrator authorization…";
    [self updateDriverStatus];
    __weak Dashboard *weakSelf = self;
    [DriverInstaller loadWithCompletion:^(NSString *message) {
        [weakSelf finishLoadingDriver:message];
    }];
}

- (void)finishLoadingDriver:(NSString *)message {
    _installingDriver = NO;
    if (!self.monitorOnly && VirtualHID.isDriverLoaded) {
        [self prepareJoystick];
    } else if (!_joystick) {
        _driverError = message;
    }
    [self updateDriverStatus];
}

- (void)openAppStore {
    [NSWorkspace.sharedWorkspace openURL:
        [NSURL URLWithString:@"https://apps.apple.com/us/app/fly2gether-flight-controller/id6758529685"]];
}

- (void)prepareJoystick {
    if (_joystick) return;
    VirtualHID *device = [[VirtualHID alloc] initWithDescriptor:RetroInput.descriptor];
    if ([device sendReport:RetroInput.safeReport]) {
        _joystick = device;
        _driverError = nil;
    } else {
        _driverError = VirtualHID.isDriverLoaded
            ? @"The VirtualFly driver is loaded, but the joystick could not be created."
            : @"Install and load VirtualFly for this session. The app copies the driver to a temporary location and removes the copy after the load attempt. If VirtualFly is already loaded, connect to it directly.";
    }
}

- (void)stopJoystick {
    [_joystick sendReport:RetroInput.safeReport];
    _joystick = nil;
    _lastReport = nil;
}

- (void)updateDriverStatus {
    BOOL monitorOnly = self.monitorOnly;
    BOOL supported = DriverInstaller.supportsArchitecture;
    _driverDot.layer.backgroundColor = (monitorOnly || _joystick ? _green : _yellow).CGColor;
    _driverTitle.stringValue = monitorOnly ? @"X-Plane direct connection"
        : _joystick ? @"Virtual joystick ready" : @"Set up your virtual joystick";
    _driverHint.stringValue = monitorOnly
        ? @"Open X-Plane and Fly2Gether on the same Wi-Fi network. Your iPhone sends controls directly to X-Plane. This window shows recent phone input."
        : _driverError ?: @"Open your simulator and assign the Fly2Gether Retro Joystick axes and buttons in its control settings.";
    if (!monitorOnly && !_joystick && !supported) {
        _driverHint.stringValue = @"The VirtualFly driver is built for Intel Macs.";
    }
    _installDriverButton.hidden = monitorOnly || _joystick || !supported;
    _installDriverButton.enabled = !_installingDriver;
    _retry.enabled = !_installingDriver;
    _retry.hidden = !_networkError && (monitorOnly || _joystick);
    _retry.title = _networkError ? @"Retry setup" : @"Connect to Loaded Driver";
}

- (void)tick {
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    NSError *error;
    if (_receiver && ![_receiver pollAtTime:now error:&error]) {
        _receiver = nil;
        _networkError = error.localizedDescription;
        [self updateDriverStatus];
    }
    if (_joystick) {
        NSData *report = _receiver ? _receiver.report : RetroInput.safeReport;
        if (![_lastReport isEqualToData:report]) {
            if ([_joystick sendReport:report]) {
                _lastReport = report;
            } else {
                [self stopJoystick];
                _driverError = @"The virtual joystick stopped accepting input. Check that the VirtualFly driver is loaded.";
                [self updateDriverStatus];
            }
        }
    }

    BOOL active = [_receiver hasActiveInputAtTime:now];
    _phoneDot.layer.backgroundColor = (active ? _green : _yellow).CGColor;
    _phoneTitle.stringValue = active ? @"Receiving iPhone controls" : @"Waiting for your iPhone";
    _phoneHint.stringValue = _networkError ?: (active
        ? [NSString stringWithFormat:@"Input from %@", _receiver.owner]
        : @"Connect your iPhone and this Mac to the same Wi-Fi network. Open Fly2Gether and tap I have controls if you see Pilot Monitoring.");
    for (NSUInteger i = 0; i < _values.count; i++) {
        int16_t axis = [_receiver axisAtIndex:i];
        _values[i].stringValue = active ? [NSString stringWithFormat:@"%d", axis] : @"–";
        _meters[i].doubleValue = active ? axis : 0;
    }
    for (NSUInteger i = 0; i < _buttons.count; i++) {
        BOOL pressed = [_receiver buttonAtIndex:i];
        _buttons[i].textColor = pressed ? _green : _muted;
        _buttons[i].layer.backgroundColor = (pressed ? _card : _navy).CGColor;
    }
}

- (NSStackView *)statusCardWithDot:(NSView *)dot title:(NSTextField *)title hint:(NSTextField *)hint {
    NSStackView *container = Stack(NSUserInterfaceLayoutOrientationVertical, 8);
    SetBackground(container, _card);
    container.edgeInsets = NSEdgeInsetsMake(14, 16, 14, 16);
    NSStackView *heading = Stack(NSUserInterfaceLayoutOrientationHorizontal, 10);
    dot.wantsLayer = YES;
    dot.layer.cornerRadius = 4;
    [dot.widthAnchor constraintEqualToConstant:8].active = YES;
    [dot.heightAnchor constraintEqualToConstant:8].active = YES;
    [heading addArrangedSubview:dot];
    title.font = [NSFont systemFontOfSize:16 weight:NSFontWeightSemibold];
    title.textColor = NSColor.whiteColor;
    [heading addArrangedSubview:title];
    [container addArrangedSubview:heading];
    hint.textColor = _muted;
    AddFullWidth(container, hint, 16);
    return container;
}

- (NSView *)makeContent {
    NSScrollView *scroll = [[NSScrollView alloc] init];
    scroll.drawsBackground = NO;
    scroll.hasVerticalScroller = YES;
    NSView *document = [[DashboardDocument alloc] init];
    scroll.documentView = document;
    document.translatesAutoresizingMaskIntoConstraints = NO;
    NSStackView *body = Stack(NSUserInterfaceLayoutOrientationVertical, 14);
    [document addSubview:body];
    body.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
        [document.widthAnchor constraintEqualToAnchor:scroll.contentView.widthAnchor],
        [body.leadingAnchor constraintEqualToAnchor:document.leadingAnchor constant:24],
        [body.trailingAnchor constraintEqualToAnchor:document.trailingAnchor constant:-24],
        [body.topAnchor constraintEqualToAnchor:document.topAnchor constant:24],
        [body.bottomAnchor constraintEqualToAnchor:document.bottomAnchor constant:-24]
    ]];

    NSStackView *branding = Stack(NSUserInterfaceLayoutOrientationHorizontal, 14);
    [branding addArrangedSubview:Artwork(@"AppIcon", 52)];
    NSStackView *title = Stack(NSUserInterfaceLayoutOrientationVertical, 3);
    [title addArrangedSubview:Label(@"Fly2GetherRetro", 30, YES, nil)];
    [title addArrangedSubview:Label(@"Your iPhone. Your flight.", 13, NO, _muted)];
    [title addArrangedSubview:Label(@"Designed for macOS High Sierra 10.13", 13, NO, _muted)];
    [branding addArrangedSubview:title];
    AddFullWidth(body, branding, 0);

    [_simulator addItemsWithTitles:@[@"X-Plane 11 or 12", @"Other simulators"]];
    [_simulator selectItemAtIndex:[NSUserDefaults.standardUserDefaults boolForKey:@"monitorXPlane"] ? 0 : 1];
    _simulator.target = self;
    _simulator.action = @selector(modeChanged);
    NSStackView *selector = Stack(NSUserInterfaceLayoutOrientationHorizontal, 16);
    [selector addArrangedSubview:Label(@"Your simulator", 13, YES, nil)];
    [selector addArrangedSubview:_simulator];
    [body addArrangedSubview:selector];

    NSStackView *driver = [self statusCardWithDot:_driverDot title:_driverTitle hint:_driverHint];
    _installDriverButton = [NSButton buttonWithTitle:@"Install and Load VirtualFly" target:self action:@selector(installDriver)];
    _retry = [NSButton buttonWithTitle:@"Connect to Loaded Driver" target:self action:@selector(retrySetup)];
    [driver addArrangedSubview:_installDriverButton];
    [driver addArrangedSubview:_retry];
    AddFullWidth(body, driver, 0);

    NSStackView *phone = [self statusCardWithDot:_phoneDot title:_phoneTitle hint:_phoneHint];
    NSStackView *download = Stack(NSUserInterfaceLayoutOrientationHorizontal, 16);
    download.alignment = NSLayoutAttributeTop;
    NSImageView *qr = Artwork(@"AppStoreQr", 120);
    [qr setAccessibilityLabel:@"QR code to download Fly2Gether for iPhone"];
    [download addArrangedSubview:qr];
    NSStackView *instructions = Stack(NSUserInterfaceLayoutOrientationVertical, 7);
    [instructions addArrangedSubview:Label(@"Scan with your iPhone camera", 13, YES, nil)];
    [instructions addArrangedSubview:Label(@"Install Fly2Gether Flight Controller.", 13, NO, _muted)];
    [instructions addArrangedSubview:[NSButton buttonWithTitle:@"View on the App Store" target:self action:@selector(openAppStore)]];
    [download addArrangedSubview:instructions];
    AddFullWidth(phone, download, 16);
    AddFullWidth(body, phone, 0);

    [body addArrangedSubview:Label(@"IPHONE INPUT", 11, YES, _muted)];
    for (NSString *name in @[@"Roll", @"Pitch", @"Rudder", @"Throttle", @"Elevator trim", @"Propeller", @"Mixture"]) {
        NSStackView *axis = Stack(NSUserInterfaceLayoutOrientationVertical, 4);
        axis.edgeInsets = NSEdgeInsetsMake(7, 14, 7, 14);
        SetBackground(axis, _card);
        NSStackView *row = Stack(NSUserInterfaceLayoutOrientationHorizontal, 8);
        NSTextField *value = Label(@"–", 15, NO, _cyan);
        [row addArrangedSubview:Label(name, 13, YES, nil)];
        [row addArrangedSubview:[[NSView alloc] init]];
        [row addArrangedSubview:value];
        [_values addObject:value];
        AddFullWidth(axis, row, 14);
        NSLevelIndicator *meter = [[NSLevelIndicator alloc] init];
        meter.levelIndicatorStyle = NSLevelIndicatorStyleContinuousCapacity;
        meter.minValue = INT16_MIN;
        meter.maxValue = INT16_MAX;
        meter.fillColor = _cyan;
        [meter setAccessibilityLabel:name];
        [_meters addObject:meter];
        AddFullWidth(axis, meter, 14);
        AddFullWidth(body, axis, 0);
    }

    NSStackView *row = Stack(NSUserInterfaceLayoutOrientationHorizontal, 8);
    for (NSString *name in @[@"Gear", @"Brakes", @"Flaps −", @"Flaps +"]) {
        NSTextField *button = Label(name, 13, NO, _muted);
        SetBackground(button, _card);
        [row addArrangedSubview:button];
        [_buttons addObject:button];
    }
    [body addArrangedSubview:row];
    [body addArrangedSubview:Label(@"Keep Fly2Gether open on your iPhone while flying.", 13, NO, _muted)];
    return scroll;
}
@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *app = NSApplication.sharedApplication;
        Dashboard *dashboard = [[Dashboard alloc] init];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        app.delegate = dashboard;
        [app run];
        app.delegate = nil;
    }
    return 0;
}
