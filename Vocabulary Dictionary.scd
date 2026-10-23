/* ============================================================================
   SYNESTHESIA — VOCABULARY DICTIONARY
   The MVP audio language (Phase 1), one entry per word.

   Every word below is real and loaded by the Synesthesia quark. Each entry gives
   the signature, what it does, its arguments, what it returns, and examples you
   can evaluate (place the cursor on a line and press Shift-Enter after running
   Setup.scd). This file is a reference to READ, not a set to run top to bottom.

   THE ONE RULE: every word returns a plain SuperCollider object — a Pbind, a
   Function, or a NodeProxy. Nothing is a wall. Raw SC composes with any word in
   the same expression, and anything you can do to a Pbind you can do to the
   result of \k.hits("x..x").

   HOW SOUND HAPPENS: spawner words build material; you assign it to a proxy
   (~name) and .play it. Proxies live in ProxySpace, crossfade on re-evaluation,
   and are sculpted/wired in place.
       ~a = \tone.drone({55});   // build
       ~a.play;                  // sound it
       ~a = \saw.drone({55});    // re-assign: crossfades to the new source
       ~a.stop(4);               // fade out over 4s (JITLib), keeps the proxy
       ~a.clear;                 // remove entirely

   Contents:
     1. CONTROL WORDS      bpm grid hush rec pad
     2. SPAWNERS           hits deg chord drone stack
     3. STRING NOTATION    steps stepAmps
     4. SCULPT             fx unfx wide dc fade
     5. WIRE               feeds route duck
     6. BRIDGE             follow pat mapExp mapLin
     7. TRANSFORM          fast slow sometimes jux
     8. REFERENCE TABLES   instruments · drone recipes · fx recipes · JITLib verbs
============================================================================ */


/* ============================================================================
   1. CONTROL WORDS
   Bare words for the frame of the performance. SuperCollider parses foo(x) as
   x.foo, so these read as words but live on the argument's class.
============================================================================ */

// ---- bpm ------------------------------------------------------------------
// bpm(beatsPerMinute)
// Set the tempo of the performance clock, in familiar BPM. Running patterns
// follow immediately. Creates the tempo clock if there isn't one.
// Returns: the BPM value.
bpm(120);
bpm(90);

// ---- grid -----------------------------------------------------------------
// grid(beats)
// Quantize re-evaluations: a rebound proxy/pattern takes effect on the next
// boundary of this many beats, so edits always land musically no matter when
// you press evaluate. grid(0) makes changes immediate.
// Returns: the beat count.
grid(4);   // changes land on the next bar
grid(0);   // immediate

// ---- hush -----------------------------------------------------------------
// hush(seconds)
// Fade EVERY proxy in the space to silence over `seconds` — the musical panic
// button. Definitions survive (anything returns with .play). NOTE: this also
// fades the standing FX returns ~verb/~delay; revive them with ~verb.play if
// you keep going.
// Returns: the fade time.
hush(12);
hush(0.5);

// ---- rec ------------------------------------------------------------------
// rec(beats)  or  rec(beats, key)
// Live sampler: capture `beats` beats of the first sound input into a new MONO
// Buffer, appended to the sample dictionary d under `key` (default "live").
// Registered immediately, so you can write the pattern that plays it while it
// records. Play captures with a mono instrument (\bplaym).
// Returns: the new Buffer (or nil if the server is off).
rec(8);                                    // 8 beats into d["live"]
rec(16, "voice");                          // into d["voice"]
// ...then:
~g = \live.hits("x...", inst: \bplaym); ~g.play;

// ---- pad ------------------------------------------------------------------
// pad(\x)   pad(\y)
// The trackpad / mouse position as a control signal — a control-rate proxy in
// 0..1 (MouseX / MouseY, reads the pointer anywhere on screen, no window focus
// needed). Map it into a useful range with .mapExp / .mapLin.
// Returns: a control-rate NodeProxy.
~cut = pad(\x).mapExp(200, 8000);
~a.fx(\lpf, ~cut);                         // ride the filter with the trackpad


/* ============================================================================
   2. SPAWNERS
   A Symbol names material: a sample folder in d, a SynthDef, or a drone recipe.
   Every spawner returns a plain object (Pbind or Function).
============================================================================ */

