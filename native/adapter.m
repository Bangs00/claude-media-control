// adapter.m — self-contained MediaRemote bridge for the "media" Claude Code
// plugin. Ports techniques from ungive/mediaremote-adapter (BSD-3-Clause,
// see NOTICE). Loaded by /usr/bin/perl (native/loader.pl) so the calling
// process is an Apple platform binary (bundle id com.apple.perl5), which
// passes the mediaremoted entitlement check introduced in macOS 15.4.
//
// Exported entry points (installed as XSUBs by loader.pl, `void f(void)`):
//   adapter_get         — print now-playing JSON (or "null") to stdout
//   adapter_send        — send a playback command; id via $MEDIA_SEND_COMMAND
//   adapter_seek        — set absolute position; seconds via $MEDIA_SEEK_SECONDS
//   adapter_test        — self-diagnosis; result via exit code (see below)
//   adapter_artwork     — save artwork to <$MEDIA_ARTWORK_PATH>.<ext> and print
//                         {"path":…,"mimeType":…,"bytes":…} (or "null")
//   adapter_output_list — print {"current":…,"devices":[…]} of the system
//                         audio output devices (CoreAudio, public API)
//   adapter_output_set  — make $MEDIA_OUTPUT_DEVICE (name, unique substring,
//                         or 1-based index) the default output device; exit 4
//                         when it matches no device or is ambiguous
//
// Parameters travel via environment variables because the perl XSUB calling
// convention cannot pass C arguments (upstream uses the same pattern).
//
// adapter_test exit codes:
//   0 — daemon responded and now-playing metadata was read (fully working)
//   5 — daemon responded but no now-playing info (nothing playing, or read
//       blocked; the dispatcher cross-checks with the JXA fallback)
//   2 — MediaRemote symbols could not be resolved (framework changed)
//   3 — daemon did not respond within the timeout
//
// Build: clang -fobjc-arc -dynamiclib -fvisibility=default -Wall \
//          -framework Foundation -framework AppKit -framework CoreAudio \
//          adapter.m -o libadapter.dylib

#import <AppKit/AppKit.h>
#import <CoreAudio/CoreAudio.h>
#import <Foundation/Foundation.h>

// ---- MediaRemote command IDs (documented in davidmurray/ios-reversed-headers) ----
typedef enum {
    kMRPlay = 0,
    kMRPause = 1,
    kMRTogglePlayPause = 2,
    kMRStop = 3,
    kMRNextTrack = 4,
    kMRPreviousTrack = 5,
} MRCommand;

// ---- Private MediaRemote function pointer signatures ----
typedef void (*MRGetInfo_t)(dispatch_queue_t, void (^)(NSDictionary *));
typedef void (*MRGetPID_t)(dispatch_queue_t, void (^)(int));
typedef void (*MRGetIsPlaying_t)(dispatch_queue_t, void (^)(bool));
typedef bool (*MRSendCommand_t)(MRCommand, id);
typedef void (*MRSetElapsedTime_t)(double);

static MRGetInfo_t mrGetInfo;
static MRGetPID_t mrGetPID;
static MRGetIsPlaying_t mrGetIsPlaying;
static MRSendCommand_t mrSendCommand;
static MRSetElapsedTime_t mrSetElapsedTime;
static dispatch_queue_t g_queue;

#define GET_TIMEOUT_MILLIS 2000

__attribute__((constructor)) static void init_mediaremote(void) {
    CFURLRef url = (__bridge CFURLRef)[NSURL
        fileURLWithPath:@"/System/Library/PrivateFrameworks/MediaRemote.framework"];
    CFBundleRef bundle = CFBundleCreate(kCFAllocatorDefault, url);
    if (!bundle) {
        return;
    }
    mrGetInfo = (MRGetInfo_t)CFBundleGetFunctionPointerForName(
        bundle, CFSTR("MRMediaRemoteGetNowPlayingInfo"));
    mrGetPID = (MRGetPID_t)CFBundleGetFunctionPointerForName(
        bundle, CFSTR("MRMediaRemoteGetNowPlayingApplicationPID"));
    mrGetIsPlaying = (MRGetIsPlaying_t)CFBundleGetFunctionPointerForName(
        bundle, CFSTR("MRMediaRemoteGetNowPlayingApplicationIsPlaying"));
    mrSendCommand = (MRSendCommand_t)CFBundleGetFunctionPointerForName(
        bundle, CFSTR("MRMediaRemoteSendCommand"));
    mrSetElapsedTime = (MRSetElapsedTime_t)CFBundleGetFunctionPointerForName(
        bundle, CFSTR("MRMediaRemoteSetElapsedTime"));
    g_queue = dispatch_queue_create("media.adapter.serial", DISPATCH_QUEUE_SERIAL);
}

