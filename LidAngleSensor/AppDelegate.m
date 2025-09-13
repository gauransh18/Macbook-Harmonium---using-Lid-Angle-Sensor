//
//  AppDelegate.m
//  LidAngleSensor
//
//  Created by Sam on 2025-09-06.
//

#import "AppDelegate.h"
#import "LidAngleSensor.h"
#import "HarmoniumAudioEngine.h"
#import "NSLabel.h"
#import "PianoKeyboardView.h"
#import "BellowsMeterView.h"
#import "BellowsDotsView.h"
#import "HandDrawnCloseButton.h"
#import <QuartzCore/QuartzCore.h>

@interface AppDelegate ()
@property (strong, nonatomic) LidAngleSensor *lidSensor;
@property (strong, nonatomic) HarmoniumAudioEngine *harmoniumAudioEngine;
// Removed info labels per request
@property (strong, nonatomic) NSButton *audioToggleButton;
@property (strong, nonatomic) NSTimer *updateTimer;
@property (strong, nonatomic) id keyDownMonitor;
@property (strong, nonatomic) id keyUpMonitor;
@property (strong, nonatomic) PianoKeyboardView *keyboardView;
@property (strong, nonatomic) NSView *stopsColumn;
@property (strong, nonatomic) BellowsMeterView *meterView; // kept but unused
@property (strong, nonatomic) BellowsDotsView *dotsView;
@property (strong, nonatomic) NSButton *muteButton;
@property (assign, nonatomic) double fallbackPhase;
@property (assign, nonatomic) CFTimeInterval lastDisplayUpdate;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    [self createWindow];
    [self initializeLidSensor];
    [self initializeAudioEngines];
    [self installKeyboardMonitorsIfNeeded];
    [self startUpdatingDisplay];
    // Auto-start audio so there is sound immediately
    [self.harmoniumAudioEngine startEngine];
    [self.audioToggleButton setTitle:@"Stop Audio"];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [self.updateTimer invalidate];
    [self.lidSensor stopLidAngleUpdates];
    [self.harmoniumAudioEngine stopEngine];
    if (self.keyDownMonitor) { [NSEvent removeMonitor:self.keyDownMonitor]; self.keyDownMonitor = nil; }
    if (self.keyUpMonitor) { [NSEvent removeMonitor:self.keyUpMonitor]; self.keyUpMonitor = nil; }
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

