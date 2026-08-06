// \brk1 — one slice of a break, played once. The brush to \break's canvas: this is
// what `\amen.chop("0325")` fires, one synth per chop, so per-hit rate, pan, amp and
// effects are ordinary pattern work.
// Family: buffer player (windowed, failsafe-capped). Tier 0 (stock).
//
// The window length comes from the event's own \sustain, which is in BEATS (measured:
// dur 0.25 at tempo 2 yields sustain 0.25, not 0.125) — so it is divided by \tempo to
// get seconds. Without that a chop's window is `tempo` times too long and chops smear
// into each other. Tempo arrives as a control rather than being baked in, per
// CONVENTIONS rule 5; `chop` supplies it and so tracks live tempo changes.
// `hold` caps the result in seconds, so a runaway pattern value can never strand a
// node (CONVENTIONS rule 4).
// Mono, like the Break registry's buffers — a stereo buffer plays its left channel.
// Try: \amen.chop("0.32 0123")
// Raw: Pbind(\instrument, \brk1, \buf, b, \pos, Pseq([0, 0.25, 0.5], inf), \dur, 0.25)

SynthDef(\brk1, {
	var out = \out.kr(0);
	var buf = \buf.kr(0);
	var rate = \rate.kr(1);
	var pos = \pos.kr(0).clip(0, 1);
	var amp = \amp.kr(0.5), pan = \pan.kr(0);
	var sustain = \sustain.kr(0.25);       // supplied by the event, in BEATS
	var tempo = \tempo.kr(1).max(0.01);    // beats per second
	var hold = \hold.kr(8);                // lifetime cap in seconds, not a release
	var atk = \atk.kr(0.002), rel = \rel.kr(0.03);
	var dur = (sustain / tempo).min(hold);
	var body = (dur - atk - rel).max(0.001);
	var env = EnvGen.ar(Env.linen(atk, body, rel, 1, [\lin, \lin, -2]), doneAction: 2);
	// loop so a chop near the end of the sample wraps instead of running into silence
	var sig = PlayBuf.ar(1, buf, BufRateScale.ir(buf) * rate, 1,
		BufFrames.ir(buf) * pos, loop: 1);
	Out.ar(out, Pan2.ar(sig * env, pan, amp));
}).add;
