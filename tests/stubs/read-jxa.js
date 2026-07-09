// Test stub for scripts/read-jxa.js — prints $STUB_JXA_JSON when set,
// otherwise "null" (= JXA fallback sees nothing playing).
ObjC.import("stdlib");
function run() {
  var v = null;
  try {
    v = $.getenv("STUB_JXA_JSON");
  } catch (e) {
    v = null;
  }
  var s = v === null || v === undefined ? "" : String(v);
  return s.length ? s : "null";
}
