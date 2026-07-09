// spectrum.m — audio spectrum for the "media" Claude Code plugin (Phase 4,
// opt-in). Captures the system output mix through a Core Audio process tap
// (AudioHardwareCreateProcessTap, public API since macOS 14.4), runs a vDSP
// FFT, and renders log-scaled frequency bands as Unicode block bars.
//
// Unlike native/adapter.m this binary is run DIRECTLY (no perl loader): the
// process tap needs no MediaRemote entitlement bypass. It does need the
// TCC "system audio recording" grant on the *responsible process* (the
// terminal app hosting Claude Code). Without it the tap still starts and
// delivers callbacks, but every sample is zero — there is no public API to
// query the grant, so callers disambiguate "denied" from "genuine silence"
// by cross-checking whether something is actually playing.
//
// Subcommands (argv[1]):
//   snapshot            capture ~1s, print one spectrum line, exit 0
//   live <seconds>      print a spectrum line ~4x/second for <seconds>
//   preflight           capture briefly; exit 0 if real audio was seen,
//                       3 if only silence (permission missing or nothing
//                       playing — caller decides which), 2 on API failure
//
// Exit codes: 0 ok, 2 tap/aggregate API failure, 3 silent capture
//   (no signal), 64 usage error.
//
// Build: clang -fobjc-arc -dynamiclib is NOT used here; this is a plain
//   executable:
//     clang -fobjc-arc -Wall -Werror -framework Foundation \
//       -framework CoreAudio -framework Accelerate spectrum.m -o spectrum
//
// Ports the aggregate-device + tap recipe validated against insidegui/
// AudioCap (see native/NOTICE). No audio ever leaves this process: capture
// is analyzed in-memory (FFT) and only the resulting bar string is printed.

#import <Accelerate/Accelerate.h>
#import <CoreAudio/AudioHardware.h>
#import <CoreAudio/AudioHardwareTapping.h>
#import <CoreAudio/CATapDescription.h>
#import <Foundation/Foundation.h>
#import <stdatomic.h>

// ---- capture state (shared with the realtime IOProc) ----

typedef struct {
    float *samples;          // rolling mono mixdown
    size_t capacity;
    _Atomic size_t count;    // frames written (saturates at capacity)
    _Atomic uint64_t nonZero;
} Capture;

static Capture g_cap;

static OSStatus ioProc(AudioObjectID inDevice, const AudioTimeStamp *inNow,
                       const AudioBufferList *inInputData,
                       const AudioTimeStamp *inInputTime,
                       AudioBufferList *outOutputData,
                       const AudioTimeStamp *inOutputTime, void *inClientData) {
    (void)inDevice; (void)inNow; (void)inInputTime; (void)outOutputData;
    (void)inOutputTime; (void)inClientData;
    if (!inInputData || inInputData->mNumberBuffers == 0) {
        return noErr;
    }
    // The tap delivers one interleaved float32 buffer. Mix channels to mono.
    const AudioBuffer *buf = &inInputData->mBuffers[0];
    UInt32 chans = buf->mNumberChannels ? buf->mNumberChannels : 1;
    const float *data = (const float *)buf->mData;
    if (!data) {
        return noErr;
    }
    size_t frames = buf->mDataByteSize / sizeof(float) / chans;
    size_t have = atomic_load_explicit(&g_cap.count, memory_order_relaxed);
    size_t wrote = 0;
    for (size_t f = 0; f < frames && have + f < g_cap.capacity; f++) {
        float acc = 0;
        for (UInt32 c = 0; c < chans; c++) {
            acc += data[f * chans + c];
        }
        float v = acc / chans;
        g_cap.samples[have + f] = v;
        if (v != 0.0f) {
            atomic_fetch_add_explicit(&g_cap.nonZero, 1, memory_order_relaxed);
        }
        wrote++;
    }
    atomic_store_explicit(&g_cap.count, have + wrote, memory_order_relaxed);
    return noErr;
}

