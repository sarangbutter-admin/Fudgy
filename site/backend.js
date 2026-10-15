/* Callebrownies: tiny Supabase client (no libraries, no build step).
   - rpc(): calls a database function through PostgREST
   When config.js is empty, SBK.on is false and the site runs in demo mode. */
(function () {
  "use strict";
  var C = window.CALLEBROWNIES_CONFIG || {};
  var URL_ = String(C.supabaseUrl || "").trim().replace(/\/+$/, "");
  var KEY = String(C.supabaseAnonKey || "").trim();
  var on = !!(URL_ && KEY);
  function nice(msg) {
    msg = String(msg || "");
    if (/Failed to fetch|NetworkError|Load failed|aborted/i.test(msg)) return "Can't reach the shop right now. Check your internet and try again.";
    return msg;
  }
  // a visitor hit one of the shop's limits: let the page show its friendly "slow down" pop-up
  function limitHit(msg, src) {
    try { if (/^(too many|we.re very busy|courier prices are busy)/i.test(msg) && window.ddSlow) window.ddSlow({ kind: "stop", src: src }); } catch (e) {}
    return msg;
  }
  // ...and when they are getting close to a limit, the friendly early warning
  function limitNear(j, src) {
    try { if (j && j._warn && window.ddSlow) window.ddSlow({ kind: "warn", src: src }); } catch (e) {}
  }
  function headers(token, extra) {
    var h = { "apikey": KEY, "Content-Type": "application/json" };
    // legacy anon keys are JWTs and may be sent as a bearer; new publishable keys must not be
    if (token) h["Authorization"] = "Bearer " + token;
    else if (/^eyJ/.test(KEY)) h["Authorization"] = "Bearer " + KEY;
    if (extra) for (var k in extra) h[k] = extra[k];
    return h;
  }
  function timeout(ms) { var c = new AbortController(); var t = setTimeout(function () { c.abort(); }, ms); return { signal: c.signal, done: function () { clearTimeout(t); } }; }

  async function rpc(name, args) {
    if (!on) throw new Error("Backend is not configured.");
    var tok = null;
    var attempt = async function (tk) {
      var t = timeout(25000), r;
      try {
        r = await fetch(URL_ + "/rest/v1/rpc/" + name, { method: "POST", headers: headers(tk), body: JSON.stringify(args || {}), signal: t.signal });
      } catch (e) { t.done(); throw new Error(nice(e && e.message)); }
      t.done();
      var txt = await r.text(), j = null;
      try { j = txt ? JSON.parse(txt) : null; } catch (e) { j = null; }
      if (!r.ok) {
        var err = new Error(limitHit(nice((j && (j.message || j.error_description || j.hint)) || ("Request failed (" + r.status + ")")), name));
        err.status = r.status; err.code = j && j.code;
        throw err;
      }
      if (j && j.ok === false && typeof j.err === "string") limitHit(j.err, name);
      limitNear(j, name);
      return j;
    };
    return attempt(tok);
  }

  // calls an Edge Function (admin = true: send the team member's token)
  async function fn(name, body, admin) {
    if (!on) throw new Error("Backend is not configured.");
    var tok = null;
    var t = timeout(30000), r;
    try {
      r = await fetch(URL_ + "/functions/v1/" + name, { method: "POST", headers: headers(tok), body: JSON.stringify(body || {}), signal: t.signal });
    } catch (e) { t.done(); throw new Error(nice(e && e.message)); }
    t.done();
    var txt = await r.text(), j = null;
    try { j = txt ? JSON.parse(txt) : null; } catch (e) { j = null; }
    var src = name === "biteship" ? "courier" : name;
    if (!r.ok) { var err = new Error(limitHit(nice((j && (j.error || j.message)) || ("Request failed (" + r.status + ")")), src)); err.status = r.status; throw err; }
    limitNear(j, src);
    return j;
  }

  window.SBK = { on: on, url: URL_, rpc: rpc, fn: fn };
})();
