/* ============================================================================
   SYNESTHESIA TUTORIAL — everything built so far, in playing order

   Work DOWN the file. Put the cursor on a line and press Shift-Return to run
   it, or anywhere inside a ( ... ) block and press Cmd-Return to run the whole
   block. Every lesson builds on the one above it, so skipping ahead works but
   some lines expect a proxy an earlier lesson made.

   Each lesson has:
     LISTEN  what you should hear
     WATCH   what arrives in TouchDesigner (an OSC In DAT on the port you
             chose shows every message as a row; an OSC In CHOP turns the
             numeric ones into channels)

   Panic: Cmd-. stops everything instantly (rough). hush(4) fades it (musical).

   Every line in this file is checked by Setup/TutorialCheck.scd, which plays
   the file top to bottom on a real server and measures that each lesson
   makes sound and sends the OSC it says it does. If a line here stops
   working, that check fails first.

   Material used: the one-shot packs from the sample library (d["k"], d["s"],
   d["cp"], d["perc"]), the SynthDefs in Setup/SynthDefs/ (\mark \brush \wash
   \spray \kick \snare \hat \tom \metal), and loops from the breaks library.
   The names \amen, \ping, \sinfb and \bpfsaw in the quark's help pages are
   NOT in this setup — that is why some help examples stay silent here.
============================================================================ */


/* ============================================================================
   LESSON 0 — BOOT, AND OPEN THE LINE TO TOUCHDESIGNER
============================================================================ */

// Boot everything: server, ProxySpace (p), samples (d), SynthDefs, breaks
// library, limiter, the ~verb and ~delay returns. Wait for "Setup done!".
"Setup/Setup.scd".loadRelative;

// Start streaming to TouchDesigner on this Mac. Use the port your OSC In
// operator listens on. stems: false because stems need a BlackHole
// aggregate device; the OSC streams don't.
Broadcast.start(NetAddr("127.0.0.1", 10000), stems: false);

// What is it doing? Address, streams, which control proxies it is tapping.
Broadcast.status;

// WATCH  /syn/alive ticks once a second (seconds since start) — the line is up.
//        /syn/tempo and the phases (/syn/bar, /half, /quarter, /eighth, /sixteenth)
//        start straight away: the clock is always running, even in silence. /syn/kr/tempo
//        is the same tempo again, in beats per SECOND — JITLib's own ~tempo proxy, and
//        every control proxy streams (lesson 6).


/* ============================================================================
   LESSON 1 — THE FRAME: TEMPO AND GRID
============================================================================ */

// Tempo in BPM. Everything follows, including breaks recorded at other tempos.
bpm(96);

// Edits land on the next bar (4 beats). This is why nothing seems to happen
// for a moment after you evaluate: it is waiting for the downbeat.
grid(4);

// WATCH  /syn/tempo reads 96.
//        /syn/bar ramps 0 -> 1 once per BAR (4 beats) and drops back; /syn/half,
//        /syn/quarter, /syn/eighth and /syn/sixteenth do the same per note value, bar-aligned.


/* ============================================================================
   LESSON 2 — DRUMS FROM SAMPLES: .hits
   \folder.hits("...") plays the sample folder d[folder] in step notation.
     x  hit      X  accent      0-9  hit, using that sample in the folder
     .  rest     spaces and |  only for your eyes
   One character is a sixteenth note (step 0.25 beats) unless you say otherwise.
============================================================================ */

~k = \k.hits("x.....x...x.....");    // kick
~k.play;

~s = \s.hits("....x.......x...");    // snare on 2 and 4
~s.play;

~h = \perc.hits("x.x.x.xXx.x.x.xX", amp: 0.5);   // percussion, accents on the X
~h.play;

// Re-evaluate a proxy to change it. It switches on the next bar, crossfaded.
~k = \k.hits("x..x..x...x..x..");

// Digits choose WHICH sample in the folder: d["k"] has 83 kicks.
~k = \k.hits("0..0..5...0..5..");

// The Euclidean form: 5 hits spread as evenly as possible over 16 steps.
~cp = \cp.hits(5, 16, amp: 0.5, rot: 2);
~cp.play;