// ---- tap lifecycle ----

typedef struct {
    AudioObjectID tapID;
    AudioObjectID aggID;
    AudioDeviceIOProcID procID;
    double sampleRate;
} TapSession;

static NSString *fourcc(OSStatus s) {
    uint32_t u = (uint32_t)s;
    char c[5] = {(char)(u >> 24), (char)(u >> 16), (char)(u >> 8), (char)u, 0};
    for (int i = 0; i < 4; i++) {
        if (c[i] < 32 || c[i] > 126) {
            return [NSString stringWithFormat:@"%d", (int)s];
        }
    }
    return [NSString stringWithFormat:@"'%s'", c];
}

// Build a private aggregate device wrapping a global-mixdown tap and start
// its IOProc. Returns NO (with a stderr note) on any Core Audio failure.
static BOOL tapStart(TapSession *s) {
    memset(s, 0, sizeof(*s));
    s->sampleRate = 48000.0;

    CATapDescription *desc =
        [[CATapDescription alloc] initStereoGlobalTapButExcludeProcesses:@[]];
    desc.name = @"claude-media-spectrum";
    desc.privateTap = YES;
    desc.muteBehavior = CATapUnmuted;  // never mute what the user hears

    OSStatus st = AudioHardwareCreateProcessTap(desc, &s->tapID);
    if (st != noErr || s->tapID == kAudioObjectUnknown) {
        fprintf(stderr, "spectrum: AudioHardwareCreateProcessTap failed (%s)\n",
                fourcc(st).UTF8String);
        return NO;
    }

    // Prefer the tap's own format for the FFT sample rate.
    AudioObjectPropertyAddress fmtAddr = {kAudioTapPropertyFormat,
                                          kAudioObjectPropertyScopeGlobal,
                                          kAudioObjectPropertyElementMain};
    AudioStreamBasicDescription asbd = {0};
    UInt32 size = sizeof(asbd);
    if (AudioObjectGetPropertyData(s->tapID, &fmtAddr, 0, NULL, &size, &asbd) ==
            noErr &&
        asbd.mSampleRate > 0) {
        s->sampleRate = asbd.mSampleRate;
    }

    // Default output device UID -> aggregate main/sub device.
    AudioObjectPropertyAddress defOutAddr = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal, kAudioObjectPropertyElementMain};
    AudioObjectID outDev = kAudioObjectUnknown;
    size = sizeof(outDev);
    if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &defOutAddr, 0,
                                   NULL, &size, &outDev) != noErr ||
        outDev == kAudioObjectUnknown) {
        fprintf(stderr, "spectrum: no default output device\n");
        AudioHardwareDestroyProcessTap(s->tapID);
        return NO;
    }
    AudioObjectPropertyAddress uidAddr = {kAudioDevicePropertyDeviceUID,
                                          kAudioObjectPropertyScopeGlobal,
                                          kAudioObjectPropertyElementMain};
    CFStringRef outUID = NULL;
    size = sizeof(outUID);
    if (AudioObjectGetPropertyData(outDev, &uidAddr, 0, NULL, &size, &outUID) !=
            noErr ||
        outUID == NULL) {
        fprintf(stderr, "spectrum: cannot read output device UID\n");
        AudioHardwareDestroyProcessTap(s->tapID);
        return NO;
    }
    NSString *outUIDStr = (__bridge_transfer NSString *)outUID;

    // Empty sub-device list / missing main device => silent zero samples,
    // so both must name the real output device (matches AudioCap).
    NSString *aggUID = [[NSUUID UUID] UUIDString];
    NSDictionary *aggDesc = @{
        @kAudioAggregateDeviceUIDKey : aggUID,
        @kAudioAggregateDeviceNameKey : @"claude-media-spectrum",
        @kAudioAggregateDeviceMainSubDeviceKey : outUIDStr,
        @kAudioAggregateDeviceIsPrivateKey : @YES,
        @kAudioAggregateDeviceIsStackedKey : @NO,
        @kAudioAggregateDeviceTapAutoStartKey : @YES,
        @kAudioAggregateDeviceSubDeviceListKey :
            @[ @{@kAudioSubDeviceUIDKey : outUIDStr} ],
        @kAudioAggregateDeviceTapListKey : @[ @{
            @kAudioSubTapUIDKey : desc.UUID.UUIDString,
            @kAudioSubTapDriftCompensationKey : @YES,
        } ],
    };
    OSStatus aggSt = AudioHardwareCreateAggregateDevice(
        (__bridge CFDictionaryRef)aggDesc, &s->aggID);
    if (aggSt != noErr || s->aggID == kAudioObjectUnknown) {
        fprintf(stderr, "spectrum: AudioHardwareCreateAggregateDevice failed (%s)\n",
                fourcc(aggSt).UTF8String);
        AudioHardwareDestroyProcessTap(s->tapID);
        return NO;
    }

    OSStatus pst = AudioDeviceCreateIOProcID(s->aggID, ioProc, NULL, &s->procID);
    if (pst != noErr || !s->procID) {
        fprintf(stderr, "spectrum: AudioDeviceCreateIOProcID failed (%s)\n",
                fourcc(pst).UTF8String);
        AudioHardwareDestroyAggregateDevice(s->aggID);
        AudioHardwareDestroyProcessTap(s->tapID);
        return NO;
    }
    OSStatus dst = AudioDeviceStart(s->aggID, s->procID);
    if (dst != noErr) {
        fprintf(stderr, "spectrum: AudioDeviceStart failed (%s)\n",
                fourcc(dst).UTF8String);
        AudioDeviceDestroyIOProcID(s->aggID, s->procID);
        AudioHardwareDestroyAggregateDevice(s->aggID);
        AudioHardwareDestroyProcessTap(s->tapID);
        return NO;
    }
    return YES;
}

