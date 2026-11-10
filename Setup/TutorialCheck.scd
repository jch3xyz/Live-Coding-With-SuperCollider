// TutorialCheck — plays ../Tutorial.scd (or the tutorial SYN_TUTORIAL names) top to
// bottom on a real server, the way a person would (one statement at a time, at a
// human pace), and reports per lesson:
//   - any statement that threw an error
//   - every audible proxy and how loud it measured on the server (peak, dBFS);
//     anything over 0 dBFS is an OVERLOAD and counts as a failure
//   - any "duplicate node ID" failure from the server, which means a sound was
//     silenced by the JITLib fault Synesthesia.guard exists to prevent
//   - every Broadcast OSC address that arrived during the lesson, with a count
// so the tutorial's LISTEN / WATCH notes can be checked against what happens.
//
// Broadcast is pointed back at this sclang (its own langPort) instead of
// TouchDesigner, so the check can count what TouchDesigner would receive.
// Skipped: the Setup line (the check loads Setup itself, as a silent gate) and
// any lesson whose title says "not checked" (live sampling needs a microphone).
//
// Usage: evaluate the whole file, or headless:
//   sclang Setup/TutorialCheck.scd
//   SYN_TUTORIAL=Tutorial-Paint.scd sclang Setup/TutorialCheck.scd   // another tutorial
// Takes about four minutes. Silent: output is muted.

