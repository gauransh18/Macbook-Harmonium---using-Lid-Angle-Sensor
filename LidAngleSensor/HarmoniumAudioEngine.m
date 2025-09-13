//
//  HarmoniumAudioEngine.m
//  LidAngleSensor
//
//  Created by GitHub Copilot on 2025-09-14.
//

#import "HarmoniumAudioEngine.h"

// Musical ranges
static const double kMinAngle = 0.0;
static const double kMaxAngle = 135.0;

// Pressure mapping (bellows)
static const double kMovementThreshold = 0.3;     // deg change to count as movement
static const double kVelocitySmoothing = 0.25;     // EMA for velocity
static const double kPressureAttackMs = 25.0;      // pressure rises quickly
static const double kPressureDecayPerSec = 0.9;    // decay per second when moving/active
static const double kIdleDecayPerSec = 0.6;        // faster decay per second when idle (no notes)
static const double kPressureFloor = 0.01;         // clamp to zero below this when idle
static const double kVelocityToPressure = 0.0125;  // scale deg/s -> pressure increment
static const double kPressureMax = 1.0;

// Voice and synth
static const int    kMaxVoices = 8;
static const double kSampleRate = 44100.0;
static const double kDefaultLPFAlpha = 0.08;       // simple one-pole LPF for reeds
static const double kChorusCents = 6.0;            // detune for second oscillator
static const double kDefaultChorusMix = 0.35;      // mix of detuned osc
static const double kKeyOnAttackMs = 12.0;
static const double kKeyOffReleaseMs = 120.0;

typedef struct Voice {
    bool active;
    int midi;
    double phase1;
    double phase2;
    double env;         // 0..1 simple AR
    double envTarget;   // target for env ramp
    double envTC;       // time constant for env ramp (seconds)
    double lastOut;     // for LPF
} Voice;

@interface HarmoniumAudioEngine ()

@property (nonatomic, strong) AVAudioEngine *engine;
@property (nonatomic, strong) AVAudioSourceNode *source;
@property (nonatomic, strong) AVAudioMixerNode *mixer;

@property (nonatomic, assign) double lastAngle;
@property (nonatomic, assign) double smoothedVelocity;
@property (nonatomic, assign) double pressure; // 0..1
@property (nonatomic, assign) double lastUpdateTime;
@property (nonatomic, assign) BOOL firstUpdate;

@property (nonatomic, assign) Voice *voices; // allocated array of kMaxVoices

@end

static inline double midiToHz(int midi) {
    return 440.0 * pow(2.0, (midi - 69) / 12.0);
}

@implementation HarmoniumAudioEngine

- (instancetype)init {
    if ((self = [super init])) {
    _firstUpdate = YES;
        _lastAngle = 0;
        _smoothedVelocity = 0;
        _pressure = 0;
        _lastUpdateTime = CACurrentMediaTime();
    _voices = (Voice *)calloc(kMaxVoices, sizeof(Voice));
    _lpfAlpha = kDefaultLPFAlpha;
    _chorusMix = kDefaultChorusMix;
    _octaveUpMix = 0.0;
        if (![self setup]) {
            return nil;
        }
    }
    return self;
}

- (void)dealloc {
    [self stopEngine];
    if (self.voices) { free(self.voices); self.voices = NULL; }
}

- (BOOL)setup {
    self.engine = [[AVAudioEngine alloc] init];
    self.mixer = self.engine.mainMixerNode;

    AVAudioFormat *format = [[AVAudioFormat alloc] initWithCommonFormat:AVAudioPCMFormatFloat32
                                                             sampleRate:kSampleRate
                                                               channels:1
                                                            interleaved:NO];
    __weak typeof(self) weakSelf = self;
    self.source = [[AVAudioSourceNode alloc] initWithFormat:format renderBlock:^OSStatus(BOOL * _Nonnull isSilence, const AudioTimeStamp * _Nonnull ts, AVAudioFrameCount frames, AudioBufferList * _Nonnull outBuf) {
        return [weakSelf render:isSilence frames:frames out:outBuf];
    }];
    [self.engine attachNode:self.source];
    [self.engine connect:self.source to:self.mixer format:format];
    return YES;
}

- (BOOL)isEngineRunning { return self.engine.isRunning; }

- (void)startEngine {
    if (self.isEngineRunning) return;
    NSError *err = nil;
    if (![self.engine startAndReturnError:&err]) {
        NSLog(@"[HarmoniumAudioEngine] start failed: %@", err.localizedDescription);
    }
}

- (void)stopEngine {
    if (!self.isEngineRunning) return;
    [self.engine stop];
}

#pragma mark - Bellows from Lid Angle