static void tapStop(TapSession *s) {
    if (s->procID) {
        AudioDeviceStop(s->aggID, s->procID);
        AudioDeviceDestroyIOProcID(s->aggID, s->procID);
    }
    if (s->aggID != kAudioObjectUnknown) {
        AudioHardwareDestroyAggregateDevice(s->aggID);
    }
    if (s->tapID != kAudioObjectUnknown) {
        AudioHardwareDestroyProcessTap(s->tapID);
    }
    memset(s, 0, sizeof(*s));
}

// Spin the runloop until at least minFrames are captured or the deadline
// passes. IOProc runs on a realtime thread, so this only waits.
static void pumpUntil(size_t minFrames, NSTimeInterval maxWait) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:maxWait];
    while ([deadline timeIntervalSinceNow] > 0) {
        if (atomic_load(&g_cap.count) >= minFrames) {
            break;
        }
        [[NSRunLoop currentRunLoop]
            runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
    }
}

// ---- FFT + render ----

enum { FFT_LEN = 4096, FFT_LOG2 = 12, BANDS = 16 };

// Average power spectrum of the newest samples over Hann-windowed hops.
// Writes BANDS log-scaled dB values into out[], returns the peak band index
// (or -1 when there is not enough signal).
static int analyze(const float *samples, size_t n, double sampleRate,
                   float outDb[BANDS]) {
    if (n < FFT_LEN) {
        return -1;
    }
    static FFTSetup setup;
    static float window[FFT_LEN];
    static float windowed[FFT_LEN];
    static float re[FFT_LEN / 2];
    static float im[FFT_LEN / 2];
    static BOOL ready = NO;
    if (!ready) {
        setup = vDSP_create_fftsetup(FFT_LOG2, kFFTRadix2);
        vDSP_hann_window(window, FFT_LEN, vDSP_HANN_NORM);
        ready = YES;
    }
    float power[FFT_LEN / 2];
    memset(power, 0, sizeof(power));
    DSPSplitComplex split = {.realp = re, .imagp = im};
    size_t hops = 0;
    for (size_t off = 0; off + FFT_LEN <= n; off += FFT_LEN / 2) {
        vDSP_vmul(samples + off, 1, window, 1, windowed, 1, FFT_LEN);
        vDSP_ctoz((const DSPComplex *)windowed, 2, &split, 1, FFT_LEN / 2);
        vDSP_fft_zrip(setup, &split, 1, FFT_LOG2, kFFTDirection_Forward);
        split.imagp[0] = 0;  // packed Nyquist term; ignore for magnitudes
        float mag[FFT_LEN / 2];
        vDSP_zvmags(&split, 1, mag, 1, FFT_LEN / 2);
        vDSP_vadd(power, 1, mag, 1, power, 1, FFT_LEN / 2);
        hops++;
    }
    if (!hops) {
        return -1;
    }
    float inv = 1.0f / hops;
    vDSP_vsmul(power, 1, &inv, power, 1, FFT_LEN / 2);

    const double fLo = 63.0, fHi = 16000.0;
    double binHz = sampleRate / FFT_LEN;
    int peak = 0;
    for (int i = 0; i < BANDS; i++) {
        double b0 = fLo * pow(fHi / fLo, (double)i / BANDS);
        double b1 = fLo * pow(fHi / fLo, (double)(i + 1) / BANDS);
        int k0 = (int)(b0 / binHz), k1 = (int)(b1 / binHz);
        if (k1 <= k0) {
            k1 = k0 + 1;
        }
        if (k1 > FFT_LEN / 2) {
            k1 = FFT_LEN / 2;
        }
        if (k0 < 1) {
            k0 = 1;  // skip DC
        }
        float sum = 0;
        for (int k = k0; k < k1; k++) {
            sum += power[k];
        }
        float mean = (k1 > k0) ? sum / (k1 - k0) : 0;
        outDb[i] = 10.0f * log10f(mean + 1e-12f);
        if (outDb[i] > outDb[peak]) {
            peak = i;
        }
    }
    return peak;
}

