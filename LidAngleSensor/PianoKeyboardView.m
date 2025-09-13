//
//  PianoKeyboardView.m
//  LidAngleSensor
//

#import "PianoKeyboardView.h"

@implementation PianoKeyboardView {
    BOOL _tracking;
}

- (instancetype)initWithFrame:(NSRect)frameRect {
    if (self = [super initWithFrame:frameRect]) {
        _midiStart = 60;
        _midiEnd = 84;
        _horizontal = YES; // switch to horizontal by default
        _handDrawn = YES;
        self.wantsLayer = YES;
    }
    return self;
}

- (BOOL)isOpaque { return YES; }

- (void)setActiveNotes:(NSSet<NSNumber *> *)activeNotes {
    _activeNotes = [activeNotes copy];
    [self setNeedsDisplay:YES];
}

static inline BOOL isBlackKey(int midi) {
    int d = midi % 12;
    return d==1||d==3||d==6||d==8||d==10;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    NSRect bounds = self.bounds;

    [[NSColor colorWithCalibratedWhite:0.98 alpha:1.0] setFill];
    NSRectFill(bounds);

    int noteCount = self.midiEnd - self.midiStart + 1;
    if (self.horizontal) {
        CGFloat keyWidth = bounds.size.width / MAX(1, noteCount);
        CGFloat whiteHeight = bounds.size.height;
        CGFloat blackHeight = bounds.size.height * 0.6;

        // Whites first
        for (int m = self.midiStart; m <= self.midiEnd; m++) {
            if (isBlackKey(m)) continue;
            int idx = m - self.midiStart;
            CGFloat x = bounds.origin.x + idx * keyWidth;
            NSRect r = NSMakeRect(x, bounds.origin.y, keyWidth, whiteHeight);

            BOOL active = [self.activeNotes containsObject:@(m)];
            NSColor *fill = active ? [NSColor colorWithCalibratedRed:0.9 green:0.95 blue:1 alpha:1] : [NSColor whiteColor];
            [fill setFill];
            if (self.handDrawn) {
                // Slight wobble for hand-drawn look
                CGFloat jitter = 0.8;
                NSBezierPath *p = [NSBezierPath bezierPath];
                [p moveToPoint:NSMakePoint(NSMinX(r)+arc4random_uniform(2)-1, NSMinY(r))];
                [p lineToPoint:NSMakePoint(NSMaxX(r)+arc4random_uniform(2)-1, NSMinY(r)+arc4random_uniform(2)-1)];
                [p lineToPoint:NSMakePoint(NSMaxX(r)+arc4random_uniform(2)-1, NSMaxY(r))];
                [p lineToPoint:NSMakePoint(NSMinX(r)+arc4random_uniform(2)-1, NSMaxY(r)+arc4random_uniform(2)-1)];
                [p closePath];
                [fill setFill];
                [p fill];
                [[NSColor colorWithCalibratedWhite:0.2 alpha:1] setStroke];
                p.lineWidth = 1.2;
                [p stroke];
            } else {
                NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(r, 0.5, 0.5) xRadius:2 yRadius:2];
                [p fill];
                [[NSColor colorWithCalibratedWhite:0.85 alpha:1] setStroke];
                p.lineWidth = 1;
                [p stroke];
            }
        }

        // Blacks
        for (int m = self.midiStart; m <= self.midiEnd; m++) {
            if (!isBlackKey(m)) continue;
            int idx = m - self.midiStart;
            CGFloat x = bounds.origin.x + idx * keyWidth + keyWidth*0.25;
            NSRect r = NSMakeRect(x, bounds.origin.y + (whiteHeight-blackHeight), keyWidth*0.5, blackHeight);
            BOOL active = [self.activeNotes containsObject:@(m)];
            NSColor *fill = active ? [NSColor colorWithCalibratedWhite:0.15 alpha:1] : [NSColor blackColor];
            [fill setFill];
            if (self.handDrawn) {
                NSBezierPath *p = [NSBezierPath bezierPath];
                [p moveToPoint:NSMakePoint(NSMinX(r)+arc4random_uniform(2)-1, NSMinY(r))];
                [p lineToPoint:NSMakePoint(NSMaxX(r)+arc4random_uniform(2)-1, NSMinY(r))];
                [p lineToPoint:NSMakePoint(NSMaxX(r)+arc4random_uniform(2)-1, NSMaxY(r)+arc4random_uniform(2)-1)];
                [p lineToPoint:NSMakePoint(NSMinX(r)+arc4random_uniform(2)-1, NSMaxY(r))];
                [p closePath];
                [p fill];
            } else {
                NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(r, 0.5, 0.5) xRadius:2 yRadius:2];
                [p fill];
            }
        }
    } else {
        // Original vertical fallback
        CGFloat keyHeight = bounds.size.height / MAX(1, noteCount);
        CGFloat whiteWidth = bounds.size.width;
        CGFloat blackWidth = bounds.size.width * 0.6;
        // Whites
        for (int m = self.midiStart; m <= self.midiEnd; m++) {
            if (isBlackKey(m)) continue;
            int idx = m - self.midiStart;
            CGFloat y = bounds.origin.y + idx * keyHeight;
            NSRect r = NSMakeRect(bounds.origin.x, y, whiteWidth, keyHeight);
            BOOL active = [self.activeNotes containsObject:@(m)];
            [[(active ? [NSColor colorWithCalibratedRed:0.85 green:0.92 blue:1 alpha:1] : [NSColor whiteColor]) colorWithAlphaComponent:1] setFill];
            NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(r, 1, 1) xRadius:2 yRadius:2];
            [path fill];
            [[NSColor colorWithCalibratedWhite:0.85 alpha:1] setStroke];
            [path setLineWidth:1];
            [path stroke];
        }
        // Blacks
        for (int m = self.midiStart; m <= self.midiEnd; m++) {
            if (!isBlackKey(m)) continue;
            int idx = m - self.midiStart;
            CGFloat y = bounds.origin.y + idx * keyHeight + keyHeight*0.25;
            NSRect r = NSMakeRect(bounds.origin.x + (whiteWidth - blackWidth), y, blackWidth, keyHeight*0.5);
            BOOL active = [self.activeNotes containsObject:@(m)];
            [[(active ? [NSColor colorWithCalibratedWhite:0.15 alpha:1] : [NSColor blackColor]) colorWithAlphaComponent:1] setFill];
            NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(r, 1, 1) xRadius:2 yRadius:2];
            [path fill];
        }
    }
}

