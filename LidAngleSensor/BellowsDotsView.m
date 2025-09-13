//
//  BellowsDotsView.m
//  LidAngleSensor
//

#import "BellowsDotsView.h"

@implementation BellowsDotsView

- (instancetype)initWithFrame:(NSRect)frameRect {
    if (self = [super initWithFrame:frameRect]) {
        _pressure = 0.0;
        _count = 8;
        _handDrawn = YES;
        self.wantsLayer = YES;
    }
    return self;
}

- (BOOL)isOpaque { return NO; }

- (void)setPressure:(double)pressure {
    double p = fmax(0.0, fmin(1.0, pressure));
    if (p < 0.008) p = 0.0; // visually snap to zero for tiny values
    _pressure = p;
    [self setNeedsDisplay:YES];
}

- (void)setCount:(NSUInteger)count {
    _count = MAX(1, count);
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    NSRect b = NSInsetRect(self.bounds, 2, 2);
    if (self.count == 0) return;

    CGFloat spacing = 8.0;
    CGFloat usableW = NSWidth(b) - spacing * (self.count - 1);
    CGFloat dotSize = MIN(NSHeight(b), usableW / self.count);
    CGFloat originX = NSMinX(b) + (NSWidth(b) - (dotSize * self.count + spacing * (self.count - 1))) / 2.0;

    // Fill intensity for all dots is driven by pressure (no per-dot progression)
    CGFloat intensity = (CGFloat)self.pressure; // 0..1 alpha

    // Deterministic jitter per-index to avoid flicker
    CGFloat (^Jitter)(NSUInteger, CGFloat) = ^CGFloat(NSUInteger idx, CGFloat scale) {
        uint32_t h = (uint32_t)((idx + 1) * 2654435761u);
        h ^= h >> 16; h *= 2246822519u; h ^= h >> 13; h *= 3266489917u; h ^= h >> 16;
        CGFloat v = (h & 0xFF) / 255.0; // 0..1
        return (v - 0.5) * 2.0 * scale; // -scale..+scale
    };

    for (NSUInteger i = 0; i < self.count; i++) {
        CGFloat x = originX + i * (dotSize + spacing);
        NSRect circle = NSMakeRect(x, NSMidY(b) - dotSize/2, dotSize, dotSize);

    // Hand-drawn outer ring (stable jitter)
    NSPoint c = NSMakePoint(NSMidX(circle) + (self.handDrawn ? Jitter(i, 1.0) : 0), NSMidY(circle) + (self.handDrawn ? Jitter(i+17, 1.0) : 0));
    CGFloat r = dotSize/2 - 1 + (self.handDrawn ? Jitter(i+33, 0.2) : 0);
    NSBezierPath *ring = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(c.x - r, c.y - r, r*2, r*2)];
    [[NSColor colorWithCalibratedWhite:0.1 alpha:1] setStroke];
    ring.lineWidth = self.handDrawn ? 1.4 : 1.0;
    [ring stroke];

    // Fill: white base, then black with alpha = intensity
    NSBezierPath *fillPath = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(circle, 3, 3)];
    [[NSColor whiteColor] setFill];
    [fillPath fill];
    [[NSColor colorWithCalibratedWhite:0 alpha:intensity] setFill];
    [fillPath fill];
    }
}

@end