static void printOut(NSString *s) {
    fprintf(stdout, "%s\n", [s UTF8String]);
    fflush(stdout);
}

static void printJSONObject(id obj) {
    NSError *err = nil;
    NSData *json = [NSJSONSerialization dataWithJSONObject:obj
                                                   options:0
                                                     error:&err];
    if (!json) {
        fprintf(stderr, "JSON serialization failed: %s\n",
                [[err localizedDescription] UTF8String]);
        exit(1);
    }
    printOut([[NSString alloc] initWithData:json
                                   encoding:NSUTF8StringEncoding]);
}

// ---- CoreAudio output devices (public API — no MediaRemote involved) ----

static AudioObjectPropertyAddress globalAddr(AudioObjectPropertySelector sel) {
    return (AudioObjectPropertyAddress){sel, kAudioObjectPropertyScopeGlobal,
                                        kAudioObjectPropertyElementMain};
}

// A device counts as an output when it exposes at least one output channel.
static BOOL isOutputDevice(AudioObjectID dev) {
    AudioObjectPropertyAddress addr = {kAudioDevicePropertyStreamConfiguration,
                                       kAudioObjectPropertyScopeOutput,
                                       kAudioObjectPropertyElementMain};
    UInt32 size = 0;
    if (AudioObjectGetPropertyDataSize(dev, &addr, 0, NULL, &size) != noErr ||
        size == 0) {
        return NO;
    }
    AudioBufferList *bufs = malloc(size);
    if (!bufs) {
        return NO;
    }
    BOOL output = NO;
    if (AudioObjectGetPropertyData(dev, &addr, 0, NULL, &size, bufs) == noErr) {
        for (UInt32 i = 0; i < bufs->mNumberBuffers; i++) {
            if (bufs->mBuffers[i].mNumberChannels > 0) {
                output = YES;
                break;
            }
        }
    }
    free(bufs);
    return output;
}

static NSString *deviceName(AudioObjectID dev) {
    if (dev == kAudioObjectUnknown) {
        return nil;
    }
    AudioObjectPropertyAddress addr = globalAddr(kAudioObjectPropertyName);
    CFStringRef name = NULL;
    UInt32 size = sizeof(name);
    if (AudioObjectGetPropertyData(dev, &addr, 0, NULL, &size, &name) != noErr ||
        !name) {
        return nil;
    }
    return CFBridgingRelease(name);
}

static AudioObjectID defaultOutputDevice(void) {
    AudioObjectPropertyAddress addr =
        globalAddr(kAudioHardwarePropertyDefaultOutputDevice);
    AudioObjectID dev = kAudioObjectUnknown;
    UInt32 size = sizeof(dev);
    if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL,
                                   &size, &dev) != noErr) {
        return kAudioObjectUnknown;
    }
    return dev;
}

// Output-capable devices in system enumeration order; ids/names share indexes.
static void collectOutputDevices(NSMutableArray<NSNumber *> *ids,
                                 NSMutableArray<NSString *> *names) {
    AudioObjectPropertyAddress addr = globalAddr(kAudioHardwarePropertyDevices);
    UInt32 size = 0;
    if (AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &addr, 0, NULL,
                                       &size) != noErr ||
        size == 0) {
        return;
    }
    AudioObjectID *devs = malloc(size);
    if (!devs) {
        return;
    }
    if (AudioObjectGetPropertyData(kAudioObjectSystemObject, &addr, 0, NULL,
                                   &size, devs) == noErr) {
        UInt32 count = size / sizeof(AudioObjectID);
        for (UInt32 i = 0; i < count; i++) {
            if (!isOutputDevice(devs[i])) {
                continue;
            }
            NSString *name = deviceName(devs[i]);
            if (name.length == 0) {
                continue;
            }
            [ids addObject:@(devs[i])];
            [names addObject:name];
        }
    }
    free(devs);
}

