// focus-tab.js — select the browser window+tab that plays the current
// track (the Chromium AppleScript suite: window `activeTabIndex`, tab
// `title`/`URL`). Called by media.sh focus_media for the Chromium family —
// and ChatGPT Atlas's embedded engine — right after activate_app brought
// the owning app forward.
//
// JXA on purpose: it resolves scripting terminology at RUN time, so the
// bundle id can arrive as an argument. Plain AppleScript must load the
// target's dictionary at COMPILE time — `tell application id <variable>`
// dies with -2740 on `active tab index` before running a single line
// (the v0.18.0 bug this file replaces).
//
// Two passes, because web players update the tab title lazily: pass 1
// picks the tab whose title contains the track title (case-insensitive —
// parity with the AppleScript `contains` the Safari branch uses); pass 2
// falls back to the first tab on a dedicated music-player site, since a
// background-throttled tab can sit on its generic site title ("YouTube
// Music") for minutes after a track change. Titles and URLs are read only
// to locate the player; nothing leaves the machine.
//
// Run: osascript -l JavaScript focus-tab.js <bundle-id> <track-title>
// Prints nothing. Always exits 0: focus is best-effort on top of an
// activation that already happened — an unresolvable or unscriptable
// target, a denied Automation consent (-1743), or no matching tab just
// leaves the app as activate_app raised it. Never launches anything: a
// bundle that is not already running is left untouched (JXA property
// access would otherwise start it).

// Hosts where a tab IS the player (deliberately no www.youtube.com — too
// many plain video tabs to guess between).
var PLAYER_HOSTS = [
  "music.youtube.com",
  "open.spotify.com",
  "music.apple.com",
  "soundcloud.com",
  "tidal.com",
  "deezer.com",
];

function hostOf(url) {
  var m = /^[a-z][a-z0-9+.-]*:\/\/([^/?#]+)/i.exec(String(url || ""));
  if (!m) return "";
  var h = m[1].toLowerCase();
  var at = h.lastIndexOf("@");
  if (at >= 0) h = h.slice(at + 1);
  var colon = h.indexOf(":");
  if (colon >= 0) h = h.slice(0, colon);
  return h;
}

function isPlayerHost(h) {
  if (!h) return false;
  for (var i = 0; i < PLAYER_HOSTS.length; i++) {
    var d = PLAYER_HOSTS[i];
    if (h === d || h.slice(-(d.length + 1)) === "." + d) return true;
  }
  return false;
}

function select(w, ti) {
  w.activeTabIndex = ti + 1; // 1-based: select the tab
  w.index = 1; // raise its window
}

function run(argv) {
  try {
    var want = String(argv[1] || "").toLowerCase();
    if (!argv[0] || !want) return;
    var app = Application(argv[0]);
    if (!app.running()) return;
    var wins = app.windows;
    var wn = wins.length;
    var wi, ti;
    for (wi = 0; wi < wn; wi++) {
      var w = wins[wi];
      var titles;
      try {
        titles = w.tabs.title(); // one AppleEvent per window, not per tab
      } catch (e) {
        continue; // a window without tabs (devtools, pickers)
      }
      for (ti = 0; ti < titles.length; ti++) {
        var t = titles[ti];
        if (t && String(t).toLowerCase().indexOf(want) >= 0) {
          select(w, ti);
          return;
        }
      }
    }
    for (wi = 0; wi < wn; wi++) {
      var w2 = wins[wi];
      var urls;
      try {
        urls = w2.tabs.url();
      } catch (e) {
        continue;
      }
      for (ti = 0; ti < urls.length; ti++) {
        if (isPlayerHost(hostOf(urls[ti]))) {
          select(w2, ti);
          return;
        }
      }
    }
  } catch (e) {
    // Best-effort by design; see header.
  }
}