// ---- hits -----------------------------------------------------------------
// \folder.hits(stepString, step=0.25, amp=1, inst=\bplay, buf=0, rot=0, accent=1.4)
// \folder.hits(k, n=8, amp=1, inst=\bplay, buf=0, rot=0)
// A drum / sample pattern from sample folder d[folder], as a Pbind. Two forms:
//
//  STEP-STRING form — \k.hits("x..X 0.2."):
//    x = hit, X = accent (amp * accent), a DIGIT = hit playing that numbered
//    sample variant of the folder, . = rest. Spaces and | are ignored (group
//    visually). `step` is beats per character (0.25 = sixteenths). Rests fold
//    into onset-to-onset durations; a leading rest is a real Rest (keeps the
//    offbeat placement).
//
//  EUCLIDEAN form — \k.hits(3, 8):
//    k hits spread as evenly as possible over n sixteenth-note steps
//    (Bjorklund), rotated by `rot`.
//
// Returns: a Pbind.
~k = \k.hits("x..x..x.");                  // syncopated kick, eighth grid
~h = \s.hits("x.xx", 0.25, amp: 0.6);      // sixteenths, quieter
~v = \s.hits("0.1. 0.11");                 // digits pick d["s"][0] and [1]
~sn = \s.hits(3, 8);                       // euclid: 3 over 8
~e  = \k.hits(5, 16, rot: 2);              // rotated euclid
// still a real Pbind — wrap it in anything:
~k = Pwrand([\k.hits(3, 8), \k.hits(5, 8)], [0.9, 0.1], inf);

// ---- deg ------------------------------------------------------------------
// \synth.deg(degrees, dur=0.5, oct=5, amp=0.3, scale, root=0)
// A melodic pattern of scale degrees on the SynthDef named by the symbol, as a
// Pbind. The SynthDef's pitch arg must be named `freq` (all Synesthesia voices
// qualify). Degree string: integers (negatives ok), [0 2 4] bracket chords,
// . or ~ for rests: "0 3 5 [0 2 4] . 7". `degrees` may also be an array.
// Scale defaults to n.scale, then d[\scale], then minor.
// Returns: a Pbind.
~m  = \mark.deg("0 3 5 7", 0.25);
~m2 = \brush.deg("0 . 3 . [0 2 4] .", 1, oct: 4);
~m3 = \mark.deg("-3 0 4 7", 0.25).fast(2); // transforms chain onto it

// ---- chord ----------------------------------------------------------------
// \synth.chord(symbols, dur=4, amp=0.3, oct=0)
// A harmony pattern from chord NAMES, via ChordSymbol2 (symbols embed directly
// in the \note stream). Names like \Cm7 or \Fm9_3 (name, optional octave digit
// / inversion after an underscore). `symbols` is a space-separated string or an
// array of Symbols.
// Returns: a Pbind.
~pads  = \brush.chord("Cm7 Fm9 Ab6 G7", 4);
~pads2 = \brush.chord("Cm7_3 Cm7_4", 8, oct: -1);

// ---- drone ----------------------------------------------------------------
// \recipe.drone(root=55, mult=1, wob=0.1, amp=0.3)
// A drone FUNCTION built from a recipe (see table §8): \dfm (self-oscillating
// filter, needs sc3-plugins), \tone (near-pure beating partial), \saw (detuned
// filtered saws). Unknown names fall back to \tone. Assign it to a proxy to
// sound it. `root` may be a proxy (~r — move it, the drone follows), a
// function, or a number. `wob` = internal modulation rate (Hz).
// Returns: a Function.
~r = {55};
~a = \tone.drone(~r);            ~a.play;
~b = \saw.drone(~r, 2, wob: 0.3, amp: 0.2); ~b.play;
~r = {65};                       // retune the root: both follow

// ---- stack ----------------------------------------------------------------
// \recipe.stack(root=55, mults=[1,2,4], wob=0.1, amp=0.3)
// Like .drone, but SUMS the recipe across an array of harmonic multiples inside
// one proxy — a chord of partials as a single sculptable object. Amplitude is
// divided across the partials.
// Returns: a Function.
~a = \dfm.stack(~r, [1, 2, 4, 6]); ~a.fade(8).play;
~a.fx(\lpf, 900);                  // sculpt the whole stack at once


