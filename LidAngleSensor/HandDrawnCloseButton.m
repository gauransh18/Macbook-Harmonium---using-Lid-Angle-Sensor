//
//  HandDrawnCloseButton.m
//  LidAngleSensor
//

#import "HandDrawnCloseButton.h"

@implementation HandDrawnCloseButton

- (instancetype)initWithFrame:(NSRect)frameRect {
    if (self = [super initWithFrame:frameRect]) {
        self.wantsLayer = YES;
        self.toolTip = @"Close";
        [self addTrackingArea:[[NSTrackingArea alloc] initWithRect:self.bounds
                                                            options:NSTrackingActiveAlways | NSTrackingMouseEnteredAndExited | NSTrackingInVisibleRect
                                                              owner:self
                                                           userInfo:nil]];
        self.accessibilityLabel = @"Close";
    }
    return self;
}

- (BOOL)isOpaque { return NO; }

- (NSSize)intrinsicContentSize { return NSMakeSize(24, 24); }

- (void)mouseEntered:(NSEvent *)event { self.hovered = YES; [self setNeedsDisplay:YES]; }
- (void)mouseExited:(NSEvent *)event { self.hovered = NO; [self setNeedsDisplay:YES]; }
- (void)mouseDown:(NSEvent *)event { self.pressed = YES; [self setNeedsDisplay:YES]; }
- (void)mouseUp:(NSEvent *)event {
    self.pressed = NO; [self setNeedsDisplay:YES];
    if (NSPointInRect([self convertPoint:event.locationInWindow fromView:nil], self.bounds)) {
        [NSApp sendAction:self.action to:self.target from:self];
    }
}

static inline CGFloat jitterForKey(uint32_t k, CGFloat scale) {
    uint32_t h = (k + 1) * 2654435761u; h ^= h >> 16; h *= 2246822519u; h ^= h >> 13; h *= 3266489917u; h ^= h >> 16;
    CGFloat v = (h & 0xFF) / 255.0; return (v - 0.5) * 2.0 * scale;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    NSRect b = self.bounds;

    // Background subtle circle when hovered/pressed
    if (self.hovered || self.pressed) {
        CGFloat alpha = self.pressed ? 0.12 : 0.08;
        [[NSColor colorWithCalibratedWhite:0 alpha:alpha] setFill];
        NSBezierPath *bg = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(b, 1, 1)];
        [bg fill];
    }

    // Hand-drawn X
    CGFloat inset = 6.0;
    NSPoint p1 = NSMakePoint(NSMinX(b) + inset + jitterForKey(1, 0.6), NSMinY(b) + inset + jitterForKey(2, 0.6));
    NSPoint p2 = NSMakePoint(NSMaxX(b) - inset + jitterForKey(3, 0.6), NSMaxY(b) - inset + jitterForKey(4, 0.6));
    NSPoint p3 = NSMakePoint(NSMinX(b) + inset + jitterForKey(5, 0.6), NSMaxY(b) - inset + jitterForKey(6, 0.6));
    NSPoint p4 = NSMakePoint(NSMaxX(b) - inset + jitterForKey(7, 0.6), NSMinY(b) + inset + jitterForKey(8, 0.6));

    NSBezierPath *x1 = [NSBezierPath bezierPath];
    [x1 moveToPoint:p1]; [x1 lineToPoint:p2];
    NSBezierPath *x2 = [NSBezierPath bezierPath];
    [x2 moveToPoint:p3]; [x2 lineToPoint:p4];

    [[NSColor blackColor] setStroke];
    x1.lineWidth = 1.6; x2.lineWidth = 1.6;
    [x1 stroke]; [x2 stroke];
}

@end
