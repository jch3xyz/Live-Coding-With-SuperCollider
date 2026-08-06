// \sprayb — buffer grain cloud (spray over rec() captures / mono samples). GrainBuf.
// NOTE: axis semantics PROVISIONAL — renamed to the hue/sat/val contract but still
// implementing the old bright/grit/morph behaviors; awaits this synth's own HSV
// rework (brush.scd is the template: wheel-hue, black-point val, grey<->neon sat).
// Family: grain voice (gated; sustained cloud). Tier 0 (stock).
// NOTE: GrainBuf requires a MONO buffer — rec() captures are mono and work directly;
// for library samples load a mono read (Buffer.readChannel(s, path, channels: [0])).
// A stereo buffer produces SILENCE (grains are skipped server-side).
// hue = position focus -> wide wander/scatter (reflects off buffer edges, no seam-jumps).
// val = spectral shelf tilt (does NOT change pitch).
// sat = trigger regularity + per-grain rate scatter (log-symmetric — no transposition).
// pos = 0..1 center position; rate = playback rate; width = per-grain pan spread.
// Level is compensated for grain overlap (dens*size).
// Try: rec(8); then ~g = Pbind(\instrument, \sprayb, \buf, d["live"][0], \dur, 8, \legato, 1)

SynthDef(\sprayb, { |out = 0, buf = 0, amp = 0.4, pan = 0, gate = 1,
	atk = 0.1, rel = 0.8, rate = 1, pos = 0.5,
	val = 0.5, sat = 0.3, hue = 0.3,
	dens = 14, size = 0.12, width = 0.6|
	var env = EnvGen.ar(Env.asr(atk, 1, rel), gate, doneAction: 2);
	var trig = Impulse.ar(dens * (1 - sat)) + Dust.ar(dens * sat);
	var wander = hue.linlin(0, 1, 0.01, 0.5);
	var cpos = (pos
		+ LFNoise2.kr(0.2).range(wander.neg, wander)
		+ TRand.ar(wander.neg * 0.5, wander * 0.5, trig)).fold(0, 1);
	var s = sat.linlin(0, 1, 1.001, 1.5);
	var jrate = rate * TExpRand.ar(s.reciprocal, s, trig);
	var comp = (dens * size).max(1).sqrt.reciprocal;
	var sig = GrainBuf.ar(2, trig, size, buf, jrate, cpos, 2,
		TRand.ar(width.neg, width, trig));
	sig = BHiShelf.ar(BLowShelf.ar(sig, 250, 1, val.linlin(0, 1, 4, -6)),
		2800, 1, val.linlin(0, 1, -9, 6));
	Out.ar(out, Balance2.ar(sig[0], sig[1], pan, amp * comp * env));
}).add;
