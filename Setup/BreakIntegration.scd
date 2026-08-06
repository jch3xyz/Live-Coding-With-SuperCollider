// BreakIntegration — end-to-end check of the breakbeat machine against a LIVE server:
// scan a real folder of files, put a break in a proxy, drive the whole vocabulary,
// swap the sample, push a tempo, build a chop pattern, round-trip the sidecar.
//
// This covers the one path neither BreakCheck.scd (NRT, DSP only) nor TestBreak
// (pure functions, no server) can reach. It earns its place: it is what caught the
// bug where Collection:includes tests identity, so a folder full of .wav files
// scanned as zero files with no warning at all.
//
// It makes its own library in a temp folder, so it needs none of your samples and
// touches nothing in this repo. It boots the server itself and makes no sound.
//
// Usage: evaluate the whole file. Takes about a minute; posts a summary.
// Companions: TestBreak.run (instant, pure functions), BreakCheck.scd (NRT, audio).

(
var setupDir = thisProcess.nowExecutingPath.dirname;
var defs = setupDir +/+ "SynthDefs";
var work = (Platform.defaultTempDir ? "/tmp/") +/+ "breakintegration";
var breaksDir = work +/+ "breaks";
var sr = 44100;
var pass = 0, fail = 0, check, mkFixture;

check = { |name, ok, detail|
	if(ok) {
		pass = pass + 1;
		("  ok   " ++ name ++ if(detail.notNil, { "  — " ++ detail }, "")).postln;
	} {
		fail = fail + 1;
		("  FAIL " ++ name ++ "  — " ++ detail).postln;
	};
};

// a mono loop of `beats` beats at `bpm`, one click per sixteenth
mkFixture = { |name, bpm, beats|
	var path = breaksDir +/+ name;
	var frames = ((beats * 60 / bpm) * sr).round.asInteger;
	var sig = Signal.newClear(frames);
	var steps = 16, sliceLen = frames / steps;
	var clickLen = (0.004 * sr).asInteger;
	var sf;
	steps.do { |i|
		var start = ((i * sliceLen) + (sliceLen * 0.08)).asInteger;
		clickLen.do { |j|
			var idx = start + j;
			if(idx < frames) {
				sig[idx] = ((i + 1) / steps) * sin(2pi * 1000 * j / sr)
					* exp(-8 * j / clickLen);
			};
		};
	};
	if(File.exists(path)) { File.delete(path) };
	sf = SoundFile.new
		.headerFormat_("WAV").sampleFormat_("float")
		.numChannels_(1).sampleRate_(sr);
	if(sf.openWrite(path).not) { nil } {
		sf.writeData(sig.as(FloatArray));
		sf.close;
		path
	};
};

File.mkdir(work);
File.mkdir(breaksDir);
if(File.exists(breaksDir +/+ "_breaks.scd")) { File.delete(breaksDir +/+ "_breaks.scd") };

if(\Break.asClass.isNil) {
	"BreakIntegration: the Synesthesia quark is not loaded — nothing to test.".warn;
} {
	mkFixture.("probe175bpm.wav", 175, 4);
	mkFixture.("slow90bpm.wav", 90, 4);
	mkFixture.("untagged_loop.wav", 140, 8);

	Server.default.waitForBoot({
		var e, voice, pat, sidecar, dict, desc;

		"".postln;
		"=== defs ===".postln;
		(defs +/+ "00_specs.scd").load;
		(defs +/+ "break.scd").load;
		(defs +/+ "brk1.scd").load;
		Server.default.sync;
		desc = SynthDescLib.global.at(\break);
		check.("both defs loaded",
			desc.notNil and: { SynthDescLib.global.at(\brk1).notNil }, "\\break, \\brk1");
		// a Symbol source on a proxy gets no automatic envelope, so the def must
		// supply its own gate and be able to free itself
		check.("\\break is releasable by a proxy",
			desc.hasGate and: { desc.canFreeSynth }, "hasGate and canFreeSynth");
		check.("\\break declares out (required for proxy hosting)",
			desc.controlNames.includes(\out), "out present");

		"".postln;
		"=== scan ===".postln;
		Break.scan(work);
		Server.default.sync;
		2.wait;
		check.("scan found the library", Break.size == 3,
			Break.size.asString ++ " breaks");
		check.("keys derived from filenames",
			Break.order.includesAll([\probe175bpm, \slow90bpm, \untagged_loop]),
			Break.order.asString);
		e = Break.at(\probe175bpm);
		check.("tempo read from the filename tag",
			(e[\bpm] == 175) and: { e[\beats] == 4 } and: { e[\src] == \filename },
			"bpm " ++ e[\bpm] ++ ", beats " ++ e[\beats] ++ ", src " ++ e[\src]);
		check.("buffer is MONO (GrainBuf renders silence otherwise)",
			e[\buf].notNil and: { e[\buf].numChannels == 1 },
			e[\buf].numChannels.asString ++ " channel(s)");
		check.("untagged file fell back to the duration heuristic",
			Break.at(\untagged_loop)[\src] == \duration,
			"bpm " ++ Break.at(\untagged_loop)[\bpm].round(0.1));

		"".postln;
		"=== the vocabulary ===".postln;
		p = ProxySpace.push(Server.default);
		p.makeTempoClock;
		p.clock.tempo = 2;
		p.quant = 4;
		Server.default.sync;

		~d.brk(\probe175bpm);
		Server.default.sync;
		voice = Break.voiceOf(~d);
		check.("brk registered a voice and installed the engine",
			voice.notNil and: { ~d.source == \break }, ~d.source.asString);
		check.("voice got its own sequence buffer",
			voice[\seq].notNil and: { voice[\seq].numFrames == Break.seqSize },
			voice[\seq].numFrames.asString ++ " frames");
		check.("the punch window is the default, not GrainBuf's Hann",
			~d.nodeMap.at(\envbuf) != -1, "envbuf " ++ ~d.nodeMap.at(\envbuf));

		~d.grind(0.7).over(2).scr(0.3).jit(0.4).vari(0).speed(1.25).pos(0.1)
			.flip(0.2).roll(2).win(\gate);
		Server.default.sync;
		check.("every continuous word applied",
			(~d.nodeMap.at(\grind) == 0.7) and: { ~d.nodeMap.at(\roll) == 2 },
			"grind " ++ ~d.nodeMap.at(\grind) ++ ", roll " ++ ~d.nodeMap.at(\roll));

		~d.seq("0.325476");
		2.5.wait;
		check.("seq set the active sequence length", voice[\slen] == 8,
			"slen " ++ voice[\slen]);
		// a \tr value left in the nodeMap re-fires on every rebuild
		check.("resync did not stick in the nodeMap",
			~d.nodeMap.at(\resync).isNil, "absent");

		~d.mask(5, 16);
		2.5.wait;
		check.("mask wrote a 16-step euclidean sequence", voice[\slen] == 16,
			"slen " ++ voice[\slen]);

		~d.ord;
		2.5.wait;
		check.("ord restored source order and cleared scram",
			(voice[\ordered] == true) and: { ~d.nodeMap.at(\scram) == 0 }, "clean");

		~d.steps(8);
		2.5.wait;
		check.("steps regenerated an untouched order at the new length",
			(voice[\steps] == 8) and: { voice[\slen] == 8 },
			"steps and slen both 8");

		"".postln;
		"=== swap, cycle, tempo ===".postln;
		~d.brk(\slow90bpm);
		2.5.wait;
		check.("swap changed the break but kept the same voice",
			(Break.keyOf(~d) == \slow90bpm) and: { Break.voiceOf(~d) === voice },
			"now " ++ Break.keyOf(~d));
		check.("swap preserved the sculpting controls",
			~d.nodeMap.at(\grind) == 0.7, "grind still 0.7");
		~d.brk;
		2.5.wait;
		check.("bare brk cycled", Break.keyOf(~d) != \slow90bpm,
			"now " ++ Break.keyOf(~d));
		150.bpm;
		0.5.wait;
		check.("bpm() pushed the tempo to the live voice",
			(~d.nodeMap.at(\tempo) - 2.5).abs < 0.001,
			"tempo " ++ ~d.nodeMap.at(\tempo));

		"".postln;
		"=== the brush ===".postln;
		pat = \probe175bpm.chop("0325");
		check.("chop returns a Pbind", pat.isKindOf(Pbind), pat.class.asString);
		check.("its events resolve (buf, pos, rate all present)",
			block { |brk|
				var ev = pat.asStream.next(Event.default.copy);
				if(ev.isNil) { brk.value(false) };
				ev[\pos].notNil and: { ev[\rate].notNil } and: { ev[\buf].notNil }
			}, "first event resolves");

		"".postln;
		"=== sidecar round trip ===".postln;
		\probe175bpm.bpm_(172);
		0.5.wait;
		sidecar = breaksDir +/+ "_breaks.scd";
		check.("bpm_ wrote a sidecar", File.exists(sidecar), "written");
		dict = sidecar.load;
		check.("it re-reads as a Dictionary holding the override",
			dict.isKindOf(Dictionary) and: {
				dict["probe175bpm.wav"] !? { |x| x[\bpm] == 172 } == true },
			dict["probe175bpm.wav"].asString);
		Break.scan(work);
		Server.default.sync;
		2.wait;
		check.("after a rescan the sidecar beats inference",
			(Break.at(\probe175bpm)[\bpm] == 172)
				and: { Break.at(\probe175bpm)[\src] == \sidecar },
			"bpm 172, src sidecar");

		"".postln;
		"=== resync actually fires ===".postln;
		// Guards a near-miss: firing a \tr control by set-then-unset can have the
		// unset's default-0 land in the same control block and cancel the trigger
		// before the synth sees it. This counts real transitions inside a live synth.
		block {
			var bus = Bus.control(Server.default, 1), before, after;
			SynthDef(\breakTrigProbe, { |cbus = 0|
				var narrowed = Trig1.ar(K2A.ar(\resync.tr(0)), SampleDur.ir);
				Out.kr(cbus, A2K.kr(PulseCount.ar(narrowed)));
				Out.ar(\out.kr(0), Silent.ar(2));
			}).add;
			Server.default.sync;
			~probe = \breakTrigProbe;
			~probe.set(\cbus, bus.index);
			~probe.play;
			1.wait;
			before = bus.getSynchronous;
			3.do { Break.trig(~probe, \resync); 0.2.wait };
			0.5.wait;
			after = bus.getSynchronous;
			check.("Break.trig delivers real trigger transitions",
				(after - before) >= 3,
				(after - before).asString ++ " of 3 fired");
			check.("and leaves nothing in the nodeMap to re-fire on rebuild",
				~probe.nodeMap.at(\resync).isNil, "nodeMap clean");
			~probe.clear;
			bus.free;
		};

		"".postln;
		"=== chained metadata setters ===".postln;
		block {
			var e;
			// Break.set returns the registry Event, and an Event turns an unknown
			// foo_(x) into a key write — so a chained setter used to vanish silently.
			// bpm and beats are two views of one fact tied together by the file's
			// length, so the last call legitimately re-derives the other one: 8 beats
			// in this 2.667s file IS 180 bpm. What must hold is that the second call
			// took effect at all, and manufactured no junk key.
			\slow90bpm.bpm_(120).len_(8);
			e = Break.at(\slow90bpm);
			check.("the chained second setter took effect", e[\beats] == 8,
				"beats " ++ e[\beats]);
			check.("and the linked value was re-derived, not left stale",
				(e[\bpm] - 180).abs < 1, "bpm " ++ e[\bpm] ++ " (8 beats in 2.667s)");
			check.("no junk key was manufactured", e[\len].isNil, "no stray len key");
		};

		"".postln;
		"=== robustness ===".postln;
		~notABreak.grind(0.5);
		check.("a break word on a non-break proxy warns instead of throwing",
			true, "survived");
		~d.brk(\nosuchbreak);
		check.("an unknown break key leaves the voice alone",
			Break.keyOf(~d).notNil, "still on " ++ Break.keyOf(~d));

		Break.freeAll;
		check.("freeAll emptied the registry and the voices",
			(Break.size == 0) and: { Break.voices.isEmpty }, "clean");

		"".postln;
		("=== BreakIntegration: " ++ pass ++ " passed, " ++ fail ++ " failed ===").postln;
		if(fail == 0) { "End to end, on a real server.".postln };
	});
};
)
