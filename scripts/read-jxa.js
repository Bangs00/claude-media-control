// read-jxa.js — fallback now-playing read via JXA + MRNowPlayingRequest.
// Zero compile, zero install: works because osascript is an Apple-signed
// platform binary, so the MediaRemote read entitlement check (macOS 15.4+)
// passes. Used when the native helper is unavailable (no CLT / build failed).
// Cannot read artwork; output carries "degraded": true so callers know.
//
// Run: osascript -l JavaScript read-jxa.js
// Output: one JSON line on stdout, or "null" when nothing is playing.
// NOTE: the value is returned from run() — console.log would go to stderr.
ObjC.import("Foundation");

function nsToJs(v) {
  return v && v.js !== undefined ? v.js : v;
}

function run() {
  const bundle = $.NSBundle.bundleWithPath(
    "/System/Library/PrivateFrameworks/MediaRemote.framework"
  );
  if (!bundle || !bundle.load) {
    return "null";
  }
  const Req = $.NSClassFromString("MRNowPlayingRequest");
  if (!Req) {
    return "null";
  }
  const item = Req.localNowPlayingItem;
  if (!item) {
    return "null";
  }
  const md = item.metadata;
  if (!md) {
    return "null";
  }

  const out = { degraded: true };
  const title = nsToJs(md.title);
  if (!title) {
    return "null";
  }
  out.title = title;
  const artist = nsToJs(md.trackArtistName);
  if (artist) out.artist = artist;
  const album = nsToJs(md.albumName);
  if (album) out.album = album;

  const dur = nsToJs(md.duration);
  if (typeof dur === "number" && isFinite(dur) && dur > 0) out.duration = dur;
  const elapsed = nsToJs(md.elapsedTime);
  if (typeof elapsed === "number" && isFinite(elapsed)) {
    out.elapsedTime = elapsed;
    out.elapsedTimeNow = elapsed; // best effort: no snapshot timestamp here
  }
  const rate = nsToJs(md.playbackRate);
  if (typeof rate === "number" && isFinite(rate)) {
    out.playbackRate = rate;
    out.playing = rate > 0;
  }

  // The owning app, via player path -> client (verified on macOS 26.5.1).
  // Needed by the AppleScript control fallback for per-app routing.
  try {
    const path = Req.localNowPlayingPlayerPath;
    if (path) {
      const client = path.client;
      if (client) {
        const bid = nsToJs(client.bundleIdentifier);
        if (bid) out.bundleIdentifier = bid;
        const name = nsToJs(client.displayName);
        if (name) out.appName = name;
      }
    }
  } catch (e) {
    // Optional enrichment only; reads above already succeeded.
  }

  return JSON.stringify(out);
}
