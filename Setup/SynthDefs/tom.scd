// \tom — synthesized tom: swept body + skin noise. Pitch it for low/mid/high toms.
// NOTE: axis semantics PROVISIONAL — renamed to the hue/sat/val contract but still
// implementing the old bright/grit/morph behaviors; awaits this synth's own HSV
// rework (brush.scd is the template: wheel-hue, black-point val, grey<->neon sat).
// Family: drum (percussive). Tier 0 (stock).
// hue = pure sine body <-> rototom bite (VarSaw).
// val = skin-noise band CENTER, freq-tracked into the stick/skin register.
// sat = drive. Try: Pbind(\instrument, \tom, \freq, Pseq([90, 130, 180], inf), \dur, 0.5)

SynthDef(\tom, { |out = 0, freq = 120, amp = 0.6, pan = 0, atk = 0.002, rel = 0.45,
	val = 0.4, sat = 0.2, hue = 0.3|
	var f = freq.max(20);
	var sweep = EnvGen.ar(Env([f * 1.5, f], [0.09], \exp));
	var body = SelectX.ar(hue.clip(0, 1), [SinOsc.ar(sweep), VarSaw.ar(sweep, 0, 0.35)]);
	var skin = BPF.ar(WhiteNoise.ar,
		(f * val.clip(0, 1).linexp(0, 1, 4, 40)).clip(200, 8000), 0.6)
		* EnvGen.ar(Env.perc(0.0005, 0.04)) * 0.3;
	var env = EnvGen.ar(Env.perc(atk, rel, 1, -6), doneAction: 2);
	var sig = (body + skin) * env;
	sig = LinSelectX.ar((sat * 0.7).clip(0, 1), [sig, (sig * (1 + (sat * 4))).tanh]);
	Out.ar(out, Pan2.ar(sig, pan, amp));
}).add;
