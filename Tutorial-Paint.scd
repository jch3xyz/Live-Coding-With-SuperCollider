/* ============================================================================
   TUTORIAL — PAINTING: the colour register, every way to use it

   The painting register says what the engineering words say, in a painter's
   words. A COLOUR is a timbre: hue / sat / val, 0..1, the axes every voice in
   Setup/SynthDefs speaks (hue an angle on the voice's timbre wheel, sat its
   identity from grey to vivid to neon, val its light from black to air), plus a
   spread, because pigment is never flat. A TOOL is one voice applied in time.
   Pigment × applicator:  \orange.brush("Cm7 G7").  Pitch and time stay music
   words. Every stroke is a plain Pbind and every move a Pbindf, so the register
   is never a wall: drop it whenever raw SuperCollider says it better.

   Like Tutorial.scd: run Setup first, then one lesson at a time, one statement
   per Shift-Enter. LISTEN lines say what to hear; WATCH lines say what the VJ's
   machine receives. Setup/TutorialCheck.scd plays this file too
   (SYN_TUTORIAL=Tutorial-Paint.scd).
============================================================================ */


/* ============================================================================
   LESSON 0 — BOOT, THE TUBES, AND ONE COLOUR ACROSS A WHEEL
   Paint.colors lists the palette. The tubes are named after the screen colour
   wheel, because a colour's timbre coordinates ARE its screen colour.
============================================================================ */

"Setup/Setup.scd".loadRelative;              // once per session (TutorialCheck loads it itself)

Broadcast.start(NetAddr("127.0.0.1", 10000));   // the VJ: TouchDesigner's OSC In on 10000
bpm(90);
~r = { 55 };                                     // the root the beds will sit on

Paint.colors.postln;                             // red orange yellow green cyan blue violet magenta grey white black
Paint.palette[\orange].postln;                   // a tube is hue / sat / val / spread / name

~pad = \orange.brush("Cm7 Fm9 Abmaj7 G7", 4, amp: 0.15);
~pad.play;

// LISTEN orange on the brush: the warm, saw end of its wheel.
// WATCH  /syn/paint/brush/trig pulses per chord; /notes (all four, lowest first), /amp, /dur, /hue (near 0.08), /sat, /val.

~pad = \blue.brush("Cm7 Fm9 Abmaj7 G7", 4, amp: 0.15);

// LISTEN the same chords, blue: further round the wheel (sync / vowel territory).

~pad = \grey.brush("Cm7 Fm9 Abmaj7 G7", 4, amp: 0.15);

// LISTEN grey: sat near 0 collapses the wheel to a veiled wash. Hue barely matters.

~pad = \white.brush("Cm7 Fm9 Abmaj7 G7", 4, amp: 0.12);

// LISTEN white: low sat, high val — air and noise-brilliance.

~pad = \black.brush("Cm7 Fm9 Abmaj7 G7", 4, amp: 0.2);

// LISTEN black: val near 0 closes the filter under the fundamental — the dark thump
//        every hue converges to.


/* ============================================================================
   LESSON 1 — WHAT A COLOUR IS, AND THE WAYS TO WRITE ONE
   A palette name is sugar. Anywhere a colour goes you may write the coordinates.
============================================================================ */

~pad = Paint.color(0.62, 0.7, 0.4).brush("Cm7 G7", 4, amp: 0.15);   // numbers: hue sat val

// LISTEN identical to blue — those are blue's coordinates.

~pad = Paint.brush([0.62, 0.7, 0.4], "Cm7 G7", 4, amp: 0.15);      // an array, colour first
~pad = (hue: 0.62, sat: 0.7, val: 0.4).brush("Cm7 G7", 4, amp: 0.15);   // an event
~pad = Paint.color(Color.new(0.2, 0.3, 0.9)).brush("Cm7 G7", 4, amp: 0.15);   // a Color, through HSV

// The spread: each event draws its own hue/sat/val from a neighbourhood of the tube.
~m = Paint.color(0.1, 0.7, 0.5, 0.0).mark("0 3 5 7", 0.25, amp: 0.2);   // flat pigment
~m.play;

~m = Paint.color(0.1, 0.7, 0.5, 0.3).mark("0 3 5 7", 0.25, amp: 0.2);   // wide spread