// Render dB values as Unicode block bars. Music has a natural high-frequency
// rolloff, so a flat "loudest band minus 48 dB" window leaves the treble
// blank; a mild pink tilt (+dB per band up the spectrum) rebalances it into
// something readable without lying about the peak.
#define RENDER_RANGE_DB 48.0f
#define RENDER_TILT_DB_PER_BAND 2.2f

static NSString *renderBarsN(const float *db, int bands) {
    // NSString literals so the multi-byte block glyphs encode correctly
    // (appendFormat:@"%s" mangles UTF-8).
    static NSString *const blocks[] = {@" ", @"▁", @"▂", @"▃", @"▄",
                                       @"▅", @"▆", @"▇", @"█"};
    // Apply the tilt, then scale to the loudest tilted band.
    float tilted[BANDS];
    float mx = -1e9f;
    for (int i = 0; i < bands; i++) {
        tilted[i] = db[i] + RENDER_TILT_DB_PER_BAND * i;
        if (tilted[i] > mx) {
            mx = tilted[i];
        }
    }
    NSMutableString *line = [NSMutableString string];
    for (int i = 0; i < bands; i++) {
        float rel = tilted[i] - mx;  // <= 0
        int lvl = (int)lroundf((rel + RENDER_RANGE_DB) / RENDER_RANGE_DB * 8.0f);
        if (lvl < 0) {
            lvl = 0;
        }
        if (lvl > 8) {
            lvl = 8;
        }
        [line appendString:blocks[lvl]];
        if (bands >= 12 && i == bands / 2 - 1) {
            [line appendString:@" "];  // visual split between low/high halves
        }
    }
    return line;
}

