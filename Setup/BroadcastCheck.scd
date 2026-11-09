// BroadcastCheck — the Broadcast manifest's acceptance test, against a LIVE server
// and a real receiver stub running in a SECOND sclang.
//
// It boots Setup.scd (gated: default device, no input, no recording file), starts
// BroadcastReceiver.scd as a second process listening on localhost, points Broadcast
// at it, and then evaluates the Guides/Synesthesia "A first session" block — read out
// of the help file itself, so the test tracks the guide — one line at a time, with
// NO Broadcast word typed after start. After every line it asks the stub's log what
// reached the wire, and the server's buses what the stems carry. Then it measures
// the event timing (how far from the audible onset each /syn/hit lands), exercises
// stem index stability (stop/play/swap/clear) and runs the manifest's negative test
// (an unreachable receiver: the music must be indistinguishable, one warning at
// most). It needs no samples of yours: where d has no "k", SC's bundled sound stands
// in, as in the guide.
//
// Usage: evaluate the whole file. Takes about two and a half minutes; posts a
// summary and the measured timing. Quiet (the server's volume is turned down), not
// silent — muting would zero the main-mix stem it has to measure.
// Headless:
//   /Applications/SuperCollider.app/Contents/MacOS/sclang Setup/BroadcastCheck.scd 2>&1 | tee /tmp/broadcastcheck.log
// and the negative test's "no errors" half is read off that log:
//   awk '/NEGATIVE BEGIN/,/NEGATIVE END/' /tmp/broadcastcheck.log | grep -c "^ERROR"   # expect 0
// Companions: TestBroadcast.run (pure functions), SetupCheck.scd, BreakIntegration.scd.