- (void)updateWithLidAngle:(double)lidAngle {
    double now = CACurrentMediaTime();
    if (self.firstUpdate) {
        self.firstUpdate = NO;
        self.lastAngle = lidAngle;
        self.lastUpdateTime = now;
        return;
    }

    double dt = now - self.lastUpdateTime;
    if (dt <= 0 || dt > 1.0) { // skip bad deltas
        self.lastUpdateTime = now;
        return;
    }

    double dAngle = lidAngle - self.lastAngle;
    double instVel = (fabs(dAngle) < kMovementThreshold) ? 0.0 : fabs(dAngle / dt);
    // smooth velocity
    self.smoothedVelocity = kVelocitySmoothing * instVel + (1.0 - kVelocitySmoothing) * self.smoothedVelocity;

    // map velocity to pressure increment, clamp
    double inc = self.smoothedVelocity * kVelocityToPressure * dt;
    self.pressure = fmin(kPressureMax, self.pressure + inc);

    // natural decay (faster when idle/no notes)
    BOOL anyNotes = ([self activeNoteCount] > 0);
    double decayPerSec = anyNotes ? kPressureDecayPerSec : kIdleDecayPerSec;
    double decay = pow(decayPerSec, dt);
    self.pressure *= decay;

    // If effectively idle and pressure is tiny, snap to zero
    if (!anyNotes && self.smoothedVelocity < 0.05 && self.pressure < kPressureFloor) {
        self.pressure = 0.0;
    }

    self.lastAngle = lidAngle;
    self.lastUpdateTime = now;
}

- (double)currentVelocity { return self.smoothedVelocity; }
- (double)currentPressure { return self.pressure; }

#pragma mark - Notes

- (void)noteOn:(int)midiNote {
    // Reuse existing voice for same note or find free
    int freeIdx = -1;
    for (int i = 0; i < kMaxVoices; i++) {
        if (self.voices[i].active && self.voices[i].midi == midiNote) {
            freeIdx = i; break;
        }
        if (!self.voices[i].active && freeIdx < 0) freeIdx = i;
    }
    if (freeIdx < 0) freeIdx = 0; // steal voice 0
    Voice *v = &self.voices[freeIdx];
    v->active = true;
    v->midi = midiNote;
    // keep phase for legato; set env attack
    v->envTarget = 1.0;
    v->envTC = kKeyOnAttackMs / 1000.0;
}

- (void)noteOff:(int)midiNote {
    for (int i = 0; i < kMaxVoices; i++) {
        Voice *v = &self.voices[i];
        if (v->active && v->midi == midiNote) {
            v->envTarget = 0.0;
            v->envTC = kKeyOffReleaseMs / 1000.0;
        }
    }
}

- (void)allNotesOff {
    for (int i = 0; i < kMaxVoices; i++) {
        Voice *v = &self.voices[i];
        v->envTarget = 0.0;
        v->envTC = kKeyOffReleaseMs / 1000.0;
    }
}

- (NSUInteger)activeNoteCount {
    NSUInteger n = 0; for (int i=0;i<kMaxVoices;i++) if (self.voices[i].active) n++; return n;
}

#pragma mark - Rendering

- (OSStatus)render:(BOOL *)isSilence frames:(AVAudioFrameCount)frames out:(AudioBufferList *)outBuf {
    float *out = (float *)outBuf->mBuffers[0].mData;
    *isSilence = NO;

    // Precompute global bellows gain
    double bellows = fmin(1.0, fmax(0.0, self.pressure));
    // gentle nonlinearity to emulate wind pressure
    double bellowsGain = pow(bellows, 0.8);

    for (AVAudioFrameCount i = 0; i < frames; i++) {
        double mix = 0.0;
        for (int vIdx = 0; vIdx < kMaxVoices; vIdx++) {
            Voice *v = &self.voices[vIdx];
            if (!v->active && v->env <= 0.0005) continue;

            // Ramp envelope toward target
            double alpha = (v->envTC <= 0.0) ? 1.0 : fmin(1.0, 1.0 / (v->envTC * kSampleRate));
            v->env += (v->envTarget - v->env) * alpha;
            if (v->env < 0.0005 && v->envTarget == 0.0) {
                v->env = 0.0; v->active = false; // deactivate
                continue;
            }

            // Frequencies for 2-osc chorus
            double baseHz = midiToHz(v->midi);
            double detuneRatio = pow(2.0, (kChorusCents/100.0)/12.0);
            double hz1 = baseHz;
            double hz2 = baseHz * detuneRatio;

            double inc1 = 2.0 * M_PI * hz1 / kSampleRate;
            double inc2 = 2.0 * M_PI * hz2 / kSampleRate;

            // Simple bright reed-like waveform: saw blended with sine, then LPF
            double s1 = sin(v->phase1);
            double s2 = sin(v->phase2);
            double saw1 = (fmod(v->phase1, 2.0*M_PI)/M_PI) - 1.0; // naive saw [-1,1]
            double saw2 = (fmod(v->phase2, 2.0*M_PI)/M_PI) - 1.0;
            double osc = 0.65 * s1 + 0.35 * saw1 + self.chorusMix * (0.65 * s2 + 0.35 * saw2);

            if (self.octaveUpMix > 0.0001) {
                double sOct = sin(v->phase1 * 2.0);
                double sawOct = (fmod(v->phase1 * 2.0, 2.0*M_PI)/M_PI) - 1.0;
                osc = (1.0 - self.octaveUpMix) * osc + self.octaveUpMix * (0.5 * sOct + 0.5 * sawOct);
            }

            // one-pole LPF
            double filtAlpha = fmax(0.0, fmin(1.0, self.lpfAlpha));
            double y = v->lastOut + filtAlpha * (osc - v->lastOut);
            v->lastOut = y;

            mix += y * v->env;

            v->phase1 += inc1; if (v->phase1 >= 2.0*M_PI) v->phase1 -= 2.0*M_PI;
            v->phase2 += inc2; if (v->phase2 >= 2.0*M_PI) v->phase2 -= 2.0*M_PI;
        }

        out[i] = (float)(mix * bellowsGain * 0.2); // master gain
    }

    return noErr;
}

@end
