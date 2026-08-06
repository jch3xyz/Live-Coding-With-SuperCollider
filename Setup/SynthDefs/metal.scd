// \metal — struck modal banks: bell-consonant vs crunchy-inharmonic, noise-excited.
// NOTE: axis semantics PROVISIONAL — renamed to the hue/sat/val contract but still
// implementing the old bright/grit/morph behaviors; awaits this synth's own HSV
// rework (brush.scd is the template: wheel-hue, black-point val, grey<->neon sat).
// Family: drum (percussive, long ring — ring times scale with rel). Tier 0 (stock).
// hue = consonant bank <-> inharmonic bank (chosen per hit — banks fixed at start).
// val = spectral shelf tilt. sat = excitation length + drive.
// freq is clipped at 2400 Hz (partials reach 8.9x freq and must stay below Nyquist).
// Try: Pbind(\instrument, \metal, \freq, 200, \dur, 4, \rel, 2, \amp, 0.4)

SynthDef(\metal, { |out = 0, freq = 200, amp = 0.5, pan = 0, atk = 0.001, rel = 1.2,
	val = 0.5, sat = 0.3, hue = 0.5|
	var f = freq.clip(20, 2400);
	var exc = WhiteNoise.ar
		* EnvGen.ar(Env.perc(0.0005, sat.linlin(0, 1, 0.015, 0.08))) * 0.12;
	var bank1 = Klank.ar(`[
		[1, 2.98, 5.4, 8.9],
		[1, 0.7, 0.45, 0.3],
		[1.6, 1.3, 1.0, 0.8]
	], exc, f, 0, rel);
	var bank2 = Klank.ar(`[
		[0.985, 1.51, 2.76, 3.51, 4.62, 6.71],
		[0.65, 0.55, 0.45, 0.35, 0.28, 0.22],
		[1.5, 1.3, 1.1, 0.9, 0.8, 0.7]
	], exc, f, 0, rel);
	var env = EnvGen.ar(Env.perc(atk, rel, 1, -4), doneAction: 2);
	var sig = SelectX.ar(hue.clip(0, 1), [bank1, bank2]);
	sig = BHiShelf.ar(sig, 3000, 1, val.clip(0, 1).linlin(0, 1, -12, 8));
	sig = sig * env;
	sig = LinSelectX.ar((sat * 0.7).clip(0, 1), [sig, (sig * (1 + (sat * 3))).tanh]);
	Out.ar(out, Pan2.ar(sig, pan, amp));
}).add;