// LISTEN every note a different timbre around the same colour.
// WATCH  /syn/paint/mark/hue varying by ±0.3 with every /trig.

~m = brush(\orange, "0 3 5 7", 0.5, amp: 0.15);   // call syntax: the same expression as \orange.brush

~pad.stop(4); ~m.stop(4);


/* ============================================================================
   LESSON 2 — THE BRUSH: a sustained stroke
   brush(notes, dur, amp, at, legato, oct). notes is chord names, degrees or a
   step string; dur is beats per note. at is placement — pan, patternable.
============================================================================ */

~pad = \orange.brush("Cm7 Fm9 Abmaj7 G7", 4, amp: 0.15);        // chord names, as on a chart
~pad.play;

~pad = \orange.brush("0 3 5 7", 1, amp: 0.15);                   // scale degrees
~pad = \orange.brush("0 3 5 7", 1, amp: 0.15, legato: 0.4);      // shorter strokes
~pad = \orange.brush("x..x x.x.", 0.5, amp: 0.15);               // a step string: one note, in rhythm
~pad = \orange.brush("Cm7 G7", 4, amp: 0.15, oct: 4);            // an octave down
~pad = \orange.brush("Cm7 G7", 4, amp: 0.15, at: -0.7);          // placed left
~pad = \orange.brush("0 3 5 7", 0.5, amp: 0.15, at: Pseq([-1, 1], inf));   // placement patterned

// LISTEN notes alternating left and right: placement belongs to the stroke, not the pigment.

~pad.stop(4);


/* ============================================================================
   LESSON 3 — MARK, DAB, DRIP: three ways to touch with one voice
   mark = discrete pitched events. dab = rhythmic touches on one note. drip =
   sparse, random touches. All three own the \mark voice.
============================================================================ */

~m = \blue.mark("0 3 5 7", 0.25, amp: 0.2);           // a line
~m.play;

~m = \blue.mark("Cm7 G7", 1, amp: 0.2);               // chords, as stabs
~m = \blue.mark("0 . 3 . [0 2 4] .", 0.25, amp: 0.2); // rests and a bracket chord

~t = \red.dab(amp: 0.3);                              // one touch a bar
~t.play;

~t = \red.dab("X..x ..x.", 0.5, amp: 0.3);            // a figure; X accents
~t = \red.dab("x.x.", 0.25, amp: 0.3, oct: 3);        // lower

~dr = \violet.drip(2, "0 3 5 7", amp: 0.2);           // about two a beat, notes at random
~dr.play;

~dr = \violet.drip(0.5, "Cm7 G7", amp: 0.2);          // sparse random chords

// LISTEN three colours of the same voice: a line, a figure, rain.
// WATCH  /syn/paint/mark/trig, /syn/paint/dab/trig, /syn/paint/drip/trig — drip's pulses irregularly.

~m.stop(2); ~t.stop(2); ~dr.stop(2);


/* ============================================================================
   LESSON 4 — SPRAY AND WASH: clouds and beds at the root
   Both take a root: a frequency, a control proxy followed live (~r), a pattern,
   or nothing — then ~r. They retrigger every dur beats and overlap themselves.
============================================================================ */

~bed = \grey.wash(~r, amp: 0.15);                     // a bed at the root
~bed.fade(4).play;

~cloud = \cyan.spray(~r, dens: 25, amp: 0.15);        // a grain cloud at the root
~cloud.fade(4).play;

~r = { 49 };                                          // move the root: both follow

// LISTEN the bed and the cloud slide down together.
// WATCH  /syn/kr/r changes; /syn/paint/wash/trig every 16 beats, /syn/paint/spray/trig every 4.

~cloud = \cyan.spray(220, dens: 8, size: 0.2, amp: 0.15);            // a fixed root, slow fat grains
~cloud = \yellow.spray(Pseq([110, 165, 220], inf), dur: 2, amp: 0.15);   // a root that walks
~bed = \black.wash(55, dur: 8, amp: 0.2);                            // a dark bed, retriggered faster

~r = { 55 };
~bed.stop(4); ~cloud.stop(4);


