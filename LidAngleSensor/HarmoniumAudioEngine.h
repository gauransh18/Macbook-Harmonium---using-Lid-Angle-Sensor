//
//  HarmoniumAudioEngine.h
//  LidAngleSensor
//
//  Created by GitHub Copilot on 2025-09-14.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

/**
 * HarmoniumAudioEngine synthesizes a reed-organ-like sound and maps lid movement
 * to bellows pressure while computer keyboard keys control notes.
 *
 * - Bellows pressure rises with lid angular velocity and decays over time.
 * - Polyphonic voices with gentle chorus and low-pass filtering for timbre.
 */
@interface HarmoniumAudioEngine : NSObject

@property (nonatomic, assign, readonly) BOOL isEngineRunning;
@property (nonatomic, assign, readonly) double currentVelocity;   // deg/s (smoothed)
@property (nonatomic, assign, readonly) double currentPressure;   // 0..1
@property (nonatomic, assign, readonly) NSUInteger activeNoteCount;

// Simple timbre controls (thread-unsafe, set from main thread)
@property (nonatomic, assign) double lpfAlpha;    // 0..1, default ~0.08 (higher = brighter)
@property (nonatomic, assign) double chorusMix;   // 0..1, default ~0.35
@property (nonatomic, assign) double octaveUpMix; // 0..1, default 0.0

- (instancetype)init;

- (void)startEngine;
- (void)stopEngine;
- (void)updateWithLidAngle:(double)lidAngle;

// Keyboard control
- (void)noteOn:(int)midiNote;
- (void)noteOff:(int)midiNote;
- (void)allNotesOff;

@end