/* ============================================================================
   3. STRING NOTATION
   Step strings as raw pattern material, for any \dur socket of a Pbind you
   write yourself (independent of the .hits word).
============================================================================ */

// ---- steps ----------------------------------------------------------------
// "x.x.".steps(step=0.25)
// The string as a looping duration Pseq. x (or X, or a digit) = onset, . = rest;
// spaces and | ignored. Rests fold into onset-to-onset durations; a leading rest
// becomes a Rest.
// Returns: a Pseq of durations.
~x = Pbind(\instrument, \mark, \degree, 0, \dur, "x..x..x.".steps);

// ---- stepAmps -------------------------------------------------------------
// "x.X.".stepAmps(step=0.25, amp=1, accent=1.4)
// The matching amplitude Pseq: X characters get amp*accent, plain hits get amp.
// Align it with .steps of the SAME string.
// Returns: a Pseq of amplitudes.
~x = Pbind(\instrument, \mark, \degree, 0,
    \dur, "x.Xx".steps, \amp, "x.Xx".stepAmps(amp: 0.4));


/* ============================================================================
   4. SCULPT — verbs on a proxy (NodeProxy). Each returns the proxy, so they
   chain. Effects insert in place on slots 10+ (your slots 0-9 stay yours).
   Numeric values are lifted to named controls, so .set / GUI / presets can
   reach them later.
============================================================================ */

// ---- fx -------------------------------------------------------------------
// ~a.fx(name, val)
// Insert (or retune) a named effect on this proxy, after its source and any
// earlier effects. Recipes and what `val` means: \lpf / \hpf = cutoff Hz;
// \verb / \delay = wet mix 0..1; \dist = drive 0..1; \crush = bitcrush 0..1
// (needs sc3-plugins); \wide = stereo width 0..2; \dc = DC blocker. `val` may
// be a number, a proxy, or a function.
// Returns: the proxy (chainable).
~a.fx(\lpf, 1200).fx(\verb, 0.3);          // two effects, chained
~a.fx(\lpf, 500);                          // same name retunes in place (crossfaded)
~a.set(\lpf_freq, 2000);                   // the lifted control is live
~a.fx(\lpf, pad(\x).mapExp(100, 8000));    // or drive it with a signal

// ---- unfx -----------------------------------------------------------------
// ~a.unfx(name)
// Remove a named effect added with .fx.
// Returns: the proxy.
~a.unfx(\verb);

// ---- wide -----------------------------------------------------------------
// ~a.wide(width=1)
// Stereo width via mid/side: 0 = mono, 1 = unchanged, up to 2 = exaggerated.
// Sugar for .fx(\wide, width).
// Returns: the proxy.
~a.wide(1.5);

// ---- dc -------------------------------------------------------------------
// ~a.dc
// Insert a DC blocker (LeakDC) — hygiene for feedback patches and chaotic
// sources. Sugar for .fx(\dc, 1).
// Returns: the proxy.
~a.dc;

// ---- fade -----------------------------------------------------------------
// ~a.fade(seconds=4)
// Set this proxy's crossfade time, returning the proxy so it chains with .play.
// From now on, re-assignments and stops use this fade.
// Returns: the proxy.
~a = \tone.stack(~r, [1, 2, 4]);
~a.fade(12).play;                          // long, painterly transitions


/* ============================================================================
   5. WIRE — topology between proxies.
============================================================================ */

// ---- feeds ----------------------------------------------------------------
// ~t.feeds(target, amt=0.2)
// Mix this proxy into another proxy's canvas at a low slot, so it passes
// THROUGH the target's whole fx chain. For layering sources into one sculptable
// object, or for deliberate feedback wiring.
// Returns: this proxy.
~t = \tone.drone(~r, 1.5); ~t.play;
~t.feeds(~a, 0.15);                        // ~t now lives inside ~a — ~a.fx sculpts the sum