/* ============================================================================
   LESSON 5 — SPRAY OVER A CAPTURE (needs a microphone; not checked automatically)
   A buffer form of spray: the \sprayb voice over a mono buffer. rec() captures
   are mono; name the folder and the latest capture is used.
============================================================================ */

rec(8);                                               // 8 beats from the first input into d["live"]
~g = \grey.spray(buf: \live, dens: 20, amp: 0.2);
~g.fade(4).play;

~g = \orange.spray(buf: \live, dens: 40, amp: 0.2);   // hue = position wander on sprayb

~g.stop(4);


/* ============================================================================
   LESSON 6 — MOVES ON A PATTERN: darker lighter paler saturate warmer cooler, paint
   Each returns a new pattern stepping one axis from the value the events carry —
   or the voice's own default — so moves chain and compound.
============================================================================ */

~pad = \orange.brush("Cm7 Fm9 Abmaj7 G7", 4, amp: 0.15);
~pad.play;

~pad = \orange.brush("Cm7 Fm9 Abmaj7 G7", 4, amp: 0.15).darker(0.3);          // val down

// LISTEN the filter closing on the same chords.

~pad = \orange.brush("Cm7 Fm9 Abmaj7 G7", 4, amp: 0.15).darker(0.3).paler(0.4);   // and toward grey
~pad = \orange.brush("Cm7 Fm9 Abmaj7 G7", 4, amp: 0.15).lighter(0.3).saturate(0.3);   // up and vivid
~pad = \orange.brush("Cm7 Fm9 Abmaj7 G7", 4, amp: 0.15).cooler(0.5);          // hue toward blue
~pad = \blue.brush("Cm7 Fm9 Abmaj7 G7", 4, amp: 0.15).warmer(0.3);            // blue toward orange, through magenta

// LISTEN warmer and cooler step round the wheel the short way, never past the pole.

~pad = \orange.brush("Cm7 Fm9 Abmaj7 G7", 4, amp: 0.15).paint(\violet);       // recoloured outright

// A raw Pbind moves too: the step starts from the voice's own default colour.
~m = Pbind(\instrument, \mark, \degree, Pseq([0, 3, 5], inf), \dur, 0.25, \amp, 0.2).darker(0.3);
~m.play;

~m = Pbind(\instrument, \mark, \degree, Pseq([0, 3, 5], inf), \dur, 0.25, \amp, 0.2).paint(\red);

~pad.stop(4); ~m.stop(2);


/* ============================================================================
   LESSON 7 — MOVES ON A PROXY: the running sound
   The same words on ~x act on what it holds. A pattern source is reassigned on
   the grid. A synth source has its hue / sat / val controls moved — any drone
   recipe that names them joins the register.
============================================================================ */

~pad = \orange.brush("Cm7 Fm9 Abmaj7 G7", 4, amp: 0.15);
~pad.play;

~pad.darker(0.2);                                     // reassigned darker, on the next bar
~pad.cooler(0.2);
~pad.paler;
~pad.paint(\green);

// WATCH  /syn/paint/brush/hue, /sat and /val change at each bar line.

// A drone recipe that reads \hue and \val as controls:
Synesthesia.droneRecipes[\lit] = { |root, mult = 1, wob = 0.1, amp = 0.3|
	var f = root * mult;
	var saw = Saw.ar([f, f * 1.003] * \hue.kr(0.1).linlin(0, 1, 1, 2), 0.2);
	RLPF.ar(saw, f * \val.kr(0.5).linexp(0, 1, 1, 24), 0.3) * \amp.kr(amp)
};

~a = \lit.drone(~r, amp: 0.15);
~a.play;

~a.darker(0.3);                                       // ~a.set(\val, 0.2): the filter closes
~a.lighter(0.5);
~a.warmer;                                            // hue toward 0.08: here, the pitch ratio
~a.paint(\yellow);                                    // sets hue and val to the tube

// LISTEN the drone darkens and brightens without being rebuilt.

~b = \tone.drone(~r, amp: 0.1);                       // a recipe that speaks no colour
~b.play;
~b.darker;                                            // warns, does nothing — honest

~pad.stop(4); ~a.stop(4); ~b.stop(4);


/* ============================================================================
   LESSON 8 — MIXING, YOUR OWN TUBES, YOUR OWN TOOLS
   mix interpolates sat, val and spread; hue takes the short way round the wheel.
============================================================================ */

