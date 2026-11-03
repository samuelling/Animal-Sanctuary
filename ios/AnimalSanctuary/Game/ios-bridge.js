/* Animal Sanctuary for iOS: keeps the game's saves in native files instead of trusting WebKit storage alone.
   The app injects this at document start, right after it sets window.__AS_NATIVE_SAVE to the saved
   key/value pairs. The game itself is unchanged: it keeps calling localStorage, and every write is
   mirrored to the app through the "saves" message handler (SaveStore.swift writes it to disk).
     - Native files are the source of truth: on launch, every saved key is copied back into localStorage.
     - The first launch with the bridge (nothing saved natively yet) sends up whatever WebKit already holds.
     - Only the top window's localStorage is mirrored; nested arcade copies never save anyway. */
(function () {
  'use strict';
  if (window.__asBridge) return;
  var H = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.saves;
  if (!H || window.top !== window) return;
  window.__asBridge = true;
  var LS;
  try { LS = window.localStorage; } catch (e) { return; }
  var P = Storage.prototype, set = P.setItem, rem = P.removeItem, clr = P.clear;
  var post = function (m) { try { H.postMessage(m); } catch (e) {} };
  var seed = window.__AS_NATIVE_SAVE || {}, keys = Object.keys(seed);
  try {
    if (keys.length) {
      for (var i = 0; i < keys.length; i++) set.call(LS, keys[i], String(seed[keys[i]]));
    } else {
      var all = {};
      for (var j = 0; j < LS.length; j++) { var k = LS.key(j); all[k] = LS.getItem(k); }
      post({ op: 'all', data: all });
    }
  } catch (e) {}
  P.setItem = function (k, v) {
    set.apply(this, arguments);
    if (this === LS) post({ op: 'set', k: String(k), v: String(v) });
  };
  P.removeItem = function (k) {
    rem.apply(this, arguments);
    if (this === LS) post({ op: 'del', k: String(k) });
  };
  P.clear = function () {
    clr.apply(this, arguments);
    if (this === LS) post({ op: 'clear' });
  };
})();