// LISTEN a four-on-the-floor-ish groove with claps rolling over the top.
// WATCH  /syn/hit/k/…, /syn/hit/s/…, /syn/hit/perc/…, /syn/hit/cp/… — per hit: /amp,
//        /index (which sample in the folder played), /dur, and /count going up by one.
//        Accents arrive with a higher amp (1.4x). They land on the sound,
//        not ahead of it.


/* ============================================================================
   LESSON 3 — THE ESCAPE HATCH: RAW SUPERCOLLIDER
   Every word returns a plain Pbind / Function / NodeProxy. Raw SC composes
   with it freely — but only the words tag their events for Broadcast.
============================================================================ */

// A synthesised kick under the samples, as an ordinary Pbind.
// (Drums take \freq — a .deg would pitch a kick to middle C.)
~sk = Pbind(\instrument, \kick, \freq, 45, \dur, 2, \amp, 0.5);
~sk.play;

// LISTEN a deep sub thump on beats 1 and 3.
// WATCH  nothing new! A hand-written Pbind carries no Synesthesia tags, so
//        Broadcast doesn't know what it is. Use the words for anything the
//        VJ should see.

~sk.stop(2);                          // fade it out over 2 s; the proxy stays


/* ============================================================================
   LESSON 4 — MELODY: .deg
   \synthdef.deg("degrees", dur) plays scale degrees on a SynthDef.
   Integers (negatives fine), [0 2 4] = a chord, . or ~ = rest.
============================================================================ */

~m = \mark.deg("0 3 5 7 . 5 3 [0 4]", 0.5, oct: 5, amp: 0.25);
~m.play;

// Change the scale and root (root in semitones above C).
~m = \mark.deg("0 3 5 7 . 5 3 [0 4]", 0.5, oct: 5, amp: 0.25, scale: Scale.dorian, root: 2);

// Faster notes: dur is beats per note.
~m = \mark.deg("0 2 4 7 9 7 4 2", 0.25, oct: 6, amp: 0.2, scale: Scale.majorPentatonic);

// LISTEN a bright, bell-ish line (\mark is the percussive voice).
// WATCH  /syn/note/mark/amp, /pitch (the lowest MIDI note), /notes (every note of a
//        bracket chord in one message), /size, /degree, /degrees, /dur (beats), /count.


/* ============================================================================
   LESSON 5 — HARMONY AND COLOUR: .chord, and hue / sat / val
   \synthdef.chord("names", dur) plays named chords, written as on a chart:
     Cm7  G7  Abmaj7  F#m7b5  Csus4  C/E (bass note)  Cm7_4 (an octave down)  . (rest)
   A name it cannot read is an error that names it.
   Every voice in Setup/SynthDefs speaks a colour contract: hue, sat, val, 0..1.
============================================================================ */

~pad = \brush.chord("Cm7 Fm9 Abmaj7 G7", 4, amp: 0.15);
~pad.play;

// Raw SC again: Pbindf adds keys to an existing Pbind. The tags survive, so
// Broadcast still sees this one.
~pad = Pbindf(\brush.chord("Cm7 Fm9 Abmaj7 G7", 4, amp: 0.15), \hue, 0.62, \sat, 0.35, \val, 0.5);

// Patterns inside: hue walks the colour wheel, one step per chord.
~pad = Pbindf(\brush.chord("Cm7 Fm9 Abmaj7 G7", 4, amp: 0.15), \hue, Pseq([0.1, 0.35, 0.6, 0.85], inf));

// LISTEN a soft pad under everything, its timbre turning with each chord.
// WATCH  /syn/note/brush/notes carries all four notes of each chord; /pitch is the
//        lowest. (Hue is not in /syn/note — paint with lesson 14's words and it is.)


/* ============================================================================
   LESSON 6 — DRONES AND THE ROOT: .drone, .stack
   A drone is a Function on a proxy, not a pattern. Give it a ROOT that is
   itself a proxy, and you can move everything built on it at once.
============================================================================ */

