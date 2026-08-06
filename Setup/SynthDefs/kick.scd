// \kick — synthesized kick: pitch-swept feedback sine + noise click.
// NOTE: axis semantics PROVISIONAL — renamed to the hue/sat/val contract but still
// implementing the old bright/grit/morph behaviors; awaits this synth's own HSV
// rework (brush.scd is the template: wheel-hue, black-point val, grey<->neon sat).
// Family: drum (percussive). Tier 0 (stock).
// hue = sweep depth/speed (tight 909-ish -> deep boomy 808).
// val = click presence/color. sat = body feedback + drive.
// Try: Pbind(\instrument, \kick, \freq, 50, \dur, 1, \amp, 0.8)

SynthDef(\kick, { |out = 0, freq = 50, amp = 0.7, pan = 0, atk = 0.0005, rel = 0.4,
	val = 0.3, sat = 0.1, hue = 0.3|
	var f = freq.max(20);
	var sweep = EnvGen.ar(Env(
		[f * hue.linlin(0, 1, 2.5, 6), f],
		[hue.linlin(0, 1, 0.02, 0.12)], \exp));
	var body = SinOscFB.ar(sweep, sat.linlin(0, 1, 0, 0.9));
	var click = HPF.ar(WhiteNoise.ar, val.clip(0, 1).linexp(0, 1, 400, 4000))
		* EnvGen.ar(Env.perc(0.0005, 0.012))
		* val.linlin(0, 1, 0.05, 0.5);
	var env = EnvGen.ar(Env.perc(atk, rel, 1, -6), doneAction: 2);
	var sig = (body + click) * env;
	sig = LinSelectX.ar((sat * 0.7).clip(0, 1), [sig, (sig * (1 + (sat * 4))).tanh]);
	Out.ar(out, Pan2.ar(sig, pan, amp));
}).add;
