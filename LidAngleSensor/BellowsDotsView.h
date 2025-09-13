//
//  BellowsDotsView.h
//  LidAngleSensor
//

#import <Cocoa/Cocoa.h>

@interface BellowsDotsView : NSView

@property (nonatomic, assign) double pressure; // 0..1
@property (nonatomic, assign) NSUInteger count; // number of dots (default 8)
@property (nonatomic, assign) BOOL handDrawn;   // sketch style

@end
