// SetupCheck — boots Setup.scd for real and asks the SERVER (not sclang) whether
// the safety floor and the standing returns actually exist.
//
// It earns its place: sclang keeps its own picture of the node tree, and that
// picture can be wrong. A stray s.freeAll right before the returns were built
// (Server:initTree re-creates the default group asynchronously, on AppClock)
// meant ~verb, ~verbIn, ~delay and ~delayIn never existed on the server while
// ~verb.isPlaying still answered true — every route(\verb) fed nothing, silently.
// The same line could free the StageLimiter, depending on a 10 ms race.
// Only a /g_queryTree round trip sees that.
//
// Boots on the system default output with no input and creates no recording
// file (topEnvironment[\setupGate]). Silent: the returns carry no signal.
//
// Usage: evaluate the whole file. Takes about half a minute; posts a summary.
// Companions: BreakIntegration.scd (live server, breaks), BreakCheck.scd (NRT).

(
var setupDir = thisProcess.nowExecutingPath.dirname;
var pass = 0, fail = 0, check, queryTree, waitFor;

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

// the server's own node tree: nodeID -> (parent:, synth:, def:, children:)
queryTree = {
	var reply, nodes = IdentityDictionary.new, i = 2, walk;
	OSCFunc({ |msg| reply = msg }, '/g_queryTree.reply', s.addr).oneShot;
	s.sendMsg("/g_queryTree", 0, 0);
	if(waitFor.({ reply.notNil }, 5)) {
		walk = { |parent|
			var id = reply[i], n = reply[i + 1];
			i = i + 2;
			if(n == -1) {
				nodes[id] = (parent: parent, synth: true, def: reply[i].asSymbol, children: []);
				i = i + 1;
			} {
				nodes[id] = (parent: parent, synth: false, children: List.new);
				n.do { nodes[id][\children].add(reply[i]); walk.(id) };
			};
		};
		walk.(nil);
	};
	nodes
};

topEnvironment[\setupGate] = true;
(setupDir +/+ "Setup.scd").load;

Routine {
	var tree, root, limiterID, ready;

	"=== SetupCheck: booting Setup.scd ===".postln;
	ready = waitFor.({ p.notNil and: { p.envir[\delay].notNil } }, 60);
	// p.quant = 4 means every proxy's synth starts on the NEXT BAR, not when .play
	// runs. A fixed 1-second wait raced that: it passed when boot happened to finish
	// late in a bar and failed (returns "not running") when it finished early.
	(p.clock.timeToNextBeat(p.quant.asArray[0] ? 4) / p.clock.tempo + 0.5).wait;
	s.sync;
	s.volume.mute;

	check.("Setup reached its standing returns", ready, "booted");
	tree = queryTree.value;
	check.("the server answered /g_queryTree", tree.notEmpty, tree.size.asString ++ " nodes");

	root = tree[0];
	check.("the default group exists", tree[1].notNil and: { tree[1][\synth].not }, "group 1");

	limiterID = tree.keys.detect { |id| tree[id][\def] == \stageLimiter };
	check.("StageLimiter is running", limiterID.notNil, "node " ++ limiterID);
	{
		var order = root !? { root[\children] } ? [];
		var li = order.indexOf(limiterID), gi = order.indexOf(1);
		check.("it sits at the root, after the default group (it sees everything)",
			li.notNil and: { gi.notNil } and: { li > gi },
			"root order " ++ order.asArray);
	}.value;

	[\verbIn, \verb, \delayIn, \delay].do { |key|
		var proxy = p.envir[key];
		var gid = proxy !? { proxy.group } !? { proxy.group.nodeID };
		var node = gid !? { tree[gid] };
		var synths = node !? { node[\children].count { |c| tree[c] !? { tree[c][\synth] } ? false } } ? 0;
		check.("~% exists on the server, not just in sclang".format(key),
			node.notNil, "group " ++ gid);
		check.("~% has a synth running in it".format(key), synths > 0, synths.asString ++ " synth(s)");
	};

	// ---- the sample library (skipped on a machine that does not have it) ----
	// Setup files its one-shot packs into d and only INDEXES the loops, loading each
	// on first use. These ask whether that split held, and whether a lazy load really
	// arrives on the server as a mono buffer full of audio.
	topEnvironment[\sampleLibrary] !? { |library|
		var libKeys, oneShotDirs, key, entry, buf, t0, loadTime, frames, got;

		check.("the library's one-shots are in d",
			[\k, \s, \cp, \perc].every { |k| d[k.asString].size > 0 },
			[\k, \s, \cp, \perc].collect { |k| k ++ "[" ++ d[k.asString].size ++ "]" }.join(" "));
		check.("...as stereo buffers, which \\bplay (the hits default) needs",
			d["k"].every { |b| b.numChannels == 2 }, "d[\"k\"]");

		libKeys = Break.order.select { |k| Break.at(k)[\path].asString.beginsWith(library) };
		check.("the library's loops are indexed", libKeys.size > 0, libKeys.size.asString ++ " loops");
		check.("...and none of them is loaded yet",
			libKeys.every { |k| Break.at(k)[\buf].isNil }, "loaded on first use");

		// whole path segments: the International Breaks pack's own folder name also
		// ends in "Essential Kicks", so a bare suffix would match every loop in it
		oneShotDirs = ["/Kicks/", "/Snares/", "/Claps/", "/Percussion/",
			"/The Drum Broker - Essential Kicks/", "/CHOPS/", "/Chops/"];
		check.("no one-shot folder leaked into the breaks library",
			libKeys.every { |k| oneShotDirs.every { |dir| Break.at(k)[\folder].contains(dir).not } },
			"excluded by name");

		// a first use: brk asks bufOf for the samples
		key = libKeys.detect { |k| Break.at(k)[\chans] == 2 } ? libKeys.first;
		entry = Break.at(key);
		t0 = Main.elapsedTime;
		p[\syn_libcheck].brk(key);
		loadTime = Main.elapsedTime - t0;
		s.sync;
		buf = entry[\buf];
		waitFor.({ buf.notNil and: { buf.numFrames.notNil } }, 5);
		frames = (entry[\dur] * s.sampleRate).round;
		check.("brk loads a library break on first use, as a mono buffer",
			buf.notNil and: { buf.numChannels == 1 },
			key ++ " (" ++ entry[\chans] ++ "ch file), sclang busy "
				++ (loadTime * 1000).round(1) ++ " ms");
		check.("...holding the whole file",
			buf.notNil and: { buf.numFrames.notNil } and: { (buf.numFrames - frames).abs <= 1 },
			buf !? { buf.numFrames.asString ++ " of " ++ frames ++ " frames" });
		buf !? {
			buf.getn((buf.numFrames / 4).asInteger, 512, { |vals| got = vals });
			waitFor.({ got.notNil }, 5);
			check.("...and it is audio, not silence",
				got.notNil and: { got.abs.maxItem > 0.0001 },
				got !? { "peak " ++ got.abs.maxItem.round(0.0001) });
		};
		// the engine itself starts on the next bar (quant), like every proxy
		(p.clock.timeToNextBeat(p.quant.asArray[0] ? 4) / p.clock.tempo + 0.5).wait;
		tree = queryTree.value;
		check.("the \\break engine is running it, on the server",
			tree.values.any { |n| n[\def] == \break }, "synth found by /g_queryTree");
		p[\syn_libcheck].clear;
		Break.unregister(p[\syn_libcheck]);
	};

	"".postln;
	("=== SetupCheck: " ++ pass ++ " passed, " ++ fail ++ " failed ===").postln;
	if(fail == 0) { "The server agrees with sclang.".postln };
	// exit when run headless; stay open when evaluated in the IDE
	if(Platform.ideName != "scide") { fail.min(1).exit };
}.play(AppClock);
)
