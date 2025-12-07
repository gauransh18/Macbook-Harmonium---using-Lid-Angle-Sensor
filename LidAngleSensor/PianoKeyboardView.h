//
//  PianoKeyboardView.h
//  LidAngleSensor
//
//  A simple vertical keyboard view (MIDI 60–84) that can highlight active notes
//  and emit mouse note on/off events.
//

#import <Cocoa/Cocoa.h>

@interface PianoKeyboardView : NSView

// MIDI note range
@property (nonatomic, assign) int midiStart; // default 60 (C4)
@property (nonatomic, assign) int midiEnd;   // default 84 (C6)

// Active note highlighting
@property (nonatomic, copy) NSSet<NSNumber *> *activeNotes;

// Layout and style
@property (nonatomic, assign) BOOL horizontal; // default NO (vertical). Set YES for horizontal layout.
@property (nonatomic, assign) BOOL handDrawn;  // default YES for sketchy style.

// Mouse callbacks
@property (nonatomic, copy) void (^noteEvent)(int midi, BOOL down);

@end