// ---- route ----------------------------------------------------------------
// ~a.route(returnName=\verb, amt=0.3)
// Send this proxy to a standing effect return created in Setup: \verb expects
// ~verbIn / ~verb, \delay expects ~delayIn / ~delay. (Named `route`, not send,
// because NodeProxy already has a send method.)
// Returns: this proxy.
~k.route(\verb, 0.2);                      // a little reverb on the kick
~m.route(\delay, 0.5);                     // more delay on the melody

// ---- duck -----------------------------------------------------------------
// ~a.duck(source, amt=0.5, attack=0.01, release=0.25)
// Sidechain: dip this proxy's level by another proxy's amplitude envelope — the
// "kick carves the drone" move, and a bridge from the pattern world into the
// signal world. At amt 1 a loud source fully silences this proxy at its peak.
// Returns: this proxy.
~a.duck(~k, 0.6);
~a.set(\duck_amt, 1.2);                    // deepen it live


/* ============================================================================
   6. BRIDGE — cross between the signal world and the pattern world.
============================================================================ */

// ---- follow ---------------------------------------------------------------
// ~k.follow(lagTime=0.1)
// This proxy's amplitude envelope as a new control-rate proxy — the general
// pattern -> signal bridge. Use the result anywhere a signal fits: modulation,
// other proxies, fx values.
// Returns: a control-rate NodeProxy.
~env = ~k.follow;
~shimmer = { SinOsc.ar([2000, 2003]) * ~env.kr(1) * 0.1 }; ~shimmer.play;

// ---- pat ------------------------------------------------------------------
// ~c.pat
// This proxy's current control value as pattern material — the signal ->
// pattern bridge. Sugar for BenoitLib's Pkr(this) (BenoitLib must be installed).
// Returns: a pattern yielding the proxy's latest value.
~m = \mark.deg("0 3 5 7", 0.25, amp: pad(\y).pat.linlin(0, 1, 0.05, 0.5));

// ---- mapExp ---------------------------------------------------------------
// ~c.mapExp(lo=20, hi=20000)
// A new control proxy mapping a 0..1 signal EXPONENTIALLY into lo..hi — the
// right curve for frequencies and times.
// Returns: a new control-rate NodeProxy.
~cut = pad(\x).mapExp(200, 8000);

// ---- mapLin ---------------------------------------------------------------
// ~c.mapLin(lo=0, hi=1)
// As .mapExp but LINEAR — for amounts, mixes, pans.
// Returns: a new control-rate NodeProxy.
~amt = pad(\y).mapLin(0, 0.8);


/* ============================================================================
   7. TRANSFORM — verbs on event patterns. Each returns a NEW pattern, so they
   chain, and raw pattern classes compose around them.
============================================================================ */

// ---- fast -----------------------------------------------------------------
// pattern.fast(factor=2)
// Play faster by scaling every duration down. factor 2 = twice as fast.
// Returns: a new Pattern.
~h = \s.hits("x.xx", 0.25).fast(2);

// ---- slow -----------------------------------------------------------------
// pattern.slow(factor=2)
// The inverse of .fast. factor 2 = half speed.
// Returns: a new Pattern.
~m = \brush.deg("0 3 5 7", 0.25).slow(2);

// ---- sometimes ------------------------------------------------------------
// pattern.sometimes(prob=0.25, func, beats=4)
// Occasionally play a transformed variant: time is cut into windows of `beats`,
// and at each window a coin is flipped — with probability `prob` the window
// plays func.value(pattern), else the original. Controlled surprise that always
// resolves back to the source.
// Returns: a new Pattern.
~m = \mark.deg("0 3 5 7", 0.25).sometimes(0.2, _.fast(4));       // rare flurries
~k = \k.hits(3, 8).sometimes(0.1, { |p| p.jux(_.fast(2)) }, 8);

// ---- jux ------------------------------------------------------------------
// pattern.jux(func, spread=0.7)
// Juxtapose (after TidalCycles): the original panned one side, a transformed
// copy panned the other — instant stereo interplay from one idea.
// Returns: a new Pattern (a Ppar of the two copies).
~sn = \s.hits(3, 8).jux(_.fast(2));
~m  = \brush.deg("0 3 5 7", 0.5).jux(_.slow(2), spread: 1);


/* ============================================================================
   8. REFERENCE TABLES — the material the words name.
============================================================================ */

