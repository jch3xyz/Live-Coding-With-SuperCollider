// \break — a whole breakbeat loop as one voice: locked to the session tempo, sliced
// on a musical grid, and continuously dissolvable from intact loop to granular dust.
// Family: grain voice (gated, sustained — lives on a NodeProxy). Tier 0 (stock).
//
// The engine is driven entirely by controls; the intelligence that knows a sample's
// tempo, indexes the library and rewrites sequences is the Break class in the
// Synesthesia quark (CONVENTIONS rule 5 — a def may not touch interpreter state).
// Try:  ~d.brk(\amen); ~d.play; ~d.grind(0.7)
// Raw:  Synth(\break, [\buf, b.bufnum, \beats, 4, \steps, 16, \tempo, 2])
//
// HOW IT WORKS
// A Phasor runs one cycle per loop at the session tempo, so every grid in the synth
// is a multiple of that one phase — nothing can drift, and \resync realigns
// everything to the bar at once. The pointer into the sample is derived from the
// phase, which is what makes tempo-fitting free: the pointer moves at session speed
// while grains play at whatever rate \vari asks for.
//
// THE MACRO (\grind) has three exact stations:
//   0.0  one grain per loop          — the loop plays intact
//   0.5  one grain per slice         — clean chops on the grid
//   1.0  64 grains per beat          — dust
//
// \vari picks how the fit is achieved: 1 (default) repitches the break to fit, the
// classic sampler/jungle sound, coherent at any \grind. 0 keeps the original pitch
// and lets the grains do the stretching — which needs grains, so it only really
// works above \grind ~0.4.

// break-specific axes (shared names live in 00_specs.scd — CONVENTIONS rule 7)
Spec.add(\grind, [0, 1]);
Spec.add(\over,  [0.25, 4, \exp]);
Spec.add(\scram, [0, 1]);
Spec.add(\jit,   [0, 1]);
Spec.add(\vari,  [0, 1]);
Spec.add(\flip,  [0, 1]);
Spec.add(\roll,  ControlSpec(1, 16, \exp, 1, 1));
Spec.add(\steps, ControlSpec(1, 64, \lin, 1, 16));
// deliberately NO Spec for \beats: SuperCollider's own registry already defines
// \beats as an LFO rate in Hz (0..20), and registering ours would overwrite a
// main-class-library Spec for every other user of it. \beats here is metadata read
// off the sample, set by `brk` rather than dragged by a performer, so rule 7's
// "every performative arg has a Spec" does not apply to it.