static BOOL finiteNumber(id v) {
    if (![v isKindOfClass:[NSNumber class]]) {
        return NO;
    }
    double d = [v doubleValue];
    return !isinf(d) && !isnan(d);
}

// Collect the now-playing dictionary. Returns nil when there is no usable
// now-playing state; *timedOut distinguishes "daemon silent" from "no info".
// Artwork (kMRMediaRemoteNowPlayingInfoArtworkData) is deliberately never
// read: huge base64 blobs would pollute the Claude conversation context.
static NSDictionary *collectNowPlaying(BOOL *timedOut) {
    if (timedOut) {
        *timedOut = NO;
    }
    if (!mrGetInfo || !mrGetPID || !mrGetIsPlaying) {
        return nil;
    }
    __block NSMutableDictionary *data = [NSMutableDictionary dictionary];
    dispatch_group_t group = dispatch_group_create();

    // PID + bundle identifier + display name
    dispatch_group_enter(group);
    mrGetPID(g_queue, ^(int pid) {
      if (pid != 0) {
          data[@"processIdentifier"] = @(pid);
          NSRunningApplication *app = [NSRunningApplication
              runningApplicationWithProcessIdentifier:pid];
          if (app.bundleIdentifier != nil) {
              data[@"bundleIdentifier"] = app.bundleIdentifier;
          }
          if (app.localizedName != nil) {
              data[@"appName"] = app.localizedName;
          }
      }
      dispatch_group_leave(group);
    });

    // isPlaying
    dispatch_group_enter(group);
    mrGetIsPlaying(g_queue, ^(bool playing) {
      data[@"playing"] = @(playing);
      dispatch_group_leave(group);
    });

    // now-playing metadata
    dispatch_group_enter(group);
    mrGetInfo(g_queue, ^(NSDictionary *info) {
      void (^copyStr)(NSString *, NSString *) = ^(NSString *dst, NSString *src) {
        id v = info[src];
        if ([v isKindOfClass:[NSString class]]) {
            data[dst] = v;
        }
      };
      copyStr(@"title", @"kMRMediaRemoteNowPlayingInfoTitle");
      copyStr(@"artist", @"kMRMediaRemoteNowPlayingInfoArtist");
      copyStr(@"album", @"kMRMediaRemoteNowPlayingInfoAlbum");

      // Live streams report an infinite duration; omit it so JSON stays valid.
      id dur = info[@"kMRMediaRemoteNowPlayingInfoDuration"];
      if (finiteNumber(dur)) {
          data[@"duration"] = dur;
      }
      id elapsed = info[@"kMRMediaRemoteNowPlayingInfoElapsedTime"];
      if (finiteNumber(elapsed)) {
          data[@"elapsedTime"] = elapsed;
      }
      id rate = info[@"kMRMediaRemoteNowPlayingInfoPlaybackRate"];
      if (finiteNumber(rate)) {
          data[@"playbackRate"] = rate;
      }
      id ts = info[@"kMRMediaRemoteNowPlayingInfoTimestamp"];
      if ([ts isKindOfClass:[NSDate class]]) {
          data[@"timestampEpoch"] = @([(NSDate *)ts timeIntervalSince1970]);
      }
      dispatch_group_leave(group);
    });

    dispatch_time_t timeout =
        dispatch_time(DISPATCH_TIME_NOW, GET_TIMEOUT_MILLIS * NSEC_PER_MSEC);
    if (dispatch_group_wait(group, timeout) != 0) {
        if (timedOut) {
            *timedOut = YES;
        }
        return nil;
    }

    // Mandatory keys (upstream media-control contract): pid + title + playing.
    if (data[@"processIdentifier"] == nil || data[@"title"] == nil ||
        data[@"playing"] == nil) {
        return nil;
    }

    // The elapsedTime snapshot ages; estimate the current position from the
    // snapshot timestamp (equivalent to media-control's --now).
    id elapsed = data[@"elapsedTime"];
    id tsEpoch = data[@"timestampEpoch"];
    if (elapsed != nil && tsEpoch != nil) {
        double rate = finiteNumber(data[@"playbackRate"])
                          ? [data[@"playbackRate"] doubleValue]
                          : ([data[@"playing"] boolValue] ? 1.0 : 0.0);
        double diff = [[NSDate date] timeIntervalSince1970] - [tsEpoch doubleValue];
        double now = [elapsed doubleValue] + (rate > 0 && diff > 0 ? diff * rate : 0);
        if (finiteNumber(data[@"duration"]) &&
            now > [data[@"duration"] doubleValue]) {
            now = [data[@"duration"] doubleValue];
        }
        data[@"elapsedTimeNow"] = @(now);
    }

    // Human-readable snapshot timestamp (ISO 8601), matching the plan schema.
    if (tsEpoch != nil) {
        NSISO8601DateFormatter *fmt = [[NSISO8601DateFormatter alloc] init];
        NSDate *date =
            [NSDate dateWithTimeIntervalSince1970:[tsEpoch doubleValue]];
        data[@"timestamp"] = [fmt stringFromDate:date];
        [data removeObjectForKey:@"timestampEpoch"];
    }

    return data;
}