~r = { 55 };                          // the root: a control signal at 55 Hz

~a = \dfm.drone(~r, amp: 0.2);        // self-oscillating filter
~a.play;

~b = \saw.drone(~r, 2, wob: 0.3, amp: 0.1);   // detuned saws an octave up
~b.play;

// Move the root: both drones follow, smoothly.
~r = { 49 };

// A stack: one proxy holding several harmonics of a recipe.
~b = \tone.stack(~r, [2, 3, 4, 6], amp: 0.15);

// Or make the root MOVE on its own:
~r = { LFNoise1.kr(0.1).range(45, 60) };

// LISTEN a low drone bed, drifting in pitch.
// WATCH  /syn/kr/r — the root, 30 times a second, in Hz. Every control-rate
//        proxy you make appears like this on its own, within a bar.
//        No /syn/krn/r: that 0..1 twin needs a Spec. Register one and it appears:
Spec.add(\r, [40, 70, \exp]);


/* ============================================================================
   LESSON 7 — SCULPTING ONE SOUND: .fx, .unfx, .wide, .dc, .fade
   Effects go IN the proxy, after its source. Each returns the proxy, so they
   chain. Numbers become live named controls.
============================================================================ */

~a.fx(\lpf, 600);                     // lowpass at 600 Hz
~a.fx(\lpf, 300).fx(\dist, 0.4);      // retune it, and add drive
~a.set(\lpf_freq, 1200);              // the named control, set directly
~a.wide(1.6);                         // stereo width (0 mono .. 2 wide)
~a.unfx(\dist);                       // remove an effect
~a.dc;                                // DC blocker: hygiene for feedback/chaos

~m.fx(\delay, 0.3);                   // effects work on patterns' proxies too
~h.fx(\hpf, 2000);                    // thin the percussion

// fade sets how long this proxy crossfades when you re-assign or stop it.
~b.fade(10);
~b = \saw.stack(~r, [2, 3], amp: 0.1);   // a slow, ten-second morph

// LISTEN the drone darkening, then opening up, getting wider.
// WATCH  nothing new — effects shape the sound, not the event stream.


/* ============================================================================
   LESSON 8 — WIRING SOUNDS TOGETHER: .route, .duck, .feeds
============================================================================ */

~s.route(\verb, 0.4);                 // send the snare to the standing reverb
~m.route(\delay, 0.5);                // the melody to the standing delay
~a.duck(~k, 0.7);                     // the kick carves a hole in the drone
~b.duck(~k, 0.5);

// feeds: put one proxy INSIDE another, so it goes through the other's effects.
~t = \tone.drone(~r, 3, amp: 0.1);
~t.feeds(~a, 0.3);                    // ~t now passes through ~a's lowpass

// LISTEN the drone pumping with the kick; the snare and melody in space.


/* ============================================================================
   LESSON 9 — BRIDGES: signals <-> patterns, and the trackpad
============================================================================ */

// The kick's loudness, as a control signal you can use anywhere.
~kenv = ~k.follow;
~shimmer = { SinOsc.ar([2400, 2407], 0, 0.04) * ~kenv.kr };
~shimmer.play;

// The trackpad, 0..1, mapped into useful ranges.
~cut = pad(\x).mapExp(200, 6000);     // left-right: filter cutoff
~a.fx(\lpf, ~cut);                    // move your finger across the trackpad
~lvl = pad(\y).mapLin(0.05, 0.4);     // up-down: an amount

// A signal read back INTO a pattern (.pat): the trackpad's height sets the
// melody's loudness, note by note.
~m = \mark.deg("0 2 4 7 9 7 4 2", 0.25, oct: 6, amp: pad(\y).pat.linlin(0, 1, 0.05, 0.35),
	scale: Scale.majorPentatonic);

// Give the VJ clean 0..1 versions of the names you chose:
Spec.add(\cut, [200, 6000, \exp]);
Spec.add(\lvl, [0.05, 0.4]);