- (void)createWindow {
    // Harmonium sketch-like UI
    NSRect windowFrame = NSMakeRect(100, 100, 820, 520);
    self.window = [[NSWindow alloc] initWithContentRect:windowFrame
                                              styleMask:NSWindowStyleMaskTitled |
                                                       NSWindowStyleMaskClosable |
                                                       NSWindowStyleMaskMiniaturizable
                                                backing:NSBackingStoreBuffered
                                                  defer:NO];
    [self.window setTitle:@"Laptop Harmonium"];
    [self.window makeKeyAndOrderFront:nil];
    [self.window center];
    self.window.backgroundColor = [NSColor whiteColor];

    NSView *contentView = [[NSView alloc] initWithFrame:windowFrame];
    [self.window setContentView:contentView];

    // Left: horizontal keyboard across bottom area
    self.keyboardView = [[PianoKeyboardView alloc] initWithFrame:NSZeroRect];
    self.keyboardView.translatesAutoresizingMaskIntoConstraints = NO;
    __weak typeof(self) weakSelf = self;
    self.keyboardView.noteEvent = ^(int midi, BOOL down) {
        if (down) [weakSelf.harmoniumAudioEngine noteOn:midi];
        else [weakSelf.harmoniumAudioEngine noteOff:midi];
        // Update highlight state
        NSMutableSet *set = [weakSelf.keyboardView.activeNotes mutableCopy] ?: [NSMutableSet set];
        if (down) { [set addObject:@(midi)]; } else { [set removeObject:@(midi)]; }
        weakSelf.keyboardView.activeNotes = set;
    };
    [contentView addSubview:self.keyboardView];

    // Right: stops column (round buttons)
    self.stopsColumn = [[NSView alloc] initWithFrame:NSZeroRect];
    self.stopsColumn.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:self.stopsColumn];

    NSArray<NSString *> *stopNames = @[ @"Bright", @"Warm", @"Octave", @"Chorus", @"Dry", @"Air" ];
    NSMutableArray<NSButton *> *stopButtons = [NSMutableArray array];
    for (NSString *name in stopNames) {
        NSButton *btn = [NSButton buttonWithTitle:@"" target:nil action:nil];
    btn.bezelStyle = NSBezelStyleCircular;
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        btn.toolTip = name;
    [btn setButtonType:NSButtonTypeSwitch];
        [self.stopsColumn addSubview:btn];
        [stopButtons addObject:btn];
    }

    // Top-right hand-drawn close (X) control and a mute
    HandDrawnCloseButton *closeButton = [[HandDrawnCloseButton alloc] initWithFrame:NSZeroRect];
    closeButton.target = self; closeButton.action = @selector(closeApp:);
    closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:closeButton];

    self.muteButton = [NSButton buttonWithTitle:@"✕" target:self action:@selector(toggleAudio:)];
    self.muteButton.bezelStyle = NSBezelStyleTexturedRounded;
    self.muteButton.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:self.muteButton];

    // Bellows dots above the keyboard
    self.dotsView = [[BellowsDotsView alloc] initWithFrame:NSZeroRect];
    self.dotsView.translatesAutoresizingMaskIntoConstraints = NO;
    self.dotsView.count = 8;
    [contentView addSubview:self.dotsView];

    // No angle/status labels

    // Start/Stop button (also keyboard shortcut)
    self.audioToggleButton = [[NSButton alloc] init];
    [self.audioToggleButton setTitle:@"Start Audio"];
    [self.audioToggleButton setBezelStyle:NSBezelStyleRounded];
    [self.audioToggleButton setTarget:self];
    [self.audioToggleButton setAction:@selector(toggleAudio:)];
    [self.audioToggleButton setTranslatesAutoresizingMaskIntoConstraints:NO];
    [contentView addSubview:self.audioToggleButton];

    // Remove info labels; no instructions or angle/status

    // Layout
    NSLayoutConstraint *kbLeft = [self.keyboardView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:24];
    NSLayoutConstraint *kbRight = [self.keyboardView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-24];
    NSLayoutConstraint *kbBottom = [self.keyboardView.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor constant:-24];
    NSLayoutConstraint *kbHeight = [self.keyboardView.heightAnchor constraintEqualToConstant:140];

    NSMutableArray *stopConstraints = [NSMutableArray array];
    NSView *prev = nil;
    for (NSView *btn in self.stopsColumn.subviews) {
        [stopConstraints addObject:[btn.centerXAnchor constraintEqualToAnchor:self.stopsColumn.centerXAnchor]];
        [stopConstraints addObject:[btn.widthAnchor constraintEqualToConstant:36]];
        [stopConstraints addObject:[btn.heightAnchor constraintEqualToConstant:36]];
        if (!prev) {
            [stopConstraints addObject:[btn.topAnchor constraintEqualToAnchor:self.stopsColumn.topAnchor constant:24]];
        } else {
            [stopConstraints addObject:[btn.topAnchor constraintEqualToAnchor:prev.bottomAnchor constant:18]];
        }
        prev = btn;
    }

    [NSLayoutConstraint activateConstraints:@[
    kbLeft, kbRight, kbBottom, kbHeight,

        // Stops column to the right of keyboard
        [self.stopsColumn.leadingAnchor constraintEqualToAnchor:self.keyboardView.trailingAnchor constant:24],
        [self.stopsColumn.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:24],
        [self.stopsColumn.widthAnchor constraintEqualToConstant:80],
        [self.stopsColumn.bottomAnchor constraintLessThanOrEqualToAnchor:contentView.bottomAnchor constant:-24],
    ]];
    [NSLayoutConstraint activateConstraints:stopConstraints];

    [NSLayoutConstraint activateConstraints:@[
    // Top-right close and mute
    [closeButton.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:10],
    [closeButton.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-10],
    [self.muteButton.centerYAnchor constraintEqualToAnchor:closeButton.centerYAnchor],
    [self.muteButton.trailingAnchor constraintEqualToAnchor:closeButton.leadingAnchor constant:-8],
        
        // Dots centered above keyboard
        [self.dotsView.centerXAnchor constraintEqualToAnchor:self.keyboardView.centerXAnchor],
        [self.dotsView.bottomAnchor constraintEqualToAnchor:self.keyboardView.topAnchor constant:-12],
        [self.dotsView.widthAnchor constraintEqualToAnchor:self.keyboardView.widthAnchor multiplier:0.6],
        [self.dotsView.heightAnchor constraintEqualToConstant:40],

        // Info stack centered horizontally between stops and meter
    [self.audioToggleButton.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:24],
    [self.audioToggleButton.leadingAnchor constraintEqualToAnchor:self.stopsColumn.trailingAnchor constant:24],
        [self.audioToggleButton.widthAnchor constraintEqualToConstant:120],
        [self.audioToggleButton.heightAnchor constraintEqualToConstant:32],
    ]];
}

- (void)initializeLidSensor {
    self.lidSensor = [[LidAngleSensor alloc] init];
    (void)self.lidSensor; // no-op UI
}