// ---- exported entry points ----

void adapter_get(void) {
    @autoreleasepool {
        BOOL timedOut = NO;
        NSDictionary *data = collectNowPlaying(&timedOut);
        if (!data) {
            if (timedOut) {
                fprintf(stderr, "mediaremoted did not respond\n");
                exit(3);
            }
            printOut(@"null");
            return;
        }
        // Enrich with the current output device (cheap CoreAudio read) so the
        // statusline `output` field costs no extra process spawn.
        NSMutableDictionary *out = [data mutableCopy];
        NSString *dev = deviceName(defaultOutputDevice());
        if (dev != nil) {
            out[@"outputDevice"] = dev;
        }
        printJSONObject(out);
    }
}

// One round-trip to the daemon so the queued command is flushed before the
// process exits (mirrors upstream behavior).
static void waitForCompletion(void) {
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    if (mrGetPID) {
        mrGetPID(g_queue, ^(int pid) {
          (void)pid;
          dispatch_semaphore_signal(sem);
        });
        dispatch_semaphore_wait(
            sem, dispatch_time(DISPATCH_TIME_NOW, 2000 * NSEC_PER_MSEC));
    }
}

void adapter_send(void) {
    @autoreleasepool {
        const char *raw = getenv("MEDIA_SEND_COMMAND");
        if (!raw || !*raw) {
            fprintf(stderr, "missing MEDIA_SEND_COMMAND\n");
            exit(64);
        }
        char *end = NULL;
        long cmd = strtol(raw, &end, 10);
        // Only the documented playback commands; reject anything else so an
        // arbitrary MRCommand can never be injected through the environment.
        if (*end != '\0' ||
            !(cmd == kMRPlay || cmd == kMRPause || cmd == kMRTogglePlayPause ||
              cmd == kMRStop || cmd == kMRNextTrack || cmd == kMRPreviousTrack)) {
            fprintf(stderr, "unsupported command id: %s\n", raw);
            exit(64);
        }
        if (!mrSendCommand) {
            fprintf(stderr, "MRMediaRemoteSendCommand unavailable\n");
            exit(2);
        }
        bool ok = mrSendCommand((MRCommand)cmd, nil);
        if (!ok) {
            fprintf(stderr, "send command %ld failed\n", cmd);
            exit(1);
        }
        waitForCompletion();
        printOut(@"{\"ok\":true}");
    }
}