SynthDef(\break, {
	var out = \out.kr(0);
	var buf = \buf.kr(0);
	var tempo = \tempo.kr(2);              // beats per second (Break pushes the clock)
	var beats = \beats.kr(4).max(1);       // the loop's length in beats
	var steps = \steps.kr(16).max(1);      // slices per loop
	var grind = \grind.kr(0.5, 0.05);
	var over = \over.kr(1);
	var scram = \scram.kr(0);
	var jit = \jit.kr(0);
	var vari = \vari.kr(1);
	var rate = \rate.kr(1);
	var pos = \pos.kr(0);
	var roll = \roll.kr(1).max(1);
	var flip = \flip.kr(0);
	var sbuf = \sbuf.kr(0);                // slice-sequence buffer (rewritten live)
	var slen = \slen.kr(16).max(1);        // active sequence length
	var envbuf = \envbuf.kr(-1);           // grain window; -1 = built-in Hann
	var amp = \amp.kr(0.5), pan = \pan.kr(0);
	var atk = \atk.kr(0.02), rel = \rel.kr(0.5), gate = \gate.kr(1);

	// one sample wide, so a resync never freezes the phase for a whole control block
	var resync = Trig1.ar(K2A.ar(\resync.tr(0)), SampleDur.ir);

	// ---- the one phase everything else is derived from ----
	var loopRate = tempo / beats;                                   // loops per second
	var loopPhase = Phasor.ar(resync, loopRate * SampleDur.ir, 0, 1, 0);
	var loopWrap = HPZ1.ar(loopPhase) < -0.25;
	var loopCount = PulseCount.ar(loopWrap, resync);
	var bufDur = BufDur.kr(buf).max(0.001);

	// ---- the slice grid, and which source slice plays at this step ----
	var slicePos = loopPhase * steps;
	var sliceTrig = (HPZ1.ar(slicePos.frac) < -0.25) + Impulse.ar(0) + resync;
	// counting loops as well as slices lets a sequence be longer than one loop
	var stepIdx = ((loopCount * steps) + slicePos.floor).mod(slen);
	var seqVal = Index.ar(sbuf, stepIdx);                           // -1 means rest
	var useRnd = TRand.ar(0, 1, sliceTrig) < scram;
	var srcIdx = Select.ar(useRnd, [seqVal.max(0), TIRand.ar(0, steps - 1, sliceTrig)]);
	var live = Select.ar(useRnd, [seqVal >= 0, DC.ar(1)]);

	// ---- roll: replay the first 1/roll of this slice, roll times ----
	var subPos = slicePos.frac * roll;
	var subFrac = subPos.frac / roll;
	var rollTrig = (HPZ1.ar(subPos.frac) < -0.25) * (roll > 1);

	// ---- grind: grains per loop, exact at 1 / steps / 64*beats ----
	var g2 = grind * 2;
	var gpl = (steps ** g2.clip(0, 1))
		* (((64 * beats / steps).max(1)) ** (g2 - 1).clip(0, 1));
	var trigRate = (gpl * loopRate).max(0.01);
	// the grain grid gets its OWN phasor rather than being derived as loopPhase * gpl:
	// scaling an advancing phase by a moving factor makes the phase itself jump, which
	// fires spurious extra grains while \grind is being swept. Both phasors start
	// together at reset, so at grind 0.5 (gpl == steps) grain and slice onsets are
	// still exactly coincident — which is what makes that station a clean chop.
	var grainPhase = Phasor.ar(resync, trigRate * SampleDur.ir, 0, 1, 0);
	var grainTrig = (HPZ1.ar(grainPhase) < -0.25) + Impulse.ar(0) + resync;
	// gating the TRIGGER rather than the output means a rest can never cut the tail
	// of a grain that is still sounding
	var trig = (grainTrig + rollTrig) * live;
	// Grain length follows the FASTEST trigger source, not just the grain grid: roll
	// adds triggers at roll x the slice rate, and without this a roll would stack
	// `roll` full-length grains on top of each other (up to +24 dB at roll 16).
	// The ceiling is deliberately generous — at grind 0 a grain IS the whole loop,
	// and a tight cap silently truncated any loop longer than it.
	// gated by (roll > 1) exactly as rollTrig is — otherwise the slice-rate term
	// dominates even with roll off, and a grind-0 grain shrinks from a whole loop to
	// one slice
	var rollRate = loopRate * steps * roll * (roll > 1);
	var effRate = trigRate.max(rollRate);
	var gdur = (over / effRate).clip(0.0005, 60);
	var stretch = bufDur * loopRate;              // rate that makes the source fit
	var flipped = TRand.ar(0, 1, trig) < flip;
	var grate = rate * (stretch ** vari) * (1 - (2 * flipped));
	// a reversed grain starts at the far end of the region it would have played
	var srcLen = gdur * grate.abs / bufDur;
	var spray = TRand.ar(-1, 1, trig) * jit.squared * 0.1;
	var ptr = (((srcIdx + subFrac) / steps) + pos + spray + (flipped * srcLen)).wrap(0, 1);

	var env = EnvGen.ar(Env.asr(atk, 1, rel), gate, doneAction: 2);
	// Overlap compensation is 1/over, not the usual 1/sqrt(over) for grain clouds:
	// because the pointer advances at exactly the rate the slice grid does, two
	// overlapping grains play the SAME source audio in phase, so they sum coherently
	// (measured: +6 dB from over 1 to 4 under a sqrt law). A scrambled sequence is
	// less coherent and so ends up quieter, which is the safe direction to err.
	var comp = over.max(1).reciprocal;
	var sig = GrainBuf.ar(1, trig, gdur, buf, grate, ptr, 2, 0, envbuf, 512);

	sig = LeakDC.ar(sig) * env * comp;
	Out.ar(out, Pan2.ar(sig, pan, amp));
}).add;