- (void)initializeAudioEngines {
    self.harmoniumAudioEngine = [[HarmoniumAudioEngine alloc] init];
    if (!self.harmoniumAudioEngine) {
        [self.audioToggleButton setEnabled:NO];
    }
}

- (NSNumber *)midiForKey:(unichar)c {
    static NSDictionary<NSNumber*, NSNumber*> *map;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        map = @{
            @('z'): @(60), @('s'): @(61), @('x'): @(62), @('d'): @(63), @('c'): @(64), @('v'): @(65), @('g'): @(66), @('b'): @(67), @('h'): @(68), @('n'): @(69), @('j'): @(70), @('m'): @(71), @(','): @(72),
            @('q'): @(72), @('2'): @(73), @('w'): @(74), @('3'): @(75), @('e'): @(76), @('r'): @(77), @('5'): @(78), @('t'): @(79), @('6'): @(80), @('y'): @(81), @('7'): @(82), @('u'): @(83), @('i'): @(84)
        };
    });
    return map[@(tolower(c))];
}

- (void)installKeyboardMonitorsIfNeeded {
    if (self.keyDownMonitor) { [NSEvent removeMonitor:self.keyDownMonitor]; self.keyDownMonitor = nil; }
    if (self.keyUpMonitor) { [NSEvent removeMonitor:self.keyUpMonitor]; self.keyUpMonitor = nil; }
    __weak typeof(self) weakSelf = self;
    self.keyDownMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyDown handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
        BOOL handled = NO;
        for (NSUInteger i = 0; i < event.characters.length; i++) {
            unichar c = [event.characters characterAtIndex:i];
            NSNumber *n = [weakSelf midiForKey:c];
            if (n) {
                [weakSelf.harmoniumAudioEngine noteOn:n.intValue];
                NSMutableSet *set = [weakSelf.keyboardView.activeNotes mutableCopy] ?: [NSMutableSet set];
                [set addObject:n];
                weakSelf.keyboardView.activeNotes = set;
                handled = YES;
            }
        }
        return handled ? nil : event;
    }];
    self.keyUpMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskKeyUp handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
        BOOL handled = NO;
        for (NSUInteger i = 0; i < event.characters.length; i++) {
            unichar c = [event.characters characterAtIndex:i];
            NSNumber *n = [weakSelf midiForKey:c];
            if (n) {
                [weakSelf.harmoniumAudioEngine noteOff:n.intValue];
                NSMutableSet *set = [weakSelf.keyboardView.activeNotes mutableCopy] ?: [NSMutableSet set];
                [set removeObject:n];
                weakSelf.keyboardView.activeNotes = set;
                handled = YES;
            }
        }
        return handled ? nil : event;
    }];
}

- (IBAction)toggleAudio:(id)sender {
    if ([self.harmoniumAudioEngine isEngineRunning]) {
        [self.harmoniumAudioEngine stopEngine];
    [self.audioToggleButton setTitle:@"Start Audio"];
    } else {
        [self.harmoniumAudioEngine startEngine];
    [self.audioToggleButton setTitle:@"Stop Audio"];
    }
}

- (IBAction)closeApp:(id)sender {
    [NSApp terminate:self];
}

- (void)startUpdatingDisplay {
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.016
                                                        target:self
                                                      selector:@selector(updateAngleDisplay)
                                                      userInfo:nil
                                                       repeats:YES];
    self.lastDisplayUpdate = CACurrentMediaTime();
}

- (void)updateAngleDisplay {
    double now = CACurrentMediaTime();
    double dt = now - self.lastDisplayUpdate; if (dt < 0 || dt > 1.0) dt = 0.016; // guard
    self.lastDisplayUpdate = now;

    BOOL haveSensor = self.lidSensor.isAvailable;
    double angle = haveSensor ? [self.lidSensor lidAngle] : -2.0;

    if (!haveSensor || angle == -2.0) {
        // Fallback: always tick engine so pressure can decay to zero.
        if ([self.harmoniumAudioEngine activeNoteCount] > 0) {
            self.fallbackPhase += dt * (1.5 * 2.0 * M_PI); // 1.5 Hz
            double simAngle = 60.0 + 10.0 * sin(self.fallbackPhase);
            [self.harmoniumAudioEngine updateWithLidAngle:simAngle];
        } else {
            // Use a constant angle to indicate no movement; engine will decay pressure.
            [self.harmoniumAudioEngine updateWithLidAngle:0.0];
        }
    } else {
        [self.harmoniumAudioEngine updateWithLidAngle:angle];
    }

    self.dotsView.pressure = [self.harmoniumAudioEngine currentPressure];
}

@end