void adapter_seek(void) {
    @autoreleasepool {
        const char *raw = getenv("MEDIA_SEEK_SECONDS");
        if (!raw || !*raw) {
            fprintf(stderr, "missing MEDIA_SEEK_SECONDS\n");
            exit(64);
        }
        char *end = NULL;
        double seconds = strtod(raw, &end);
        if (*end != '\0' || isnan(seconds) || isinf(seconds) || seconds < 0) {
            fprintf(stderr, "invalid seek position: %s\n", raw);
            exit(64);
        }
        if (!mrSetElapsedTime) {
            fprintf(stderr, "MRMediaRemoteSetElapsedTime unavailable\n");
            exit(2);
        }
        mrSetElapsedTime(seconds);
        waitForCompletion();
        printOut(@"{\"ok\":true}");
    }
}

// Artwork is fetched on demand only (never in adapter_get): the image lands
// in a file and only its path travels through the conversation context.
void adapter_artwork(void) {
    @autoreleasepool {
        const char *raw = getenv("MEDIA_ARTWORK_PATH");
        if (!raw || !*raw) {
            fprintf(stderr, "missing MEDIA_ARTWORK_PATH\n");
            exit(64);
        }
        NSString *prefix = [NSString stringWithUTF8String:raw];
        if (!mrGetInfo) {
            fprintf(stderr, "MRMediaRemoteGetNowPlayingInfo unavailable\n");
            exit(2);
        }
        __block NSData *art = nil;
        __block NSString *mime = nil;
        dispatch_semaphore_t sem = dispatch_semaphore_create(0);
        mrGetInfo(g_queue, ^(NSDictionary *info) {
          id d = info[@"kMRMediaRemoteNowPlayingInfoArtworkData"];
          if ([d isKindOfClass:[NSData class]]) {
              art = d;
          }
          id m = info[@"kMRMediaRemoteNowPlayingInfoArtworkMIMEType"];
          if ([m isKindOfClass:[NSString class]]) {
              mime = m;
          }
          dispatch_semaphore_signal(sem);
        });
        dispatch_time_t timeout =
            dispatch_time(DISPATCH_TIME_NOW, GET_TIMEOUT_MILLIS * NSEC_PER_MSEC);
        if (dispatch_semaphore_wait(sem, timeout) != 0) {
            fprintf(stderr, "mediaremoted did not respond\n");
            exit(3);
        }
        if (!art || art.length == 0) {
            printOut(@"null");
            return;
        }

        // Extension from the MIME type, verified against magic bytes when
        // the MIME type is missing (JPEG in practice, PNG occasionally).
        NSString *ext = nil;
        if (mime) {
            if ([mime containsString:@"png"]) {
                ext = @"png";
            } else if ([mime containsString:@"jpeg"] || [mime containsString:@"jpg"]) {
                ext = @"jpg";
            }
        }
        if (!ext && art.length >= 4) {
            const unsigned char *b = art.bytes;
            if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) {
                ext = @"png";
            } else if (b[0] == 0xFF && b[1] == 0xD8) {
                ext = @"jpg";
            }
        }
        if (!ext) {
            ext = @"bin";
        }

        NSString *path = [NSString stringWithFormat:@"%@.%@", prefix, ext];
        NSError *err = nil;
        if (![art writeToFile:path options:NSDataWritingAtomic error:&err]) {
            fprintf(stderr, "cannot write artwork to %s: %s\n",
                    [path UTF8String], [[err localizedDescription] UTF8String]);
            exit(1);
        }
        NSMutableDictionary *out = [NSMutableDictionary dictionary];
        out[@"path"] = path;
        out[@"bytes"] = @(art.length);
        if (mime) {
            out[@"mimeType"] = mime;
        }
        printJSONObject(out);
    }
}

// ---- output devices ----

void adapter_output_list(void) {
    @autoreleasepool {
        NSMutableArray<NSNumber *> *ids = [NSMutableArray array];
        NSMutableArray<NSString *> *names = [NSMutableArray array];
        collectOutputDevices(ids, names);
        if (names.count == 0) {
            fprintf(stderr, "no audio output devices found\n");
            exit(1);
        }
        NSMutableDictionary *out = [NSMutableDictionary dictionary];
        NSString *current = deviceName(defaultOutputDevice());
        if (current != nil) {
            out[@"current"] = current;
        }
        out[@"devices"] = names;
        printJSONObject(out);
    }
}

