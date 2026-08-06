// \bplay — stereo buffer player. The default instrument of \folder.hits.
// One-shot: plays the buffer from pos (0..1), frees itself. hold caps how long
// the node stays open (a failsafe timeout against stuck reversed/slow playback —
// deliberately NOT named rel: it is a lifetime cap, not a release).
// Conventions: see CONVENTIONS.md in this folder.

SynthDef(\bplay, { |out = 0, buf = 0, rate = 1, amp = 0.5, pan = 0, pos = 0, hold = 15|
	var sig = PlayBuf.ar(2, buf, BufRateScale.ir(buf) * rate, 1,
		BufFrames.ir(buf) * pos, doneAction: 2);
	var env = EnvGen.ar(Env.linen(0, hold, 0), doneAction: 2);
	sig = sig * env * amp;
	Out.ar(out, Balance2.ar(sig[0], sig[1], pan));
}).add;