/*  INSTRUMENTS (SynthDefs in Setup/SynthDefs/) — what you name in deg / chord,
    and the default (\bplay) for hits. All speak the color contract hue/sat/val
    (0..1); brush is fully reworked to HSV geometry, the rest are provisional
    (renamed args, older behavior) pending their own rework.

      VOICES        family              hue / sat / val quick gloss
      \mark         percussive          hue=harmonic->bell->metal, val=FM index, sat=splash+drive
      \brush        sustained pad        hue=timbre wheel (wraps), sat=grey->vivid->neon, val=black->air
      \spray        grain (synthetic)    hue=grain FM ratio, val=index, sat=scatter/rain
      \sprayb       grain (buffer, MONO) hue=position wander, val=tilt, sat=scatter  (rec() captures)
      \wash         texture bed          hue=air->comb->modal, val=color+tilt, sat=crackle+movement

      DRUMS         \kick \snare \hat \tom \metal   (hue/sat/val provisional; see each file header)

      PLAYERS       \bplay (stereo, default for hits) · \bplaym (mono, for rec captures)

    Common event keys any voice takes via deg/chord/hits or a raw Pbind:
      \freq or \degree+\scale+\root+\octave · \dur · \amp · \pan · \legato (gated voices)
      \hue \sat \val (0..1) · plus per-voice extras (brush: \sub \air \fenv \track \drift \bow \smear)
*/

/*  DRONE RECIPES (used by .drone / .stack):
      \dfm    self-oscillating DFM1 filter (needs sc3-plugins) — rich, vocal
      \tone   near-pure partial with slow beating — clean, glassy
      \saw    detuned filtered saw pair — warm, analog
    args on all three: (root, mult, wob, amp).  wob = internal LFO rate (Hz).
*/

/*  FX RECIPES (used by .fx):
      \lpf   resonant lowpass    val = cutoff Hz        (default 800)
      \hpf   resonant highpass   val = cutoff Hz        (default 200)
      \verb  reverb              val = wet mix 0..1     (default 0.3)
      \delay comb delay          val = wet mix 0..1     (default 0.3; \delay_time control)
      \dist  tanh drive          val = drive 0..1       (default 0.3)
      \crush bitcrush            val = amount 0..1      (needs sc3-plugins)
      \wide  mid/side width      val = 0..2             (also the .wide word)
      \dc    DC blocker          (also the .dc word)
*/

/*  JITLIB VERBS you'll lean on (not Synesthesia words, but part of speaking):
      ~a.play         start monitoring a proxy's output
      ~a.stop(t)      fade out over t seconds, KEEP the proxy (and its effect on others)
      ~a.clear(t)     free it entirely
      ~a = { ... }    (re)assign a source — crossfades over the proxy's fadeTime
      ~a.set(\k, v)   set any named control live (e.g. a lifted fx value)
      ~a.vol_(0.7)    per-proxy level
      p.clear         free the whole space
    And the escape hatch, always open — raw SC lands on the same canvas:
      ~x = { DFM1.ar(SinOsc.ar([~r.kr, ~r.kr*1.01]), ~r.kr*2, 1.1, 1) * 0.3 };
*/


/* ============================================================================
   A 12-LINE SENTENCE, to see the words in motion (evaluate line by line):

     bpm(126); grid(4);
     ~r = {50};
     ~a = \tone.stack(~r, [1, 2, 4]); ~a.fade(8).play;
     ~a.fx(\lpf, 700).fx(\verb, 0.3);
     ~k = Pbind(\instrument, \kick, \freq, 50, \dur, 1); ~k.play; // one kick per beat
                                                    // (drums take \freq — .deg would pitch a kick to middle C)
     ~a.duck(~k, 0.6);                              // the kick carves the drone
     ~h = \s.hits("x.xx", 0.25).fast(2); ~h.play;   // (needs a sample folder "s")
     ~m = \mark.deg("0 3 5 [0 2 4]", 0.5).sometimes(0.2, _.fast(4)); ~m.play;
     ~a.fx(\lpf, pad(\x).mapExp(150, 8000));        // trackpad rides the filter
     ~r = {57};                                     // move the root — the canvas shifts
     hush(20);
============================================================================ */