(
var setupDir = thisProcess.nowExecutingPath.dirname;
var quarkDir = Broadcast.filenameSymbol.asString.dirname.dirname;
var sclang = Platform.resourceDir.dirname +/+ "MacOS" +/+ "sclang";
var work = (Platform.defaultTempDir ? "/tmp/") +/+ "broadcastcheck";
var logPath = work +/+ "receiver.log";
var port = 57130;
var pass = 0, fail = 0, check, waitFor, readLog, lastOf, countOf, since, barWait;
var stemsOf, stemIndexOf, meterBus, meterSynth, levels, stemLevel, mainLevel;
var guideLines, expectations, origPlay, epoch0, stubPid;
var logCache = [], logOffset = 0;

check = { |name, ok, detail|
	if(ok) {
		pass = pass + 1;
		("  ok   " ++ name ++ if(detail.notNil, { "  — " ++ detail }, "")).postln;
	} {
		fail = fail + 1;
		("  FAIL " ++ name ++ "  — " ++ detail).postln;
	};
};

// poll a flag rather than hang on a Condition (see sc-headless-verification)
waitFor = { |test, timeout = 10|
	var t = 0;
	while { test.value.not and: { t < timeout } } { 0.1.wait; t = t + 0.1 };
	test.value
};

// the stub's log, parsed: [(time:, address:, args: [strings]), ...]. Read
// incrementally — only the bytes since the last read are parsed — because a
// thirty-hertz stream writes tens of thousands of lines in a run, and re-parsing
// them all blocked the interpreter long enough to make the server report late
// bundles that were this check's fault, not Broadcast's.
readLog = {
	var file, text, lines, partial, remaining;
	if(File.exists(logPath)) {
		file = File(logPath, "r");
		if(file.isOpen) {
			// exactly the unread bytes: File:readAllString sizes its buffer from the
			// whole file's length even after a seek, which is the stall this avoids
			remaining = (file.length - logOffset).max(0);
			text = String.newClear(remaining);
			file.seek(logOffset, 0);
			if(remaining > 0) { file.read(text) };
			file.close;
			lines = text.split($\n);
			// a line still being written has no newline yet: leave it for next time
			partial = if(text.endsWith("\n")) { "" } { lines.pop ? "" };
			logOffset = logOffset + text.size - partial.size;
			lines.do { |line|
				var parts;
				if(line.notEmpty and: { line.beginsWith("#").not }) {
					parts = line.split($ ).reject(_.isEmpty);
					logCache = logCache.add((time: parts[0].asFloat, address: parts[1], args: parts.copyToEnd(2)));
				};
			};
		};
	};
	logCache
};
since = { |mark| readLog.value.copyToEnd(mark) };
countOf = { |entries, address| entries.count { |e| e[\address] == address } };
lastOf = { |entries, address| entries.reverse.detect { |e| e[\address] == address } };
// the latest stem table as [key0, key1, ...] ("-" is a free slot)
stemsOf = { |entries| lastOf.(entries, "/syn/stems") !? { |e| e[\args] } };
// (detectIndex, not indexOf: indexOf compares identity, and two equal Strings are
// never the same object)
stemIndexOf = { |entries, key| stemsOf.(entries) !? { |t| t.detectIndex { |x| x == key.asString } } };

// one meter synth at the root tail reads all 20 output buses: the house pair (0-1)
// and the stems from 2 (stem 0 = the main mix on 2-3, stem i on 2+2i)
levels = { meterBus.getnSynchronous(20) };
stemLevel = { |index| levels.value[(2 + (2 * index))..(3 + (2 * index))].sum };
mainLevel = { stemLevel.(0) };

barWait = { |bars = 2| (p.clock.timeToNextBeat(4) / p.clock.tempo + (bars * 4 / p.clock.tempo) + 0.5).wait };

// ---- the guide's first session, read from the help file ----
guideLines = block { |brk|
	var text = File.readAllString(quarkDir +/+ "HelpSource/Guides/Synesthesia.schelp");
	var lines = text.split($\n);
	// (detectIndex takes no start offset, hence the hand-rolled search)
	var indexFrom = { |from, test|
		var found;
		(from..(lines.size - 1)).do { |i| if(found.isNil and: { test.(lines[i]) }) { found = i } };
		found
	};
	var start = indexFrom.(0, { |l| l.beginsWith("SECTION:: A first session") });
	var codeStart = start !? { indexFrom.(start, { |l| l.stripWhiteSpace == "code::" }) };
	var codeEnd = codeStart !? { indexFrom.(codeStart, { |l| l.stripWhiteSpace == "::" }) };
	if(codeEnd.isNil) { brk.value([]) };
	lines.copyRange(codeStart + 1, codeEnd - 1)
	.collect { |l| l.split($/).first.stripWhiteSpace }   // drop // comments
	.reject(_.isEmpty)
};

// what each sound-making line must leave on the wire (or in a stem), matched by a
// fragment of the line; lines without an entry are evaluated and only watched for
// warnings. Each returns [ok, detail].
expectations = [
	"~r = { 55 }" -> { |entries|
		var last = lastOf.(entries, "/syn/kr/r");
		[last.notNil and: { (last[\args][0].asFloat - 55).abs < 0.5 },
			"/syn/kr/r " ++ (last !? { last[\args][0] })]
	},
	"~a.fade(6).play" -> { |entries|
		[stemIndexOf.(entries, \a).notNil, "/syn/stems " ++ stemsOf.(entries)]
	},
	"~a.fx(\\lpf, 800)" -> { |entries|
		var i = stemIndexOf.(readLog.value, \a);
		[i.notNil and: { stemLevel.(i) > 1e-6 }, "stem " ++ i ++ " carries ~a: level " ++ (i !? { stemLevel.(i).round(1e-6) })]
	},
	"~a.fx(\\verb, 0.4)" -> { |entries|
		var i = stemIndexOf.(readLog.value, \a);
		[i.notNil and: { stemLevel.(i) > 1e-6 } and: { mainLevel.value > 1e-6 },
			"stem " ++ i ++ " and the main mix (stem 0) both carry signal"]
	},
	"~k.play" -> { |entries|
		var n = countOf.(entries, "/syn/hit/k");
		var one = lastOf.(entries, "/syn/hit/k");
		[n >= 3 and: { stemIndexOf.(entries, \k).notNil } and: { one[\args].size == 2 },
			n.asString ++ " × /syn/hit/k [amp index] e.g. " ++ (one !? { one[\args] }) ++ ", stem " ++ stemIndexOf.(entries, \k)]
	},
	"~a.duck(~k, 0.6)" -> { |entries|
		var i = stemIndexOf.(readLog.value, \a);
		[i.notNil and: { stemLevel.(i) > 1e-6 }, "stem " ++ i ++ " still carries ~a"]
	},
	"~m.play" -> { |entries|
		var notes = entries.select { |e| e[\address] == "/syn/note/ping" };
		var degrees = notes.collect { |e| e[\args][1].asFloat }.asSet.asArray.sort;
		// "one instant" to within 2 ms: the stub rounds arrival times to 0.1 ms, and three
		// messages sent back to back straddle a rounding step about one run in three
		var chord = notes.separate { |a, b| (b[\time] - a[\time]).abs > 0.002 }.detect { |g| g.size == 3 };
		[notes.size >= 4 and: { degrees.every { |d| [0, 2, 3, 4, 5].includes(d.asInteger) } }
			and: { chord.notNil } and: { notes.first[\args].size == 3 },
			notes.size.asString ++ " × /syn/note/ping [amp degree dur], degrees " ++ degrees
			++ ", a 3-note chord as 3 messages at one time"]
	},
	"pad(\\x).mapExp(200, 8000)" -> { |entries|
		var sig = lastOf.(entries, "/syn/kr/syn_sig1"), norm = lastOf.(entries, "/syn/krn/syn_sig1");
		var padx = lastOf.(entries, "/syn/kr/syn_padx");
		[sig.notNil and: { norm.notNil } and: { padx.notNil }
			and: { sig[\args][0].asFloat > 0 } and: { sig[\args][0].asFloat <= 8000 }
			and: { norm[\args][0].asFloat >= 0 } and: { norm[\args][0].asFloat <= 1 },
			"/syn/kr/syn_sig1 " ++ (sig !? { sig[\args][0] }) ++ " Hz, /syn/krn/syn_sig1 "
			++ (norm !? { norm[\args][0] }) ++ ", /syn/kr/syn_padx " ++ (padx !? { padx[\args][0] })]
	},
	"~r = { 65 }" -> { |entries|
		var last = lastOf.(entries, "/syn/kr/r");
		[last.notNil and: { last[\args][0].asFloat > 60 } and: { last[\args][0].asFloat <= 65.01 },
			"/syn/kr/r → " ++ (last !? { last[\args][0] }) ++ " (crossfading toward 65)"]
	}
	// hush(15) is checked in its own section below: stems fade, indices stay, events stop
];

if(File.exists(work).not) { File.mkdir(work) };
if(File.exists(logPath)) { File.delete(logPath) };

// the stub, as a second sclang in daemon mode. Its output goes to /dev/null in the
// shell: a child whose stdout sclang has closed dies the first time it posts. A stub
// left over from an interrupted run would still hold the port, so it goes first
// (systemCmd blocks; an asynchronous kill would race the launch and win).
"pkill -f BroadcastReceiver.scd".systemCmd;
stubPid = ("env SYN_BC_PORT=" ++ port ++ " SYN_BC_LOG=" ++ logPath.quote
	++ " SYN_BC_SECONDS=400 SYN_BC_QUIET=1 " ++ sclang.quote ++ " -D "
	++ (setupDir +/+ "BroadcastReceiver.scd").quote ++ " > /dev/null 2>&1").unixCmd({ }, true);

// room for the main mix + 8 stems from channel 2 (the speakers have 2; the rest are
// plain buses here, which is all the check needs). Setup does not touch this option.
Server.default.options.numOutputBusChannels = 20;
topEnvironment[\setupGate] = true;
// The gate boots on the system default devices unless told otherwise. A Bluetooth
// headset as default opens at 16 kHz and drops out, so prefer the built-in microphone
// and speakers when this Mac has them (quiet, see above); elsewhere, the defaults.
topEnvironment[\setupDevice] = [
	ServerOptions.inDevices.detect { |d| d.contains("Microphone") },
	ServerOptions.outDevices.detect { |d| d.contains("Speakers") }
];
origPlay = Event.parentEvents[\default][\play];
(setupDir +/+ "Setup.scd").load;

Routine {
	var ready, mark, entries, hushLevelK, hushLevelMain, hushStems, k0, expected, hits, offsets;
	var meterDef, negLevel, onLevel, offLevel, measure, pat;

	// an error anywhere below is a failure, not a hang: the summary and the exit still run
	try {

	"=== BroadcastCheck: booting Setup.scd, starting the receiver stub ===".postln;
	ready = waitFor.({ p.notNil and: { p.envir[\delay].notNil } }, 60);
	if(ready.not or: { p.clock.isNil }) {
		Error("BroadcastCheck: Setup did not finish booting — is another scsynth still running?").throw
	};
	barWait.(1);
	s.sync;
	check.("Setup reached its standing returns", ready, "booted");
	check.("the receiver stub is listening",
		waitFor.({ File.exists(logPath) and: { File.readAllString(logPath).contains("ready on port") } }, 30),
		"second sclang, port " ++ port);
	s.volume.volume = -36;      // quiet, not mute (see the header)

	// the guide's minimal environment, where Setup's palette lacks it
	SynthDef(\ping, { |out = 0, freq = 440, amp = 0.3, pan = 0, atk = 0.01, rel = 0.4|
		var sig = SinOsc.ar(freq) * EnvGen.ar(Env.perc(atk, rel), doneAction: 2);
		Out.ar(out, Pan2.ar(sig, pan, amp));
	}).add;
	if(d["k"].isNil or: { d["k"].isEmpty }) {
		d["k"] = [Buffer.read(s, Platform.resourceDir +/+ "sounds/a11wlk01.wav")];
	};
	meterDef = SynthDef(\syn_check_meter, { |cbus = 0|
		Out.kr(cbus, Amplitude.kr(In.ar(0, 20)).lag(0.3))
	}).add;
	s.sync;
	// a fixed index far above anything the allocator hands out: the server rebuilds
	// its allocators on every client login (boot, or a re-login after it judged the
	// server unresponsive), and an allocated bus then collides with the proxies'
	meterBus = Bus(\control, 8000, 20, s);
	meterSynth = Synth.tail(RootNode(s), \syn_check_meter, [\cbus, meterBus.index]);
	epoch0 = Date.getDate.rawSeconds - Main.elapsedTime;

	"".postln;
	"=== start ===".postln;
	Broadcast.start(NetAddr("127.0.0.1", port));
	check.("Broadcast started with all three streams",
		Broadcast.running and: { Broadcast.events } and: { Broadcast.kr } and: { Broadcast.stems }, "running");
	check.("no warning: 20 output channels leave room for main + 8 stems",
		Broadcast.warnings.isEmpty, Broadcast.warnings.values.asString);
	2.5.wait;
	entries = readLog.value;
	check.("/syn/alive heartbeat is arriving", countOf.(entries, "/syn/alive") >= 1,
		countOf.(entries, "/syn/alive").asString ++ " in 2.5 s");
	check.("/syn/stems was published at start, with main on stem 0",
		stemsOf.(entries).notNil and: { stemsOf.(entries)[0] == "main" }, stemsOf.(entries).asString);
	check.("the standing returns, being monitored, hold stems",
		stemIndexOf.(entries, \verb).notNil and: { stemIndexOf.(entries, \delay).notNil },
		"verb " ++ stemIndexOf.(entries, \verb) ++ ", delay " ++ stemIndexOf.(entries, \delay));

	"".postln;
	("=== the guide's first session, " ++ guideLines.size ++ " lines, nothing typed for Broadcast ===").postln;
	check.("found the \"A first session\" code block in the guide", guideLines.size >= 10, guideLines.size.asString ++ " lines");
	guideLines.do { |line|
		var exp = expectations.detect { |assoc| line.contains(assoc.key) };
		var result, before;
		("  > " ++ line).postln;
		mark = readLog.value.size;
		if(line.contains("hush")) {
			// what the stems carry right before the fade, to compare after it
			k0 = stemIndexOf.(readLog.value, \k);
			hushLevelK = k0 !? { stemLevel.(k0) };
			hushLevelMain = mainLevel.value;
			hushStems = stemsOf.(readLog.value);
		};
		line.interpret;
		if(line.beginsWith("bpm") or: { line.beginsWith("grid") }) { 0.2.wait } {
			// a new or rebound proxy crossfades in over p.fadeTime after its bar
			if(line.contains("~r = { 65 }") or: { line.contains("mapExp") }) {
				barWait.(2); (p.fadeTime + 0.5).wait
			} { barWait.(2) };
		};
		exp !? {
			result = exp.value.value(since.(mark));
			check.(line, result[0], result[1]);
		};
	};

	"".postln;
	"=== after hush(15): stems and events follow audibility ===".postln;
	4.wait;
	check.("the ~k stem is fading (gain lagged by the hush time)",
		hushLevelK.notNil and: { stemLevel.(k0) < (hushLevelK * 0.7) },
		"stem " ++ k0 ++ ": " ++ (hushLevelK !? { hushLevelK.round(1e-6) }) ++ " → " ++ (k0 !? { stemLevel.(k0).round(1e-6) }));
	check.("the stem table did not change: indices survive a stop",
		stemsOf.(readLog.value) == hushStems, stemsOf.(readLog.value).asString);
	mark = readLog.value.size;
	barWait.(1);
	check.("no /syn/hit/k after hush: a brush in a stopped proxy sends nothing",
		countOf.(since.(mark), "/syn/hit/k") == 0, countOf.(since.(mark), "/syn/hit/k").asString ++ " hits");
	check.("the continuous stream keeps flowing (kr proxies are not silenced by hush)",
		countOf.(since.(mark), "/syn/kr/r") > 10, countOf.(since.(mark), "/syn/kr/r").asString ++ " × /syn/kr/r in a bar");
	check.("no warnings so far", Broadcast.warnings.isEmpty, Broadcast.warnings.values.asString);

	"".postln;
	"=== the continuous stream's rate, tempo and beat ===".postln;
	mark = readLog.value.size;
	2.0.wait;
	entries = since.(mark);
	check.("/syn/kr/r arrives at about 30 Hz",
		countOf.(entries, "/syn/kr/r").inclusivelyBetween(45, 75),
		countOf.(entries, "/syn/kr/r").asString ++ " in 2 s");
	check.("/syn/tempo carries the clock in BPM",
		lastOf.(entries, "/syn/tempo").notNil and: { (lastOf.(entries, "/syn/tempo")[\args][0].asFloat - 120).abs < 0.01 },
		lastOf.(entries, "/syn/tempo") !? { |e| e[\args][0] });
	check.("/syn/beat is a 0..1 phase",
		entries.select { |e| e[\address] == "/syn/beat" }.every { |e| e[\args][0].asFloat.inclusivelyBetween(0, 1) }
			and: { countOf.(entries, "/syn/beat") > 10 },
		countOf.(entries, "/syn/beat").asString ++ " values");

	"".postln;
	"=== event timing against the stub (the ±10 ms claim) ===".postln;
	// A user callback records when each hit is due to sound — the logical time plus
	// the event's latency, in Unix seconds, the clock the stub logs in. This also
	// proves the performer's own \callback keeps running beside Broadcast's hook.
	expected = List.new;
	~t = Pbindf(\k.hits("xxxx", 0.5), \callback, { |ev|
		expected.add(epoch0 + thisThread.seconds + (ev[\latency] ? s.latency))
	});
	mark = readLog.value.size;
	~t.play;
	barWait.(2);
	~t.clear;        // clear, not stop: stop leaves the pattern running unheard, and
	0.5.wait;        // its callbacks would then outnumber the (rightly unsent) hits
	hits = since.(mark).select { |e| e[\address] == "/syn/hit/k" };
	check.("the user's \\callback ran for every hit", expected.size >= 8, expected.size.asString ++ " callbacks");
	check.("…and Broadcast still sent every hit", hits.size == expected.size,
		hits.size.asString ++ " on the wire vs " ++ expected.size ++ " expected");
	offsets = hits.collect { |h, i| expected[i] !? { (h[\time] - expected[i]) * 1000 } }.reject(_.isNil);
	if(offsets.notEmpty) {
		("  arrival minus audible onset, ms: mean " ++ offsets.mean.round(0.01)
			++ ", min " ++ offsets.minItem.round(0.01) ++ ", max " ++ offsets.maxItem.round(0.01)
			++ ", |max| " ++ offsets.abs.maxItem.round(0.01) ++ " over " ++ offsets.size ++ " hits").postln;
	};
	check.("every hit landed within ±10 ms of its audible onset",
		offsets.notEmpty and: { offsets.abs.maxItem <= 10 },
		offsets.notEmpty.if({ "|max| " ++ offsets.abs.maxItem.round(0.01) ++ " ms" }, "no hits"));

	"".postln;
	"=== stem index stability: stop, play, swap, clear ===".postln;
	~k.play;
	barWait.(1);
	k0 = stemIndexOf.(readLog.value, \k);
	check.("~k.play after hush keeps its stem",
		k0.notNil and: { k0 == hushStems.detectIndex { |x| x == "k" } }, "stem " ++ k0);
	~k.stop; 1.wait; ~k.play; barWait.(1);
	check.("…through a stop/play cycle", stemIndexOf.(readLog.value, \k) == k0, "stem " ++ stemIndexOf.(readLog.value, \k));
	~k = \k.hits(3, 8); barWait.(1);
	check.("…through a source swap", stemIndexOf.(readLog.value, \k) == k0, "stem " ++ stemIndexOf.(readLog.value, \k));
	mark = readLog.value.size;
	~k.clear; 1.wait;
	check.("~k.clear releases the stem and announces /syn/gone/k",
		stemIndexOf.(readLog.value, \k).isNil and: { countOf.(since.(mark), "/syn/gone/k") == 1 },
		"stems " ++ stemsOf.(readLog.value) ++ ", gone × " ++ countOf.(since.(mark), "/syn/gone/k"));
	mark = readLog.value.size;
	~r = nil; barWait.(1);
	check.("a kr proxy whose source goes nil is announced once on /syn/gone/r and dropped",
		countOf.(since.(mark), "/syn/gone/r") == 1 and: { Broadcast.krKeys.includes(\r).not },
		"gone × " ++ countOf.(since.(mark), "/syn/gone/r") ++ ", tapped: " ++ Broadcast.krKeys);
	Broadcast.status;

	"".postln;
	"=== the negative test: an unreachable receiver ===".postln;
	"=== NEGATIVE BEGIN ===".postln;
	// the same bar of kick measured three ways on the HOUSE output (buses 0-1 —
	// the stems are Broadcast's own, and silent with it off); the levels must agree.
	// A short monitor fade and a settled Amplitude follower, averaged over a bar.
	measure = {
		var samples = List.new;
		~n = \k.hits("x.x.");
		~n.fade(0.02).play;
		barWait.(1);
		8.do { samples.add(levels.value[0..1].sum); (0.5 / p.clock.tempo).wait };
		("    house level " ++ samples.mean.round(1e-5) ++ "  buses 0-19: "
			++ levels.value.collect(_.round(1e-5))).postln;
		~n.stop(0.02);
		barWait.(1);
		samples.mean
	};
	// a warm-up pass first: a freshly created ~n measures about a quarter low on its
	// first bar whatever Broadcast is doing, and a second pass under the same state
	// agrees with the other two to within one percent. The comparison is between
	// Broadcast states, so the voice's own first bar must not be one of the three.
	measure.value;
	onLevel = measure.value;
	Broadcast.stop;
	Broadcast.start(NetAddr("192.0.2.1", 9000));    // TEST-NET: never routed, never answers
	check.("start against an unreachable address still returns running", Broadcast.running, "running");
	negLevel = measure.value;
	hush(0.1);
	check.("at most one warning with the receiver unreachable", Broadcast.warnings.size <= 1,
		Broadcast.warnings.size.asString ++ " warning(s)" ++ if(Broadcast.warnings.notEmpty) { ": " ++ Broadcast.warnings.values } { "" });
	Broadcast.stop;
	offLevel = measure.value;
	"=== NEGATIVE END ===".postln;
	check.("the main mix measures the same with Broadcast on, unreachable and off",
		(onLevel - negLevel).abs < (onLevel * 0.15) and: { (offLevel - negLevel).abs < (offLevel * 0.15) },
		"on " ++ onLevel.round(1e-6) ++ ", unreachable " ++ negLevel.round(1e-6) ++ ", off " ++ offLevel.round(1e-6));

	"".postln;
	"=== stop leaves no trace ===".postln;
	check.("the default event's play function is restored",
		Event.parentEvents[\default][\play] === origPlay, "identical function");
	check.("every syn_bc_ proxy is cleared",
		p.envir.keys.select { |k| Broadcast.isHidden(k) }.every { |k| p.envir[k].source.isNil },
		p.envir.keys.select { |k| Broadcast.isHidden(k) }.size.asString ++ " hidden keys, all neutral");
	check.("a brush Pbind is still a plain Pbind", \k.hits("x").isKindOf(Pbind), "Pbind");

	} { |error|
		fail = fail + 1;
		"  FAIL the check itself threw:".postln;
		error.reportError;
	};

	Broadcast.stop;
	meterSynth !? { meterSynth.free };
	"pkill -f BroadcastReceiver.scd".unixCmd({ }, false);
	"".postln;
	("=== BroadcastCheck: " ++ pass ++ " passed, " ++ fail ++ " failed ===").postln;
	if(fail == 0) { "Everything musical reached the wire, with nothing typed for it.".postln };
	("receiver log: " ++ logPath).postln;
	if(Platform.ideName != "scide") { 0.5.wait; fail.min(1).exit };
}.play(AppClock);
)
