// \brush — the sustained voice (brush tool). An ensemble pad synthesizer with a
// living modulation ecology, interfaced through the HSV color contract.
// Family: sustained voice (gated adsr; \legato-friendly). Tier 0 (stock).
//
// THE SPACE (coupled, per CONVENTIONS — not three independent wires):
//   hue — ANGLE on a wrapping 5-station timbre wheel (0 and 1 are the same place):
//         warm ensemble saw -> hollow pulse -> glass -> torn sync (alive: swept at
//         attack, undulating in sustain) -> vowel formants -> back to saw.
//   sat — hue-identity strength. 1: tight detune, resonant, defined; extreme top
//         adds neon drive. 0: GREY — wheel collapses to a blurred, noise-veiled,
//         resonance-flattened wash where moving hue does (almost) nothing.
//   val — light. 0: BLACK — the filter closes below the fundamental and every hue
//         converges to the same dark thump (sub carries the floor). Mid: detail and
//         filter-envelope contrast grow. 1: full light; the air layer opens
//         (partials when saturated, noise-brilliance when desaturated = WHITE).
//   Couplings: hue expression scales with sat; sat expression scales with val;
//   the modulation ecology's rates/depths shift by region (grey churns, vivid is
//   calm, dark breathes slowly) — the weather changes as you move.
//
// Tier-3 standalone surface: sub, air, fenv (filter-env amount), track
// (keytracking), drift (ecology depth), bow (attack chiff), smear (mono ensemble
// chorus). Per-note Rand seeds: every note of a chord blooms differently.
// Try: Pbind(\instrument, \brush, \degree, Pseq([0, 2, 4], inf), \dur, 4,
//      \legato, 0.9, \hue, 0.1, \sat, 0.7, \val, 0.55)