static void printSpectrum(const float db[BANDS], int peak, double sampleRate) {
    const double fLo = 63.0, fHi = 16000.0;
    double peakHz = fLo * pow(fHi / fLo, (peak + 0.5) / BANDS);
    NSString *bars = renderBarsN(db, BANDS);
    NSString *peakStr = peakHz >= 1000
                            ? [NSString stringWithFormat:@"%.1fkHz", peakHz / 1000.0]
                            : [NSString stringWithFormat:@"%.0fHz", peakHz];
    fprintf(stdout, "63Hz %s 16kHz   (peak: %s)\n", bars.UTF8String,
            peakStr.UTF8String);
    fflush(stdout);
    (void)sampleRate;
}

// ---- capture helpers ----

// Reset the rolling buffer so a fresh window is analyzed each live frame.
static void resetCapture(void) {
    atomic_store(&g_cap.count, 0);
    atomic_store(&g_cap.nonZero, 0);
}

static BOOL hasSignal(void) {
    size_t n = atomic_load(&g_cap.count);
    if (n < FFT_LEN) {
        return NO;
    }
    float rms = 0;
    vDSP_rmsqv(g_cap.samples, 1, &rms, n);
    return rms > 1e-5f;  // above the noise floor of a real signal
}

// ---- subcommands ----

// Capture ~1s so the FFT averages many hops (a short grab over-weights one
// transient and leaves the render lopsided).
#define SNAPSHOT_MIN_FRAMES 48000
#define SNAPSHOT_MAX_WAIT 1.6

static int doSnapshot(void) {
    TapSession s;
    if (!tapStart(&s)) {
        return 2;
    }
    pumpUntil(SNAPSHOT_MIN_FRAMES, SNAPSHOT_MAX_WAIT);
    size_t n = atomic_load(&g_cap.count);
    BOOL signal = hasSignal();
    double rate = s.sampleRate;  // read before tapStop zeroes the struct
    tapStop(&s);

    if (n < FFT_LEN || !signal) {
        fprintf(stderr, "spectrum: captured only silence — grant \"system audio "
                        "recording\" to your terminal app in System Settings > "
                        "Privacy & Security, or nothing is playing.\n");
        return 3;
    }
    float db[BANDS];
    int peak = analyze(g_cap.samples, n, rate, db);
    if (peak < 0) {
        fprintf(stderr, "spectrum: not enough audio to analyze\n");
        return 3;
    }
    if (getenv("SPECTRUM_DEBUG")) {
        float rms = 0, mn = 0, mx = 0;
        vDSP_rmsqv(g_cap.samples, 1, &rms, n);
        vDSP_minv(g_cap.samples, 1, &mn, n);
        vDSP_maxv(g_cap.samples, 1, &mx, n);
        fprintf(stderr, "DEBUG n=%zu rate=%.0f rms=%.5f min=%.4f max=%.4f peak=%d\n",
                n, rate, rms, mn, mx, peak);
        for (int i = 0; i < BANDS; i++) {
            fprintf(stderr, "DEBUG band%2d %.2f dB\n", i, db[i]);
        }
    }
    printSpectrum(db, peak, rate);
    return 0;
}