void adapter_output_set(void) {
    @autoreleasepool {
        const char *raw = getenv("MEDIA_OUTPUT_DEVICE");
        if (!raw || !*raw) {
            fprintf(stderr, "missing MEDIA_OUTPUT_DEVICE\n");
            exit(64);
        }
        NSString *want = [NSString stringWithUTF8String:raw];
        NSMutableArray<NSNumber *> *ids = [NSMutableArray array];
        NSMutableArray<NSString *> *names = [NSMutableArray array];
        collectOutputDevices(ids, names);
        if (names.count == 0) {
            fprintf(stderr, "no audio output devices found\n");
            exit(1);
        }

        // Resolve the request: 1-based index, then case-insensitive exact
        // name, then unique case-insensitive substring.
        NSInteger target = -1;
        char *end = NULL;
        long idx = strtol(raw, &end, 10);
        if (*end == '\0' && idx >= 1 && (NSUInteger)idx <= names.count) {
            target = idx - 1;
        }
        if (target < 0) {
            for (NSUInteger i = 0; i < names.count; i++) {
                if ([names[i] caseInsensitiveCompare:want] == NSOrderedSame) {
                    target = (NSInteger)i;
                    break;
                }
            }
        }
        if (target < 0) {
            NSMutableArray<NSNumber *> *hits = [NSMutableArray array];
            for (NSUInteger i = 0; i < names.count; i++) {
                if ([names[i] rangeOfString:want
                                    options:NSCaseInsensitiveSearch]
                        .location != NSNotFound) {
                    [hits addObject:@(i)];
                }
            }
            if (hits.count == 1) {
                target = hits[0].integerValue;
            } else if (hits.count > 1) {
                NSMutableArray<NSString *> *matched = [NSMutableArray array];
                for (NSNumber *h in hits) {
                    [matched addObject:names[h.unsignedIntegerValue]];
                }
                fprintf(stderr, "ambiguous output device \"%s\" — matches: %s\n",
                        raw,
                        [[matched componentsJoinedByString:@", "] UTF8String]);
                exit(4);
            }
        }
        if (target < 0) {
            fprintf(stderr, "no output device matches \"%s\" — available: %s\n",
                    raw, [[names componentsJoinedByString:@", "] UTF8String]);
            exit(4);
        }

        AudioObjectID dev = (AudioObjectID)ids[(NSUInteger)target].unsignedIntValue;
        AudioObjectPropertyAddress addr =
            globalAddr(kAudioHardwarePropertyDefaultOutputDevice);
        OSStatus st = AudioObjectSetPropertyData(kAudioObjectSystemObject, &addr,
                                                 0, NULL, sizeof(dev), &dev);
        if (st != noErr) {
            fprintf(stderr, "switching the output device failed (OSStatus %d)\n",
                    (int)st);
            exit(1);
        }
        NSMutableDictionary *out = [NSMutableDictionary dictionary];
        out[@"ok"] = @YES;
        out[@"current"] = names[(NSUInteger)target];
        printJSONObject(out);
    }
}

void adapter_test(void) {
    @autoreleasepool {
        if (!mrGetInfo || !mrGetPID || !mrGetIsPlaying || !mrSendCommand ||
            !mrSetElapsedTime) {
            fprintf(stderr, "MediaRemote symbols not resolved\n");
            exit(2);
        }
        BOOL timedOut = NO;
        NSDictionary *data = collectNowPlaying(&timedOut);
        if (timedOut) {
            fprintf(stderr, "mediaremoted did not respond\n");
            exit(3);
        }
        if (!data) {
            // Daemon is reachable but reports no now-playing item. Either
            // nothing is playing (normal) or reads are blocked; the caller
            // disambiguates by cross-checking the JXA fallback.
            fprintf(stderr, "daemon reachable, no now-playing info\n");
            exit(5);
        }
        exit(0);
    }
}