\orange.mix(\blue).postln;                            // a colour between two tubes (hue 0.85: through red)
\orange.mix(\green, 0.25).postln;                     // a quarter of the way

~bed = \grey.mix(\blue, 0.4).wash(~r, amp: 0.15);    // a mix takes every tool word
~bed.fade(4).play;

Paint.palette[\dusk] = \orange.mix(\violet, 0.6);    // name a mix
Paint.palette[\rust] = Paint.color(0.05, 0.8, 0.35); // or a new tube from coordinates
Paint.colors.postln;

~pad = \dusk.brush("Cm7 Fm9 Abmaj7 G7", 4, amp: 0.15);
~pad.play;

~pad = \rust.brush("Cm7 Fm9 Abmaj7 G7", 4, amp: 0.15);

// WATCH  /syn/paint/brush still — the tube's name travels only as the colour itself.

Paint.tools.postln;                                   // tool -> voice
Paint.tools[\dab] = \kick;                            // a tool over any voice that speaks the axes

~t = \red.dab("x...", 0.5, amp: 0.5, oct: 2);
~t.play;

// LISTEN dab is now the kick: hue is sweep depth, sat body drive, val the click.
// WATCH  /syn/paint/dab/…, as before — the wire names the tool, not the voice.

Paint.tools[\dab] = \mark;                            // and back

~bed.stop(4); ~pad.stop(4); ~t.stop(2);


/* ============================================================================
   LESSON 9 — DROPPING THE REGISTER
   A stroke is a Pbind: pattern words and raw pattern classes apply as they do
   to anything else, and the colour keys are just keys.
============================================================================ */

~m = \blue.mark("0 3 5 7", 0.25, amp: 0.2).fast(2).jux(_.slow(2));   // transform words
~m.play;

~t = \red.dab("x.x.", 0.5, amp: 0.3).sometimes(0.3, _.fast(4));
~t.play;

~m = Pbindf(\blue.mark("0 3 5 7", 0.25, amp: 0.2), \hue, Pseq([0.1, 0.9], inf));   // hue as a pattern
~m = Pbindf(\blue.mark("0 3 5 7", 0.25, amp: 0.2), \val, pad(\x).pat);             // val from the trackpad

// LISTEN move the mouse left and right: light follows it, note by note.

// Build the stroke yourself: a raw Pbind with the colour's keys spliced in.
~pad = Pbind(\instrument, \brush, \note, Pseq([[0, 3, 7, 10]], inf), \dur, 4, \amp, 0.15, *Paint.colorKeys(\green));
~pad.play;

Paint.colorKeys(\green).postln;                       // what those keys are
Paint.stroke(\brush, \green, [\degree, 0, \dur, 4, \amp, 0.15]).postln;   // the builder every tool uses

~m.stop(2); ~t.stop(2); ~pad.stop(4);


/* ============================================================================
   LESSON 10 — THE WIRE: what the VJ receives from a stroke
   Every stroke goes out under /syn/paint/<tool>/: a trig pulse, amp, notes (the MIDI
   notes, lowest first, in eight slots), dur in seconds, hue, sat, val — one value per address.
============================================================================ */

Broadcast.eventMessages(\orange.brush("Cm7", 4).asStream.next(Event.default)).postln;   // four messages, one per note
Broadcast.eventMessages(\grey.wash(55).asStream.next(Event.default)).postln;            // a cloud's pitch is its root
Broadcast.status;

~pad = \orange.brush("Cm7 Fm9 Abmaj7 G7", 4, amp: 0.15);
~pad.play;

~pad = Pbindf(\orange.brush("Cm7 Fm9 Abmaj7 G7", 4, amp: 0.15), \hue, Pseq([0, 0.25, 0.5, 0.75], inf));

// WATCH  /syn/paint/brush/hue stepping a quarter turn per chord. On the VJ's side,
//        hue -> colour wheel, sat -> saturation, val -> brightness: one gesture, two renderers.


/* ============================================================================
   LESSON 11 — ENDINGS
============================================================================ */

hush(8);
~verb.play; ~delay.play;                              // revive the returns if you carry on
Broadcast.stop;
