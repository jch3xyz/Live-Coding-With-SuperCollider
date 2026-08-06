// \bplaym — mono buffer player with pan. The instrument for rec() captures
// (which are mono) and any mono sample material.
// hold = failsafe lifetime cap (not a release; see bplay.scd).
// Conventions: see CONVENTIONS.md in this folder.

SynthDef(\bplaym, { |out = 0, buf = 0, rate = 1, amp = 0.5, pan = 0, pos = 0, hold = 15|
	var sig = PlayBuf.ar(1, buf, BufRateScale.ir(buf) * rate, 1,
		BufFrames.ir(buf) * pos, doneAction: 2);
	var env = EnvGen.ar(Env.linen(0, hold, 0), doneAction: 2);
	Out.ar(out, Pan2.ar(sig * env, pan, amp));
}).add;
