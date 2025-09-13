//
//  BellowsMeterView.m
//  LidAngleSensor
//

#import "BellowsMeterView.h"

@implementation BellowsMeterView

- (BOOL)isOpaque { return NO; }

- (void)setPressure:(double)pressure {
    _pressure = fmax(0.0, fmin(1.0, pressure));
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    NSRect b = NSInsetRect(self.bounds, 2, 2);

    // Background circle border (like a meter icon)
    CGFloat diameter = MIN(b.size.width, b.size.height);
    NSRect circle = NSMakeRect(NSMidX(b)-diameter/2, NSMidY(b)-diameter/2, diameter, diameter);
    NSBezierPath *ring = [NSBezierPath bezierPathWithOvalInRect:circle];
    [[NSColor colorWithCalibratedWhite:0.8 alpha:1] setStroke];
    [ring setLineWidth:2];
    [ring stroke];

    // Fill as arc based on pressure
    CGFloat startAngle = 270; // bottom
    CGFloat sweep = 360 * self.pressure;
    NSBezierPath *arc = [NSBezierPath bezierPath];
    [arc appendBezierPathWithArcWithCenter:NSMakePoint(NSMidX(circle), NSMidY(circle))
                                    radius:diameter/2 - 4
                                startAngle:startAngle
                                  endAngle:startAngle + sweep
                                 clockwise:NO];
    [[NSColor systemBlueColor] setStroke];
    [arc setLineWidth:6];
    [arc stroke];
}

@end