// Compact bar string only (no axis labels / peak) for a statusline segment.
// <bands> defaults to 12. Prints nothing and exits 3 on silence so the
// caller can drop the segment cleanly.
static int doBars(int bands) {
    if (bands < 4) {
        bands = 12;
    }
    if (bands > BANDS) {
        bands = BANDS;
    }
    TapSession s;
    if (!tapStart(&s)) {
        return 2;
    }
    // Shorter capture than snapshot: a statusline refresh should not stall for
    // a full second. Fewer FFT hops, but a glanceable bar is fine.
    pumpUntil(FFT_LEN * 3, 0.7);
    size_t n = atomic_load(&g_cap.count);
    BOOL signal = hasSignal();
    double rate = s.sampleRate;  // read before tapStop zeroes the struct
    tapStop(&s);
    if (n < FFT_LEN || !signal) {
        return 3;
    }
    float db[BANDS];
    int peak = analyze(g_cap.samples, n, rate, db);
    if (peak < 0) {
        return 3;
    }
    // Collapse the full BANDS analysis into <bands> display columns.
    float shown[BANDS];
    for (int i = 0; i < bands; i++) {
        int k0 = i * BANDS / bands, k1 = (i + 1) * BANDS / bands;
        if (k1 <= k0) {
            k1 = k0 + 1;
        }
        float best = -1e9f;
        for (int k = k0; k < k1 && k < BANDS; k++) {
            if (db[k] > best) {
                best = db[k];
            }
        }
        shown[i] = best;
    }
    fprintf(stdout, "%s\n", renderBarsN(shown, bands).UTF8String);
    fflush(stdout);
    return 0;
}

static int doLive(double seconds) {
    if (seconds <= 0) {
        seconds = 5;
    }
    if (seconds > 60) {
        seconds = 60;  // bound the run so a stray call cannot linger
    }
    TapSession s;
    if (!tapStart(&s)) {
        return 2;
    }
    // Warm up so the first frame is not silence-by-timing.
    pumpUntil(FFT_LEN, 1.0);
    NSDate *end = [NSDate dateWithTimeIntervalSinceNow:seconds];
    BOOL any = NO;
    while ([end timeIntervalSinceNow] > 0) {
        resetCapture();
        pumpUntil(FFT_LEN, 0.4);
        size_t n = atomic_load(&g_cap.count);
        if (n >= FFT_LEN && hasSignal()) {
            float db[BANDS];
            int peak = analyze(g_cap.samples, n, s.sampleRate, db);
            if (peak >= 0) {
                printSpectrum(db, peak, s.sampleRate);
                any = YES;
            }
        }
    }
    tapStop(&s);
    if (!any) {
        fprintf(stderr, "spectrum: captured only silence for the whole run — "
                        "check the audio-recording permission or start playback.\n");
        return 3;
    }
    return 0;
}

// preflight: is real audio capturable right now? Distinguishing "permission
// denied" from "nothing playing" is impossible here (no query API), so this
// only reports signal vs silence; the shell dispatcher cross-checks the
// now-playing state to decide which.
static int doPreflight(void) {
    TapSession s;
    if (!tapStart(&s)) {
        return 2;
    }
    pumpUntil(FFT_LEN * 2, 1.2);
    BOOL signal = hasSignal();
    tapStop(&s);
    return signal ? 0 : 3;
}

int main(int argc, char **argv) {
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr,
                    "usage: spectrum snapshot|live <seconds>|bars [n]|preflight\n");
            return 64;
        }
        // Allocate the rolling buffer for the longest single analysis window
        // plus generous headroom (~2s at 48k).
        g_cap.capacity = 48000 * 2 + FFT_LEN * 8;
        g_cap.samples = calloc(g_cap.capacity, sizeof(float));
        if (!g_cap.samples) {
            fprintf(stderr, "spectrum: out of memory\n");
            return 2;
        }
        NSString *cmd = [NSString stringWithUTF8String:argv[1]];
        int rc;
        if ([cmd isEqualToString:@"snapshot"]) {
            rc = doSnapshot();
        } else if ([cmd isEqualToString:@"live"]) {
            double secs = argc > 2 ? atof(argv[2]) : 5.0;
            rc = doLive(secs);
        } else if ([cmd isEqualToString:@"bars"]) {
            int bands = argc > 2 ? atoi(argv[2]) : 12;
            rc = doBars(bands);
        } else if ([cmd isEqualToString:@"preflight"]) {
            rc = doPreflight();
        } else {
            fprintf(stderr, "spectrum: unknown subcommand: %s\n", argv[1]);
            rc = 64;
        }
        free(g_cap.samples);
        return rc;
    }
}