SynthDef(\brush, { |out = 0, freq = 220, amp = 0.35, pan = 0, gate = 1,
	atk = 0.8, dec = 0.3, sus = 0.85, rel = 1.5,
	hue = 0.05, sat = 0.65, val = 0.5,
	sub = 0.3, air = 0.3, fenv = 0.4, track = 0.6, drift = 0.5, bow = 0.3, smear = 0.3|

	var env, envK, slope, satEff, spread, freqs, phases, sawSum, pulseSum,
		glass, syncSweep, syncRatio, syncSig, f1, f2, vowel, grey, stations,
		weights, hueSig, source, fEnv, cutoffKey, cutoff, wobble, sig,
		subSig, airSig, neon, bowSig;

	// --- envelopes (audio for amplitude, control copy for the ecology) ---
	env  = EnvGen.ar(Env.adsr(atk, dec, sus, rel), gate, doneAction: 2);
	envK = EnvGen.kr(Env.adsr(atk, dec, sus, rel), gate);
	slope = Slope.kr(envK).max(0);

	// --- couplings: dark mutes saturation; grey mutes hue ---
	satEff = (sat * val.linlin(0, 1, 0.35, 1)).clip(0, 1);

	// --- ensemble core: 5 voices, per-note random drift rates and phases;
	//     desaturation widens and churns the spread (blur is made of motion) ---
	spread = (1 - satEff).linlin(0, 1, 0.0015, 0.009)
		* drift.linlin(0, 1, 0.4, 1.6)
		* freq.explin(50, 2000, 1.4, 0.7);
	freqs = Array.fill(5, { |i|
		freq * (1 + (LFNoise2.kr(ExpRand(0.07, 0.23)) * spread * (i + 1) / 3))
	});
	phases = Array.fill(5, { Rand(0, 1) });

	// --- the five hue stations ---
	sawSum   = VarSaw.ar(freqs, phases, 0.06).sum * 0.2;
	pulseSum = Pulse.ar(freqs, 0.5 + (LFNoise2.kr(0.19) * 0.09)).sum * 0.17;
	glass = SinOsc.ar(
		freq * [1, 2.0, 3.01, 4.52] * (1 + (LFNoise2.kr([0.11, 0.13, 0.17, 0.19]) * 0.002)),
		0, [0.25, 0.8, 0.45, 0.22]).sum * 0.5;
	syncSweep = EnvGen.kr(Env([1.7, 0], [0.9], -3), gate);
	syncRatio = 1.05 + (syncSweep * 1.1) + (LFNoise2.kr(0.13).range(0, 1) * 1.1);
	syncSig = SyncSaw.ar(freq, freq * syncRatio) * 0.72;
	f1 = LFNoise2.kr(0.08).range(420, 760);
	f2 = LFNoise2.kr(0.06).range(950, 1400);
	vowel = (BPF.ar(sawSum, f1, 0.15) * 2.4) + (BPF.ar(sawSum, f2, 0.12) * 1.7);

	// --- the wheel: triangular partition of unity, wrapping at the ends ---
	stations = [sawSum, pulseSum, glass, syncSig, vowel];
	weights = Array.fill(5, { |k|
		(1 - ((hue - (k / 5)).wrap(-0.5, 0.5).abs * 5)).max(0)
	});
	hueSig = (stations * weights).sum;

	// --- grey: the hueless bed (blurred ensemble + pink veil) ---
	grey = (sawSum * 0.55) + (BPF.ar(PinkNoise.ar, (freq * 2).clip(80, 6000), 1.0) * 0.45);
	source = (hueSig * satEff) + (grey * (1 - satEff));

	// --- bow: articulation chiff following the envelope's slope ---
	bowSig = HPF.ar(PinkNoise.ar, (freq * 2).clip(200, 8000))
		* (slope * 2.5).clip(0, 1) * bow * 0.4;
	source = source + bowSig;

	// --- filter section = value: black floor, contrast, keytracked, wandering ---
	fEnv = EnvGen.kr(Env.adsr(atk * 0.6, dec * 1.5, 0.6, rel * 0.8), gate);
	cutoffKey = freq.pow(track) * (261.63.pow(1 - track));
	cutoff = cutoffKey * val.linexp(0, 1, 0.6, 26)
		* (1 + (fEnv * fenv * val.linlin(0, 1, 0.3, 1.4) * 2));
	wobble = LFNoise2.kr((1 - satEff).linlin(0, 1, 0.06, 1.6) * drift.linlin(0, 1, 0.5, 1.5))
		.range(1 - ((1 - satEff) * 0.35), 1 + ((1 - satEff) * 0.6));
	sig = MoogFF.ar(source, (cutoff * wobble).clip(30, 16000),
		satEff.linlin(0, 1, 0.35, 2.4));

	// --- mono ensemble smear (time-domain chorus; width stays the canvas's job) ---
	sig = sig + (DelayC.ar(sig, 0.03, LFNoise2.kr(0.4).range(0.004, 0.014))
		* smear * (1 + ((1 - satEff) * 0.8)) * 0.6);

	// --- harmonic scaffolding, post-filter: sub floor and air ceiling ---
	subSig = SinOsc.ar(freq * 0.5) * sub * val.linlin(0, 1, 1.2, 0.55) * 0.5;
	airSig = (
		(SinOsc.ar(freq * [3.0, 4.02], 0, [0.4, 0.28]).sum * satEff)
		+ (HPF.ar(WhiteNoise.ar, 3500) * (1.3 - satEff) * 0.35)
	) * air * val.pow(2) * 0.5;
	sig = sig + subSig + airSig;

	// --- neon: the oversaturated extreme runs hot ---
	neon = ((sat - 0.75).max(0) * 4).clip(0, 1);
	sig = LinSelectX.ar(neon * 0.85,
		[sig, (sig * (1 + (neon * 5))).tanh * (1 - (neon * 0.25))]);

	// --- tide: slow level weather — grey churns, vivid rests; dark sits lower ---
	sig = sig * LFNoise2.kr(0.05 + ((1 - satEff) * 0.3))
		.range(1 - (0.04 + ((1 - satEff) * 0.22)), 1);
	sig = LeakDC.ar(sig * env * val.linlin(0, 1, 0.55, 1));

	Out.ar(out, Pan2.ar(sig, pan, amp));
}).add;
