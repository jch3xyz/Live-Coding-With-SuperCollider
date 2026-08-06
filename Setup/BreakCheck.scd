// BreakCheck — offline verification of the \break engine. Renders NRT (no audio
// hardware, no sound), measures the result numerically, and posts pass/fail.
//
// This is the regression gate for the breakbeat machine: run it after any edit to
// break.scd. It proves the things that matter and cannot be checked by reading —
// that slices land on the session grid, that a sample recorded at one tempo locks to
// a session at another, that rests are silent, that a swap is gapless, that the node
// dies, that nothing clips.
//
// It builds its own fixtures, so it needs no sample library: synthetic loops whose
// 16 slices carry ascending amplitudes, which makes both timing AND slice order
// measurable from the rendered audio.
//
// Usage: evaluate the whole file. Takes about a minute; posts a summary at the end.
// Language-side unit tests are separate and instant: TestBreak.run
//
// Note: this machine's dead x86_64 PortedPlugins spew dlopen errors into the NRT
// server's stderr. They are pre-existing and unrelated — ignore them.

(
var setupDir = thisProcess.nowExecutingPath.dirname;
var defPath = setupDir +/+ "SynthDefs" +/+ "break.scd";
var work = (Platform.defaultTempDir ? "/tmp/") +/+ "breakcheck";
var sr = 44100;
var pass = 0, fail = 0;
var check, mkFixture, render, onsets, winSignal, f175, f90;

File.mkdir(work);

check = { |name, ok, detail|
	if(ok) {
		pass = pass + 1;
		("  ok   " ++ name ++ if(detail.notNil, { "  — " ++ detail }, "")).postln;
	} {
		fail = fail + 1;
		("  FAIL " ++ name ++ "  — " ++ detail).postln;
	};
};

// a loop of `beats` beats at `bpm`, one amplitude-coded click per slice, mono
mkFixture = { |name, bpm, beats, steps = 16|
	var path = work +/+ name;
	var dur = beats * 60 / bpm;
	var frames = (dur * sr).round.asInteger;
	var sig = Signal.newClear(frames);
	var sliceLen = frames / steps;
	var clickLen = (0.004 * sr).asInteger;
	var sf;
	steps.do { |i|
		var start = ((i * sliceLen) + (sliceLen * 0.08)).asInteger;
		var amp = (i + 1) / steps;
		clickLen.do { |j|
			var idx = start + j;
			if(idx < frames) {
				sig[idx] = amp * sin(2pi * 1000 * j / sr) * exp(-8 * j / clickLen);
			};
		};
	};
	sf = SoundFile.new
		.headerFormat_("WAV").sampleFormat_("float")
		.numChannels_(1).sampleRate_(sr);
	if(sf.openWrite(path).not) { nil } {
		sf.writeData(sig.as(FloatArray));
		sf.close;
		(path: path, bpm: bpm, beats: beats, dur: dur)
	};
};

winSignal = Env(#[0, 1, 1, 0], #[0.005, 0.965, 0.03], #[\lin, \lin, -2]).discretize(1024);

// render a score and return the left channel
render = { |name, extraMsgs, dur, synthArgs, fixtures|
	var out = work +/+ ("r_" ++ name ++ ".aiff");
	var osc = work +/+ ("r_" ++ name ++ ".osc");
	var defBytes = defPath.load.asBytes;
	var msgs = List.new;
	var done = false, waited = 0, data = nil;
	fixtures.do { |f, i| msgs.add([0.0, ['/b_allocRead', i, f[\path], 0, -1]]) };
	msgs.add([0.0, ['/b_alloc', 20, 64, 1]]);
	msgs.add([0.0, ['/b_setn', 20, 0, 16] ++ (0..15)]);
	msgs.add([0.0, ['/b_alloc', 21, 1024, 1]]);
	msgs.add([0.0, ['/b_setn', 21, 0, 1024] ++ winSignal.as(Array)]);
	msgs.add([0.0, ['/d_recv', defBytes]]);
	msgs.add([0.01, ['/s_new', \break, 1000, 0, 0] ++ synthArgs]);
	extraMsgs.do { |m| msgs.add(m) };
	msgs.add([dur, ['/c_set', 0, 0]]);
	Score(msgs.asArray).recordNRT(osc, out, nil, sr, "AIFF", "float",
		ServerOptions.new.numOutputBusChannels_(2).sampleRate_(sr),
		action: { done = true });
	while { done.not and: { waited < 90 } } { 0.25.wait; waited = waited + 0.25 };
	if(done.not) { ("  (render timed out: " ++ name ++ ")").postln; nil } {
		0.5.wait;
		block { |brk|
			var sf = SoundFile.openRead(out);
			if(sf.isNil) { brk.value };
			data = FloatArray.newClear(sf.numFrames * sf.numChannels);
			sf.readData(data);
			sf.close;
			data = data[0, sf.numChannels .. data.size - sf.numChannels];
		};
		data
	}
};

// local maxima above a threshold, at least minGap apart
onsets = { |sig, thresh = 0.02, minGap = 2000|
	var out = List.new, last = -1e9, i = 0, n = sig.size;
	while { i < n } {
		if((sig[i].abs > thresh) and: { (i - last) > minGap }) {
			var j = i, peak = 0, peakAt = i;
			while { (j < n) and: { (j - i) < minGap } } {
				if(sig[j].abs > peak) { peak = sig[j].abs; peakAt = j };
				j = j + 1;
			};
			out.add((at: peakAt, amp: peak));
			last = peakAt;
			i = peakAt + (minGap * 0.6).asInteger;
		} { i = i + 1 };
	};
	out.asArray
};

Routine {
	var base, sig, ons, sp, expect;

	"".postln;
	"=== BreakCheck: fixtures ===".postln;
	f175 = mkFixture.("probe175bpm.wav", 175, 4);
	f90 = mkFixture.("slow90bpm.wav", 90, 4);
	if(f175.isNil or: { f90.isNil }) {
		("BreakCheck: could not write fixtures into " ++ work).error;
	} {
		("  4 beats at 175 bpm = " ++ f175[\dur].round(0.0001) ++ "s").postln;
		("  4 beats at 90 bpm  = " ++ f90[\dur].round(0.0001) ++ "s").postln;

		// the standard voice: clean chops, fitted, punch window
		base = [\sbuf, 20, \slen, 16, \beats, 4, \steps, 16, \grind, 0.5,
			\over, 1, \vari, 1, \envbuf, 21, \atk, 0.001];

		"".postln;
		"=== grid lock ===".postln;
		sig = render.("grid120", [], 4.2, [\buf, 0, \tempo, 2, \amp, 1] ++ base, [f175]);
		if(sig.notNil) {
			ons = onsets.(sig);
			sp = ons.collect(_[\at]).differentiate.drop(1);
			expect = 0.125 * sr;
			check.("16 slices per loop, twice over 4.2s",
				(ons.size >= 28) and: { ons.size <= 34 }, ons.size.asString ++ " onsets");
			check.("onsets one 16th apart at 120 bpm",
				sp.every { |s| (s - expect).abs < (expect * 0.03) },
				"mean " ++ sp.mean.round(0.1) ++ ", expect " ++ expect);
			check.("slice order preserved (fixture amps ascend)",
				ons.keep(16).collect(_[\amp]).differentiate.drop(1).count { |d| d > 0 } >= 12,
				"ascending");
		};

		sig = render.("grid150", [], 3.4, [\buf, 0, \tempo, 2.5, \amp, 1] ++ base, [f175]);
		if(sig.notNil) {
			sp = onsets.(sig, 0.02, 1600).collect(_[\at]).differentiate.drop(1);
			expect = (60 / 150 / 4) * sr;
			check.("grid follows a tempo change to 150 bpm",
				sp.every { |s| (s - expect).abs < (expect * 0.03) },
				"mean " ++ sp.mean.round(0.1) ++ ", expect " ++ expect);
		};

		sig = render.("src90", [], 4.2, [\buf, 0, \tempo, 2, \amp, 1] ++ base, [f90]);
		if(sig.notNil) {
			sp = onsets.(sig).collect(_[\at]).differentiate.drop(1);
			expect = 0.125 * sr;
			check.("a 90 bpm source locks to the same 120 bpm grid",
				sp.every { |s| (s - expect).abs < (expect * 0.03) },
				"mean " ++ sp.mean.round(0.1) ++ ", expect " ++ expect);
		};

		"".postln;
		"=== sequence ===".postln;
		sig = render.("rests",
			[[0.005, ['/b_setn', 20, 0, 16,
				0, -1, 2, -1, 4, -1, 6, -1, 8, -1, 10, -1, 12, -1, 14, -1]]],
			4.2, [\buf, 0, \tempo, 2, \amp, 1] ++ base, [f175]);
		if(sig.notNil) {
			check.("rest slices are silent (half as many onsets)",
				onsets.(sig).size.inclusivelyBetween(13, 19),
				onsets.(sig).size.asString ++ " onsets, expect ~16");
		};

		"".postln;
		"=== gapless swap ===".postln;
		sig = render.("swap", [[2.0, ['/n_set', 1000, \buf, 1]]], 4.2,
			[\buf, 0, \tempo, 2, \amp, 1] ++ base, [f175, f90]);
		if(sig.notNil) {
			var before = sig.copyRange((1.0 * sr).asInteger, (1.9 * sr).asInteger);
			var after = sig.copyRange((2.1 * sr).asInteger, (3.0 * sr).asInteger);
			var atSwap = sig.copyRange((2.0 * sr).asInteger, (2.3 * sr).asInteger);
			check.("audio continues after the swap",
				after.abs.maxItem > (before.abs.maxItem * 0.3),
				"peak " ++ before.abs.maxItem.round(0.001) ++ " -> "
					++ after.abs.maxItem.round(0.001));
			check.("no silent gap at the swap point",
				atSwap.abs.maxItem > 0.02,
				"peak in the 300ms after: " ++ atSwap.abs.maxItem.round(0.001));
		};

		"".postln;
		"=== grind ===".postln;
		sig = render.("intact", [], 4.2,
			[\buf, 0, \tempo, 2, \amp, 1] ++ base ++ [\grind, 0], [f175]);
		if(sig.notNil) {
			ons = onsets.(sig);
			sp = ons.collect(_[\at]).differentiate.drop(1);
			expect = 0.125 * sr;
			check.("grind 0 plays the loop intact, on the session grid",
				(ons.size >= 28) and: { ons.size <= 34 } and: {
					sp.every { |s| (s - expect).abs < (expect * 0.05) } },
				ons.size.asString ++ " onsets, mean spacing " ++ sp.mean.round(0.1));
		};

		// vari 0 deliberately lets grains overrun their slice, so what must hold is
		// the LOOP period rather than per-click spacing
		sig = render.("preserve", [], 6.2,
			[\buf, 0, \tempo, 2, \amp, 1] ++ base ++ [\vari, 0, \grind, 0.75], [f175]);
		if(sig.notNil) {
			var bounds = List.new;
			ons = onsets.(sig, 0.02, 1200);
			ons.doAdjacentPairs { |a, b|
				if(b[\amp] < (a[\amp] * 0.5)) { bounds.add(b[\at]) };
			};
			sp = bounds.asArray.differentiate.drop(1);
			expect = 2.0 * sr;
			check.("vari 0 (pitch preserved) still repeats at the session period",
				(sp.size > 0) and: { sp.every { |s| (s - expect).abs < (expect * 0.02) } },
				"loop period " ++ sp ++ ", expect " ++ expect);
		};

		sig = render.("sweep",
			(1..20).collect { |i| [i * 0.2, ['/n_set', 1000, \grind, i / 20]] },
			4.4, [\buf, 0, \tempo, 2] ++ base ++ [\grind, 0], [f175]);
		if(sig.notNil) {
			check.("no clipping sweeping grind 0->1 at default amp",
				sig.abs.maxItem <= 1.0,
				"peak " ++ sig.abs.maxItem.round(0.001) ++ " ("
					++ sig.abs.maxItem.ampdb.round(0.1) ++ " dBFS)");
			check.("no NaN or runaway values",
				sig.every { |v| v.isNaN.not and: { v.abs < 100 } }, "clean");
			check.("still audible at the dust end",
				sig.copyRange((4.0 * sr).asInteger, (4.3 * sr).asInteger)
					.abs.maxItem > 0.005, "audible");
		};

		"".postln;
		"=== level vs overlap ===".postln;
		sig = [0.5, 1, 2, 4].collect { |ov|
			var s = render.("ov" ++ ov, [], 3.0,
				[\buf, 0, \tempo, 2] ++ base ++ [\over, ov], [f175]);
			s !? {
				s.copyRange((0.5 * sr).asInteger, (2.5 * sr).asInteger).squared.mean.sqrt
			}
		};
		if(sig.every(_.notNil)) {
			check.("level holds across over = [0.5, 1, 2, 4]",
				(sig.maxItem / sig.minItem).ampdb < 3,
				"RMS " ++ sig.collect { |v| v.ampdb.round(0.1) } ++ " dB");
		};

		"".postln;
		"=== transients survive the slice seam ===".postln;
		// The fixture's clicks sit 8% into each slice, but a real break's hits land ON
		// the slice boundary — inside the grain window's attack ramp, which is a
		// fraction of grain length and so ~500us at chop density. Grain pre-roll starts
		// each grain slightly early so the boundary transient lands past that ramp.
		// Compare peak per hit at the chop station against the intact loop.
		block {
			var intact, chops, ratio;
			intact = render.("tr_intact", [], 3.0,
				[\buf, 0, \tempo, 2] ++ base ++ [\grind, 0], [f175]);
			chops = render.("tr_chops", [], 3.0,
				[\buf, 0, \tempo, 2] ++ base ++ [\grind, 0.5], [f175]);
			if(intact.notNil and: { chops.notNil }) {
				ratio = chops.abs.maxItem / intact.abs.maxItem;
				check.("chop-station peak within 3 dB of the intact loop",
					ratio.ampdb.abs < 3,
					"chops " ++ chops.abs.maxItem.round(0.001) ++ " vs intact "
						++ intact.abs.maxItem.round(0.001) ++ " = "
						++ ratio.ampdb.round(0.1) ++ " dB");
			};
		};

		"".postln;
		"=== the chop station stays on-grid after a grind move ===".postln;
		// The grain grid is derived from the loop phase rather than free-running, so
		// coincidence with the slice grid survives any grind history. A free-running
		// phasor lost it permanently the first time grind moved.
		sig = render.("regrind",
			[[0.7, ['/n_set', 1000, \grind, 1.0]],
			 [1.4, ['/n_set', 1000, \grind, 0.31]],
			 [2.1, ['/n_set', 1000, \grind, 0.5]]],
			5.0, [\buf, 0, \tempo, 2, \amp, 1] ++ base, [f175]);
		if(sig.notNil) {
			// after the return to 0.5, onsets must still be one 16th apart
			var tail = sig.copyRange((2.6 * sr).asInteger, (4.9 * sr).asInteger);
			ons = onsets.(tail);
			sp = ons.collect(_[\at]).differentiate.drop(1);
			expect = 0.125 * sr;
			check.("back at grind 0.5, onsets are one 16th apart again",
				(sp.size > 0) and: {
					sp.every { |s| (s - expect).abs < (expect * 0.05) } },
				"mean " ++ (if(sp.size > 0) { sp.mean.round(0.1) } { "none" })
					++ ", expect " ++ expect);
		};

		"".postln;
		"=== roll does not stack grains ===".postln;
		// roll adds triggers at roll x the slice rate. If grain length still followed
		// only the grain grid, each roll would pile `roll` full-length grains on top
		// of each other — measured at up to +24 dB before this was fixed.
		sig = [1, 2, 4, 8].collect { |r|
			var s = render.("roll" ++ r, [], 3.0,
				[\buf, 0, \tempo, 2] ++ base ++ [\roll, r], [f175]);
			s !? { s.abs.maxItem }
		};
		if(sig.every(_.notNil)) {
			check.("peak stays bounded across roll = [1, 2, 4, 8]",
				(sig.maxItem / sig[0]) < 2.0,
				"peaks " ++ sig.collect { |v| v.round(0.001) }
					++ ", worst ratio " ++ (sig.maxItem / sig[0]).round(0.01) ++ "x");
			check.("and no roll setting clips",
				sig.maxItem <= 1.0, "max peak " ++ sig.maxItem.round(0.001));
		};

		"".postln;
		"=== \\brk1 window length (sustain is in BEATS) ===".postln;
		// An event's \sustain is in beats, not seconds: dur 0.25 at tempo 2 yields
		// 0.25. Treating it as seconds made every chop's window tempo-times too long.
		block {
			var brk1Path = setupDir +/+ "SynthDefs" +/+ "brk1.scd";
			var out = work +/+ "brk1win.aiff";
			var osc = work +/+ "brk1win.osc";
			var done = false, waited = 0, data = nil, tail;
			// a CONTINUOUS tone, not the click fixture: with sparse clicks the last
			// sample above threshold is the last click, not the end of the window
			var tonePath = work +/+ "tone.wav";
			var toneFrames = (2.0 * sr).asInteger;
			var tone = Signal.newClear(toneFrames);
			var tsf;
			toneFrames.do { |i| tone[i] = 0.5 * sin(2pi * 1000 * i / sr) };
			if(File.exists(tonePath)) { File.delete(tonePath) };
			tsf = SoundFile.new.headerFormat_("WAV").sampleFormat_("float")
				.numChannels_(1).sampleRate_(sr);
			tsf.openWrite(tonePath);
			tsf.writeData(tone.as(FloatArray));
			tsf.close;
			Score([
				[0.0, ['/b_allocRead', 0, tonePath, 0, -1]],
				[0.0, ['/d_recv', brk1Path.load.asBytes]],
				// 1 beat of sustain at tempo 2 must sound for 0.5 s, not 1 s
				[0.01, ['/s_new', \brk1, 1000, 0, 0,
					\buf, 0, \sustain, 1, \tempo, 2, \amp, 1, \rel, 0.01]],
				[2.0, ['/c_set', 0, 0]]
			]).recordNRT(osc, out, nil, sr, "AIFF", "float",
				ServerOptions.new.numOutputBusChannels_(2).sampleRate_(sr),
				action: { done = true });
			while { done.not and: { waited < 60 } } { 0.25.wait; waited = waited + 0.25 };
			0.5.wait;
			block { |brk|
				var sf = SoundFile.openRead(out);
				if(sf.isNil) { brk.value };
				data = FloatArray.newClear(sf.numFrames * sf.numChannels);
				sf.readData(data);
				sf.close;
				data = data[0, sf.numChannels .. data.size - sf.numChannels];
			};
			if(data.notNil) {
				// last sample above a small threshold = where the window closed
				tail = data.size - 1;
				while { (tail > 0) and: { data[tail].abs < 0.001 } } { tail = tail - 1 };
				check.("1 beat at tempo 2 gives a 0.5 s window, not 1 s",
					((tail / sr) - 0.5).abs < 0.05,
					"window ended at " ++ (tail / sr).round(0.001) ++ "s");
			} {
				check.("brk1 render produced output", false, "no data");
			};
		};

		"".postln;
		"=== lifecycle ===".postln;
		sig = render.("die", [[1.0, ['/n_set', 1000, \gate, 0]]], 3.0,
			[\buf, 0, \tempo, 2, \amp, 1, \rel, 0.2] ++ base, [f175]);
		if(sig.notNil) {
			check.("silent after gate 0 and release (the node frees itself)",
				sig.copyRange((1.6 * sr).asInteger, (2.9 * sr).asInteger)
					.abs.maxItem < 0.001, "silent");
		};

		"".postln;
		("=== BreakCheck: " ++ pass ++ " passed, " ++ fail ++ " failed ===").postln;
		if(fail == 0) { "The engine is behaving.".postln };
	};
}.play;
)
