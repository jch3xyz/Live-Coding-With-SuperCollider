// \mark — the percussive voice (mark/dab/drip tools). Two-operator phase modulation.
// NOTE: axis semantics PROVISIONAL — renamed to the hue/sat/val contract but still
// implementing the old bright/grit/morph behaviors; awaits this synth's own HSV
// rework (brush.scd is the template: wheel-hue, black-point val, grey<->neon sat).
// Family: percussive voice. Tier 0 (stock).
// hue = modulator ratio, harmonic -> bell -> metal (continuous; modulator is
//         Nyquist-guarded so extreme pitches don't alias unpredictably).
// val = FM index, partly envelope-tracked (hits open val, decay dark).
// sat = noise-splash transient (independent of the main envelope) + body drive.
// Gamut: woody pluck -> kalimba/EP -> bell -> metallic clang.
// Try: Pbind(\instrument, \mark, \degree, Pseq([0, 3, 5], inf), \dur, 0.5, \hue, 0.6)

SynthDef(\mark, { |out = 0, freq = 220, amp = 0.4, pan = 0,
	atk = 0.002, rel = 0.6, val = 0.5, sat = 0, hue = 0.3|
	var env = EnvGen.ar(Env.perc(atk, rel, 1, -4), doneAction: 2);
	var ratio = hue.linexp(0, 1, 1, 7.19);
	var modfreq = (freq * ratio).min(SampleRate.ir * 0.45);
	var index = val.linlin(0, 1, 0.4, 9) * (0.3 + (env * 0.7));
	var sig = SinOsc.ar(freq, SinOsc.ar(modfreq) * index);
	var splash = HPF.ar(WhiteNoise.ar, (freq * 4).clip(200, 12000))
		* EnvGen.ar(Env.perc(0.001, 0.03)) * (sat * 0.6);
	sig = LinSelectX.ar((sat * 0.7).clip(0, 1), [sig, (sig * (1 + (sat * 6))).tanh]);
	Out.ar(out, Pan2.ar((sig * env) + splash, pan, amp));
}).add;
