/*
VOCABULARY SKETCH — design fiction; Phase 1 words are now REAL (Synesthesia quark).
Two renames landed in implementation: .send -> .route (NodeProxy:send already
exists in JITLib) and .exp/.lin -> .mapExp/.mapLin (math-operator collision).
knob()/dseq/colors remain future phases.
Paradigm: the patch is the canvas, patterns are brushes.
Rule: every terse form evaluates to a plain SC object (Function, Pbind, NodeProxy),
so raw SC composes with it anywhere.

Mechanisms assumed: personal quark of class extensions —
  + Symbol (sound spawners), + String (notation), + NodeProxy (sculpt/route verbs),
  + Pattern/Pbind (transform verbs), + Interpreter (bare control words like hush()).
No preprocessor. Everything below is legal sclang syntax.
*/

// ============================================================
// 0. CONTROL WORDS (bare words — Interpreter extensions)
// ============================================================

bpm(120);           // p.clock.tempo = 2
grid(4);            // default quant: rebinds land on the next bar
hush(20);           // fade the whole canvas to silence over 20s (the musical panic)
rec(8);             // capture 8 beats of SoundIn -> d["live"] (live sampler)

// ============================================================
// 1. GRAPH WORDS — the canvas (inspiration: Help 5, drones/modular)
// ============================================================

~r = {50};                          // the root, as a signal (co34pt convention, kept)

// -- spawners: Symbol -> Function (assign to a proxy to make it sound)
~a = \dfm.drone(~r);                // self-oscillating DFM1 drone at the root
~b = \dfm.drone(~r, 2, wob: 0.3);   // 2nd harmonic, wider slow modulation
~c = \dfm.stack(~r, [1, 2, 4, 6]);  // one proxy, four harmonics summed
~t = \tone.drone(~r, 1.5, drift: 0.02); // near-fifth partial, slow pitch drift

~a.fade(12).play;                   // fadeTime 12, then monitor

// -- sculpt verbs (NodeProxy extensions; insert via NodeProxy roles \filterIn)
~a.fx(\lpf, 800);                   // insert filter in-place, next free slot
~a.fx(\verb, 0.3);                  // insert reverb, wet 0.3
~a.unfx(\verb);                     // remove it
~a.wide(0.4);                       // stereo spread
~a.dc;                              // LeakDC
~a.vol_(0.7);                       // exists already (JITLib)

// -- routing verbs
~t.feeds(~a, 0.15);                 // mix ~t into ~a's input, scaled (feedback wiring)
~a.send(\verb, 0.4);                // to the standing return built in Setup
// JITLib already has chaining operators worth keeping in the fingers:
// ~src <>> ~flt   (play src into flt's \in)

// raw SC remains a first-class brushstroke on the same canvas:
~a = {DFM1.ar(SinOsc.ar([~r.kr, ~r.kr*1.01]), ~r.kr*2, 1.1, 1) * 0.3};

// ============================================================
// 2. TIME WORDS — the brushes (patterns opt into the grid)
// ============================================================

// -- step notation: String -> duration/amp pattern
//    x = hit, X = accent, . = rest, digits = sample-variant index
~k  = \k.hits("x..x..x.");                  // bplay kick from d["k"][0], 8th-note steps
~sn = \s.hits(3, 8);                        // euclid overload (Pbjorklund2 under the hood)
~hh = \ch.hits("x.xx", 0.25, amp: 0.6);     // 16th-note grid
~pk = \pk.hits("0...2..1");                 // digits pick d["pk"][n]

// -- melodic: degree strings through the scale machinery (n.scale convention)
~mel = \sinfb.deg("0 3 5 7", 0.5, oct: 3, fb: 0.4);
~pad = \bpfsaw.deg("[0 2 4]", 4, oct: 4);   // brackets = chord

// -- transform verbs (Pattern/Pbind extensions -> new patterns; escape hatch intact)
~hh  = ~hh.fast(2);
~mel = ~mel.slow(2).sometimes(0.2, _.fast(4));  // occasional double-time flurry
~sn  = ~sn.jux(_.fast(2));                      // straight left, varied right

// because \k.hits(3,8) IS a Pbind, raw pattern classes still wrap it:
~k = Pwrand([\k.hits(3, 8), \k.hits(5, 8)], [0.9, 0.1], inf);

// ============================================================
// 3. BRIDGE WORDS — where this language does what Tidal can't
// ============================================================

// pattern -> signal: the drums carve the drone
~a.duck(~k, 0.6);                   // sidechain: ~a dips by ~k's amplitude envelope
~env = ~k.follow;                   // or take the envelope itself as a signal

// signal -> pattern: knobs and signals inside patterns
~cut = knob(1).exp(200, 8000);      // MIDI CC1, lagged, exponential mapping
~a.fx(\lpf, ~cut);                  // same signal sculpts the canvas...
~hh = \ch.hits("x.xx", 0.25, amp: ~cut.pat.linlin(200, 8000, 0.2, 1)); // ...and the brush

// sequence AS signal: demand-rate — the most literal "programming the speaker"
~arp = \saw.dseq("0 7 12 19", 6, ~r);   // pitch sequence running at 6 Hz, audio-side
~arp.fx(\verb, 0.5).play;               // it's a proxy like any other: patchable

// capture -> canvas
rec(8);                                  // ...play piano into the mic...
~g = \live.grains(rate: 0.5, pos: knob(2));  // granulate the capture (warp1 sugar)
~g.play;

// ============================================================
// 4. WHAT A SET OPENING LOOKS LIKE (~90 seconds, ~15 evaluations)
// ============================================================

~r = {50};
~a = \dfm.stack(~r, [1, 2, 4]); ~a.fade(12).play;
~a.fx(\lpf, knob(1).exp(100, 6000));
~t = \tone.drone(~r, 1.5, drift: 0.02); ~t.play;
~t.feeds(~a, 0.15);

bpm(120); grid(4);
~k = \k.hits("x..x..x."); ~k.play;
~a.duck(~k, 0.5);                       // pulse emerges from inside the drone

~arp = \saw.dseq("0 7 12 19", 6, ~r); ~arp.fx(\verb, 0.5).play;

rec(8);                                  // capture a phrase
~g = \live.grains(pos: knob(2)); ~g.play;

~r = {55};                               // move the root: entire canvas shifts
hush(30);                                // long exit

/*
IMPLEMENTATION REALITY (for later):
- Thin sugar (1-10 lines each, over existing JITLib/co34pt conventions):
  drone/stack spawners, .fade, .wide, .dc, .send, .feeds, .follow, .duck,
  bpm/grid/hush/rec, knob (MIDI-in layer from Design Notes #1), .exp/.lin maps.
- Real (small) parsers: hits-string (~30 lines), deg-string (~40 lines; chords via
  brackets, later maybe <> alternation via Ppatlace).
- Real bookkeeping: .fx/.unfx slot management on NodeProxy roles.
- Transform verbs: .fast/.slow scale durs; .sometimes wraps in Pwrand;
  .jux = Ppar of panned copies. (True rev/backtracking needs pure patterns — out of
  scope; not our ontology.)
- .play override (or spawners) auto-register an analysis tap per proxy ->
  the visuals pipeline gets per-part data with zero extra commands (Design Notes,
  visuals tap #2).
- Quark needs a name; class extensions need no prefix, real classes do.
*/
