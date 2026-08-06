// \snare — synthesized snare: two swept shell modes vs bandpassed noise snares.
// NOTE: axis semantics PROVISIONAL — renamed to the hue/sat/val contract but still
// implementing the old bright/grit/morph behaviors; awaits this synth's own HSV
// rework (brush.scd is the template: wheel-hue, black-point val, grey<->neon sat).
// Family: drum (percussive). Tier 0 (stock).
// hue = shell <-> snares balance (intentionally: hue is "snares amount" here).
// val = noise band center + a short attack crack. sat = drive.
// Try: Pbind(\instrument, \snare, \dur, 2, \amp, 0.6)

SynthDef(\snare, { |out = 0, freq = 180, amp = 0.6, pan = 0, atk = 0.0005, rel = 0.25,
	val = 0.5, sat = 0.4, hue = 0.45|
	var f = freq.max(20);
	var shell = (SinOsc.ar(EnvGen.ar(Env([f * 1.9, f], [0.07], \exp))) * 0.6)
		+ (SinOsc.ar(EnvGen.ar(Env([f * 3.1, f * 1.6], [0.05], \exp))) * 0.25);
	var snares = (BPF.ar(WhiteNoise.ar, val.clip(0, 1).linexp(0, 1, 900, 6000), 1.1) * 1.2)
		+ (HPF.ar(WhiteNoise.ar, 4000) * EnvGen.ar(Env.perc(0.0005, 0.03)) * val * 0.8);
	var env = EnvGen.ar(Env.perc(atk, rel, 1, -4), doneAction: 2);
	var sig = SelectX.ar(hue.clip(0, 1), [shell, snares]) * env;
	sig = LinSelectX.ar((sat * 0.7).clip(0, 1), [sig, (sig * (1 + (sat * 5))).tanh]);
	Out.ar(out, Pan2.ar(sig, pan, amp));
}).add;
