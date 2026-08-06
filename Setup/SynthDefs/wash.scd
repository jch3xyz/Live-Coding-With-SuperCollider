// \wash — the texture bed (wash tool). Noise -> comb -> modal-ring continuum.
// NOTE: axis semantics PROVISIONAL — renamed to the hue/sat/val contract but still
// implementing the old bright/grit/morph behaviors; awaits this synth's own HSV
// rework (brush.scd is the template: wheel-hue, black-point val, grey<->neon sat).
// Family: texture voice (long gated env; LeakDC mandatory — Crackle has DC). Tier 0 (stock).
// hue = air -> combed color -> pitched modal ring at freq (seams crossfaded).
// val = noise color blend + freq-tracked lowpass tilt.
// sat = crackle/dust mix + slow amplitude movement DEPTH (sat 0 = truly steady bed).
// Takes freq (deg-able) but happily sits at the root. Modal bank is fixed per note.
// Try: Pbind(\instrument, \wash, \degree, 0, \octave, 3, \dur, 16, \legato, 1)

SynthDef(\wash, { |out = 0, freq = 110, amp = 0.25, pan = 0, gate = 1,
	atk = 3, rel = 5, val = 0.4, sat = 0.2, hue = 0.3|
	var env = EnvGen.ar(Env.asr(atk, 1, rel, \sin), gate, doneAction: 2);
	var noise = SelectX.ar((val * 2).clip(0, 2),
		[BrownNoise.ar, PinkNoise.ar, WhiteNoise.ar]);
	var crackle = (Crackle.ar(1.9) * sat * 0.25)
		+ (Dust2.ar(sat.linexp(0, 1, 0.1, 60)) * sat * 0.5);
	var src = noise + crackle;
	var comb = CombC.ar(src * 0.4, 0.06,
		freq.reciprocal.clip(0.0005, 0.06),
		hue.linlin(0, 1, 0.05, 2.5));
	var modal = Klank.ar(`[
		[1, 2.0, 2.98, 4.5],
		[1, 0.6, 0.4, 0.25],
		[1, 0.7, 0.5, 0.35]
	], src * 0.02, freq);
	var sig = SelectX.ar((hue * 2).clip(0, 2), [src, comb, modal]);
	sig = sig * LFNoise2.kr(0.2 + (sat * 0.3)).range(1 - (sat * 0.4), 1);
	sig = LPF.ar(sig, (freq * val.linexp(0, 1, 4, 64)).clip(200, 16000));
	sig = LeakDC.ar(sig);
	Out.ar(out, Pan2.ar(sig * env, pan, amp));
}).add;
