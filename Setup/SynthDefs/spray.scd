// \spray — synthetic grain cloud (spray/wash tools, no buffer needed). GrainFM.
// NOTE: axis semantics PROVISIONAL — renamed to the hue/sat/val contract but still
// implementing the old bright/grit/morph behaviors; awaits this synth's own HSV
// rework (brush.scd is the template: wheel-hue, black-point val, grey<->neon sat).
// Family: grain voice (gated; sustained cloud). Tier 0 (stock).
// hue = grain FM ratio path (pure -> bell-ish -> clangorous grains).
// val = grain FM index (spectral center).
// sat = trigger regularity (periodic shimmer -> Dust rain) + per-grain pitch
//        scatter (log-symmetric around freq — the cloud never transposes).
// width = per-grain pan spread (a spatial parameter, per conventions 6b).
// Level is compensated for grain overlap (dens*size), so density sweeps stay level-safe.
// Try: Pbind(\instrument, \spray, \degree, 0, \dur, 4, \legato, 1, \dens, 25)

SynthDef(\spray, { |out = 0, freq = 440, amp = 0.35, pan = 0, gate = 1,
	atk = 0.1, rel = 0.8, val = 0.5, sat = 0.3, hue = 0.3,
	dens = 18, size = 0.08, width = 0.6|
	var env = EnvGen.ar(Env.asr(atk, 1, rel), gate, doneAction: 2);
	var trig = Impulse.ar(dens * (1 - sat)) + Dust.ar(dens * sat);
	var s = sat.linlin(0, 1, 1.001, 1.6);
	var jit = TExpRand.ar(s.reciprocal, s, trig);
	var ratio = hue.linexp(0, 1, 1, 5.04);
	var index = val.linlin(0, 1, 0.5, 8);
	var comp = (dens * size).max(1).sqrt.reciprocal;
	var sig = GrainFM.ar(2, trig, size,
		freq * jit, freq * jit * ratio, index,
		TRand.ar(width.neg, width, trig));
	Out.ar(out, Balance2.ar(sig[0], sig[1], pan, amp * comp * env));
}).add;