- (int)midiForPoint:(NSPoint)p {
    NSRect b = self.bounds;
    int noteCount = self.midiEnd - self.midiStart + 1;
    if (self.horizontal) {
        CGFloat keyWidth = b.size.width / MAX(1, noteCount);
        int idx = floor((p.x - b.origin.x) / keyWidth);
        int m = self.midiStart + idx;
        if (m < self.midiStart) m = self.midiStart;
        if (m > self.midiEnd) m = self.midiEnd;
        // Prefer black key if near top where blacks sit and pattern expects one
        if (p.y > b.origin.y + b.size.height * 0.45) {
            static const int whiteToBlackOffset[12] = { 0, 0, +1, 0, 0, 0, 0, +1, 0, +1, 0, 0 };
            int d = m % 12;
            int off = whiteToBlackOffset[d];
            if (off != 0) {
                int cand = m + off;
                if (cand >= self.midiStart && cand <= self.midiEnd && isBlackKey(cand)) m = cand;
            }
        }
        return m;
    } else {
        CGFloat keyHeight = b.size.height / MAX(1, noteCount);
        int idx = floor((p.y - b.origin.y) / keyHeight);
        int m = self.midiStart + idx;
        if (m < self.midiStart) m = self.midiStart;
        if (m > self.midiEnd) m = self.midiEnd;
        if (p.x > b.origin.x + b.size.width * 0.55) {
            static const int whiteToBlackOffset[12] = { -1, 0, +1, 0, 0, -1, 0, +1, 0, +1, 0, 0 };
            int d = m % 12;
            int off = whiteToBlackOffset[d];
            if (off != 0) {
                int cand = m + off;
                if (cand >= self.midiStart && cand <= self.midiEnd && isBlackKey(cand)) m = cand;
            }
        }
        return m;
    }
}

- (void)mouseDown:(NSEvent *)event {
    _tracking = YES;
    NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
    int m = [self midiForPoint:p];
    if (self.noteEvent) self.noteEvent(m, YES);
}

- (void)mouseDragged:(NSEvent *)event {
    if (!_tracking) return;
    NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
    int m = [self midiForPoint:p];
    if (self.noteEvent) self.noteEvent(m, YES);
}

- (void)mouseUp:(NSEvent *)event {
    _tracking = NO;
    NSPoint p = [self convertPoint:event.locationInWindow fromView:nil];
    int m = [self midiForPoint:p];
    if (self.noteEvent) self.noteEvent(m, NO);
}

@end
