// \hat — synthesized hi-hat: white noise vs six inharmonic squares (808 recipe).
// NOTE: axis semantics PROVISIONAL — renamed to the hue/sat/val contract but still
// implementing the old bright/grit/morph behaviors; awaits this synth's own HSV
// rework (brush.scd is the template: wheel-hue, black-point val, grey<->neon sat).
// Family: drum (percussive). Tier 0 (stock).
// hue = white noise -> metallic partials (complexity rises with hue, family rule).
// val = band center (floor matches the fixed HPF so the axis stays spectral).
// sat = drive. rel = closed (~0.06) vs open (~0.4).
// Try: Pbind(\instrument, \hat, \dur, 0.25, \rel, 0.06, \amp, 0.5)

SynthDef(\hat, { |out = 0, freq = 320, amp = 0.5, pan = 0, atk = 0.0005, rel = 0.08,
	val = 0.7, sat = 0.2, hue = 0.6|
	var metal = Mix(Pulse.ar([2, 3.03, 4.09, 5.21, 6.15, 7.3] * freq, 0.5, 0.15));
	var white = WhiteNoise.ar(0.8);
	var src = SelectX.ar(hue.clip(0, 1), [white, metal]);
	var sig = HPF.ar(BPF.ar(src, val.clip(0, 1).linexp(0, 1, 6000, 12000), 1.2), 6000);
	var env = EnvGen.ar(Env.perc(atk, rel, 1, -8), doneAction: 2);
	sig = sig * env;
	sig = LinSelectX.ar((sat * 0.7).clip(0, 1), [sig, (sig * (1 + (sat * 4))).tanh]);
	Out.ar(out, Pan2.ar(sig, pan, amp));
}).add;