(
var setupDir = thisProcess.nowExecutingPath.dirname;
var tutorialPath = "SYN_TUTORIAL".getenv !? { |rel|
	if(rel.beginsWith("/")) { rel } { setupDir +/+ ".." +/+ rel }
} ?? { setupDir +/+ ".." +/+ "Tutorial.scd" };
var lessons, parse, measure, waitFor, seen, current, failures = 0, report;

waitFor = { |test, timeout = 10|
	var t = 0;
	while { test.value.not and: { t < timeout } } { 0.1.wait; t = t + 0.1 };
	test.value
};

// split the file into lessons of statements. A statement ends where brackets
// balance and the line ends with ';' — enough for this file, which keeps to
// one statement (or one bracketed block) per run.
parse = { |text|
	var out = List.new, lesson, inComment = false, buf = "", depth = 0;
	text.split($\n).do { |line|
		var code = line, inStr = false, i = 0, trimmed;
		if(inComment) {
			if(line.contains("LESSON")) {
				lesson = (num: line.findRegexp("LESSON ([0-9]+)")[1][1].asInteger,
					title: line.split($—).last.stripWhiteSpace, stmts: List.new);
				out.add(lesson);
			};
			if(line.contains("*/")) { inComment = false };
		} {
			if(line.stripWhiteSpace.beginsWith("/*")) {
				inComment = line.contains("*/").not;
				if(line.contains("LESSON")) {
					lesson = (num: line.findRegexp("LESSON ([0-9]+)")[1][1].asInteger,
						title: line.split($—).last.stripWhiteSpace, stmts: List.new);
					out.add(lesson);
				};
			} {
				// drop a trailing // comment that is not inside a string
				while { i < line.size } {
					if(line[i] == $") { inStr = inStr.not };
					if(inStr.not and: { line[i] == $/ } and: { line[i + 1] == $/ }) {
						code = line.copyRange(0, i - 1); i = line.size;
					};
					i = i + 1;
				};
				trimmed = code.stripWhiteSpace;
				if(trimmed.size > 0 and: { lesson.notNil }) {
					inStr = false;
					trimmed.do { |c|
						if(c == $") { inStr = inStr.not };
						if(inStr.not) {
							if("([{".includes(c)) { depth = depth + 1 };
							if(")]}".includes(c)) { depth = depth - 1 };
						};
					};
					buf = if(buf.isEmpty) { trimmed } { buf ++ "\n" ++ trimmed };
					if(depth == 0 and: { trimmed.last == $; }) {
						lesson[\stmts].add(buf); buf = "";
					};
				};
			};
		};
	};
	out
};

// the peak of every audible proxy over `dur` seconds, read on the server
measure = { |dur = 3|
	var keys = p.envir.keys.asArray.sort.select { |k|
		var px = p.envir[k];
		px.rate == \audio and: { px.monitor.notNil } and: { px.monitor.isPlaying }
	};
	var results = IdentityDictionary.new, resp, synths;
	resp = OSCFunc({ |msg| results[keys[msg[2]]] = msg[3] }, '/tutlvl', s.addr);
	synths = keys.collect { |k, i|
		var bus = p.envir[k].bus;
		{
			var sig = InFeedback.ar(bus.index, bus.numChannels);
			var pk = RunningMax.kr(Peak.kr(sig.asArray.collect(_.abs).reduce(\max)));
			var done = TDelay.kr(Impulse.kr(0), dur);
			SendReply.kr(done, '/tutlvl', pk, i);
			FreeSelf.kr(TDelay.kr(done, 0.05));
			Silent.ar
		}.play(RootNode(s), addAction: \addToTail);
	};
	(dur + 0.5).wait;
	waitFor.({ results.size == keys.size }, 2);
	resp.free;
	keys.collect { |k| k -> (results[k] ? 0) }
};

lessons = parse.(File.readAllString(tutorialPath));
seen = IdentityDictionary.new;

// a private server, so an open IDE session (its own server on 57110) is never
// rebooted or shared: two clients on one server hand out the same node IDs and
// replace each other's synths, which looks exactly like broken instruments
Server.default = s = Server(\tutorialCheck, NetAddr("127.0.0.1", 57145));

topEnvironment[\setupGate] = true;
(setupDir +/+ "Setup.scd").load;

thisProcess.addOSCRecvFunc({ |msg|
	var addr = msg[0].asString;
	if(addr == "/fail" and: { msg[2].asString.contains("duplicate node ID") }) {
		failures = failures + 1;
		"  FAIL  server: duplicate node ID — a proxy's start was cancelled (JITLib fault)".postln;
	};
	if(current.notNil and: { addr.beginsWith("/syn/") }) {
		seen[current] = seen[current] ?? { Bag.new };
		seen[current].add(addr);
	};
});

Routine {
	("=== TutorialCheck: " ++ PathName(tutorialPath).fileName ++ ", booting Setup.scd ===").postln;
	waitFor.({ p.notNil and: { p.envir[\delay].notNil } }, 60);
	(p.clock.timeToNextBeat(4) / p.clock.tempo + 0.5).wait;
	s.sync;
	s.volume.mute;

	lessons.do { |lesson|
		if(lesson[\title].contains("not checked")) {
			("\n--- LESSON " ++ lesson[\num] ++ " skipped (" ++ lesson[\title] ++ ") ---").postln;
		} {
			current = lesson[\num];
			("\n--- LESSON " ++ lesson[\num] ++ " — " ++ lesson[\title] ++ " ---").postln;
			lesson[\stmts].do { |stmt|
				var code = stmt;
				if(code.contains("Setup.scd").not) {
					code = code.replace("NetAddr(\"127.0.0.1\", 10000)",
						"NetAddr(\"127.0.0.1\", " ++ NetAddr.langPort ++ ")");
					// compile first: a syntax error returns nil rather than throwing
					code.compile !? { |fn|
						try { fn.value } { |err|
							failures = failures + 1;
							("  FAIL  " ++ stmt.replace("\n", " ") ++ "\n        " ++ err.errorString).postln;
						};
					} ?? {
						failures = failures + 1;
						("  FAIL  (does not compile) " ++ stmt.replace("\n", " ")).postln;
					};
					0.4.wait;
				};
			};
			// let quantised changes land and patterns cycle: two bars
			(2 * 4 / p.clock.tempo).wait;
			measure.(3).do { |pair|
				var db = pair.value.ampdb.round(0.1);
				var over = pair.value > 1;
				if(over) { failures = failures + 1 };
				("  sound  ~" ++ pair.key ++ "  " ++ if(pair.value > 0.0001) { db.asString ++ " dB" } { "SILENT" }
					++ if(over) { "  OVERLOAD" } { "" }).postln;
			};
			(seen[current] ? Bag.new).contents.asSortedArray.do { |pair|
				("  osc    " ++ pair[0] ++ "  x" ++ pair[1]).postln;
			};
			seen[current] = nil;
		};
	};

	"".postln;
	("=== TutorialCheck: " ++ failures ++ " failure(s) ===").postln;
	s.quit; 0.5.wait;   // the private server goes with us
	if(Platform.ideName != "scide") { failures.min(1).exit };
}.play(AppClock);
)