// LISTEN shimmer that pulses with the kick; the drone filter under your finger.
// WATCH  every control proxy streams, under the name you gave it:
//          /syn/kr/kenv   the kick envelope, 0..1-ish (pump a visual with this)
//          /syn/kr/cut    200..6000      and, after the Spec.add, /syn/krn/cut 0..1
//          /syn/kr/lvl    0.05..0.4      and /syn/krn/lvl 0..1
//        You will ALSO see the helpers these words make on the way, under
//        generated names: /syn/kr/k_env (what .follow made — kenv is a copy),
//        /syn/kr/syn_padx and syn_pady (the raw trackpad, 0..1), and
//        /syn/kr/syn_sig1, syn_sig2 (the mapExp/mapLin results). Those have
//        /syn/krn twins because the words register Specs under THEIR names.
//        Rule of thumb: name what you want the VJ to use, and give it a Spec.
//        (Tidying the generated names is on the naming-convention list.)


/* ============================================================================
   LESSON 10 — TRANSFORMING PATTERNS: .fast .slow .sometimes .jux
============================================================================ */

~h = \perc.hits("x.x.x.xXx.x.x.xX", amp: 0.5).fast(2);         // double time
~h = \perc.hits("x.x.x.xXx.x.x.xX", amp: 0.5).sometimes(0.3, _.fast(2));  // now and then
~cp = \cp.hits(5, 16, amp: 0.5).jux(_.slow(2));                // left normal, right half speed

// LISTEN hats that occasionally burst into double time; claps split L/R.


/* ============================================================================
   LESSON 11 — BREAKS: a drum loop as one sculptable voice
   ~x.brk(\name) puts a loop on a proxy, locked to YOUR tempo whatever tempo
   it was recorded at. The library is indexed at boot and each loop loads the
   first time it plays.
============================================================================ */

// Make room: the sample drums out, the break in.
~k.stop(4); ~s.stop(4); ~h.stop(4); ~cp.stop(4);

// Find material. The 'from' column says how the tempo was worked out:
// filename (reliable), folder, duration (a guess), fallback (a bigger guess).
Break.list("monosole");

~br.brk(\b92bpm_2);                   // a 92 bpm loop, played at 96
~br.play;
~a.duck(~br, 0.6);                    // the drone now ducks to the break

// grind: HOW BIG THE PIECES ARE. 0 = the whole loop, 0.5 = sixteenth slices,
// 1 = dust. On its own it is nearly silent, by design — the pieces still play
// in order. It sets the resolution the other gestures work at.
~br.grind(0.5);

~br.seq("0.32 0.76 0123 4.4.");       // re-order the slices (digits = slice numbers)
~br.scr(0.3);                         // 30% of slices chosen at random
~br.mask(11, 16);                     // keep 11 of 16 slices, Euclidean
~br.ord;                              // back to the original order (resets scr too)
~br.mask(16, 16);                     // and every slice again

~br.over(0.5);                        // grains shorter than their slot: gated, choppy
~br.over(1);                          // back to butt-joined
~br.roll(4);                          // stutter each slice 4 times
~br.roll(1);                          // release
~br.speed(-1);                        // backwards
~br.speed(1);

~br.grind(0.92).jit(0.5);             // dust: tiny grains, scattered
~br.grind(0.5).jit(0);                // and back

~br.brk(\monosole_95bpm_16);          // SWAP to another loop on the next bar, no gap
~br.brk;                              // no name: the next loop in the library

// LISTEN the loop chopped, rearranged, stuttered, dusted — always on the grid.
// WATCH  nothing on /syn/hit: a .brk voice is one continuous sound, not
//        events. (It would arrive as an audio stem.) For events, chop it:

// .chop: the same loop as a PATTERN of slices — one event per slice.
~ch = \b92bpm_2.chop("0.3. 2.1. 0.33 7654", amp: 0.6);
~ch.play;

// WATCH  /syn/hit/b92bpm_2/amp, /index (the slice number) and /count, once per slice played.


/* ============================================================================
   LESSON 12 — ENDINGS
============================================================================ */

~ch.stop(4);
hush(8);                              // fade EVERYTHING over 8 seconds

// hush also faded the standing returns. If you carry on, revive them:
~verb.play; ~delay.play;

// WATCH  hush silences the sound, but the control streams keep flowing:
//        /syn/kr/r, cut, lvl... are signals, not sounds, so nothing fades them.

// .stop keeps a proxy; .clear removes it.
~shimmer.clear;                       // an audio proxy: frees its stem (if stems are on)
~lvl.clear;                           // a control proxy: its stream ends

// WATCH  /syn/gone/lvl, once — the VJ's cue that this stream has ended.
//        (Audio proxies have no /syn/gone; they leave the /syn/stems table.)

// Stop streaming. The music is untouched — this never changes a sound.
Broadcast.stop;


/* ============================================================================
   LESSON 13 — LIVE SAMPLING (needs a microphone; not checked automatically)
============================================================================ */

// Record 8 beats from the first input into d["live"], then play it back.
// The pattern can be written while it records.
rec(8);
~g = \live.hits("x...x.x.", inst: \bplaym);   // \bplaym: captures are mono
~g.play;


/* ============================================================================
   LESSON 14 — PAINTING: colours and tools
   The painting register says the same things in a painter's words. A colour is
   hue / sat / val (the axes every voice in Setup/SynthDefs speaks) plus a spread,
   and the tubes are named after the screen colour wheel: Paint.colors. A tool is
   one voice applied in time: brush mark dab drip spray wash. Pigment × applicator:
   \orange.brush("Cm7 G7"). Pitch and time stay music words. Every stroke is a
   plain Pbind and every move a Pbindf, so you can drop the register any time.
   Tutorial-Paint.scd is the long version: every way to use the register.
============================================================================ */

Broadcast.start(NetAddr("127.0.0.1", 10000));   // lesson 12 stopped it; the VJ is back
~r = { 55 };                                     // the root again, for the beds below

Paint.colors.postln;                             // the tubes

~pad = \orange.brush("Cm7 Fm9 Abmaj7 G7", 4, amp: 0.15);
~pad.play;

// LISTEN the pad from lesson 5, now orange: the warm, saw end of the brush's wheel.
// WATCH  /syn/paint/brush/amp, /pitch, /notes (all four), /size, /dur, /hue (near 0.08),
//        /sat, /val and /count. The colour's coordinates are its screen colour: draw them.

~pad = \orange.brush("Cm7 Fm9 Abmaj7 G7", 4, amp: 0.15).darker(0.3);

// LISTEN the same chords with the filter closing: darker is a move on val.

~pad.cooler(0.2);                                // move the running proxy: hue toward blue
~pad.paler;                                      // and toward grey

// WATCH  /syn/paint/brush/hue and /sat change on the next bar.

~m = \blue.mark("0 3 5 7", 0.25, amp: 0.2);
~m.play;

~t = \red.dab("x..x", 0.5, amp: 0.3);           // rhythmic touches on one note
~t.play;

~dr = \violet.drip(2, "0 3 5 7", amp: 0.2);     // sparse touches, random timing and notes
~dr.play;

// WATCH  /syn/paint/mark/count, /syn/paint/dab/count, /syn/paint/drip/count — drip's rises irregularly.

~bed = \grey.wash(~r, amp: 0.15);                // a bed at the root
~bed.fade(4).play;

~cloud = \cyan.spray(~r, dens: 25, amp: 0.15);  // a grain cloud at the root
~cloud.fade(4).play;

// LISTEN wash and spray both sit on ~r: move the root and both follow.
// WATCH  /syn/paint/wash/count every 16 beats and /syn/paint/spray/count every 4.

~bed = \grey.mix(\blue, 0.5).wash(~r, amp: 0.15);   // a pigment between two tubes

~k = \k.hits("x.x.").paint(\red);                // a colour on an engineering word:
~k.play;                                         // the sample player ignores it, harmlessly

// Drop the register: a stroke is a Pbind like any other.
~m = \blue.mark("0 3 5 7", 0.25, amp: 0.2).fast(2).jux(_.slow(2));

// When you are done, end the set as lesson 12 did: hush(8), then Broadcast.stop.
