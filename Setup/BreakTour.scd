// BreakTour — a scripted walk through the regions of the \break engine, for
// calibrating by ear. Same idea as GamutTour.scd: play it, listen for dead zones,
// then rename words and retune curves based on what you actually hear.
//
// Requires: Setup.scd evaluated (server, ProxySpace p, tempo clock), and at least
// one break in Setup/samples/breaks*/. With no library at all, run
// q[\breakDemo].value first — it builds a usable break from SuperCollider's own
// bundled sound, so the tour works before you have collected anything.
//
// Keys are namespaced `break*` because GamutTour.scd already owns q[\tour],
// q[\tourGated] and q[\colorWalk]; the tour voice is the proxy ~brk.
//
// Usage:  q[\breakTour].value;            // the full walk, posts what it is doing
//         q[\breakTour].value(\amen);     // on a particular break
//         q[\breakStations].value;        // just the three grind stations, held longer
//         q[\breakHush].value;            // stop
//
// Everything here is ordinary vocabulary — nothing in this file is private API.

q = q ? ();

// ---------------------------------------------------------------------------
// the named regions, as (label -> a function of the voice)
// ---------------------------------------------------------------------------
q[\breakRegions] = [
	"intact loop — grind 0, repitched to fit"
		-> { |v| v.grind(0).over(1).vari(1).win(\gate).jit(0).roll(1) },
	"beat-sized chops — grind 0.25"
		-> { |v| v.grind(0.25).over(1).win(\punch) },
	"clean 16th chops — grind 0.5, the default"
		-> { |v| v.grind(0.5).over(1).win(\punch) },
	"gated chops — same grid, grains shorter than their slot"
		-> { |v| v.over(0.6) },
	"smeared chops — grains overrunning their slot"
		-> { |v| v.over(2.5) },
	"subdivided — grind 0.75, chops becoming grains"
		-> { |v| v.over(1).grind(0.75) },
	"dust — grind 1 with scatter"
		-> { |v| v.grind(1).jit(0.6) },
	"wash — dust with heavy overlap (feed a reverb and it is a pad)"
		-> { |v| v.over(4).win(\hann) },
	"back to chops"
		-> { |v| v.over(1).grind(0.5).jit(0).win(\punch) },
	"pitch preserved — vari 0 at grain density"
		-> { |v| v.vari(0).grind(0.7) },
	"pitch preserved at chop density (listen for slice overrun)"
		-> { |v| v.grind(0.5) },
	"fitted again"
		-> { |v| v.vari(1) },
	"resequenced"
		-> { |v| v.seq("0.325476") },
	"reversed by slice"
		-> { |v| v.rev },
	"euclidean mask 5 of 16"
		-> { |v| v.mask(5, 16) },
	"half stochastic"
		-> { |v| v.ord.scr(0.5) },
	"fully stochastic"
		-> { |v| v.scr(1) },
	"ordered again"
		-> { |v| v.ord },
	"roll 2 — stutter"
		-> { |v| v.roll(2) },
	"roll 4"
		-> { |v| v.roll(4) },
	"roll off"
		-> { |v| v.roll(1) },
	"reverse grains"
		-> { |v| v.flip(0.4) },
	"forward again"
		-> { |v| v.flip(0) },
	"transposed up a fifth"
		-> { |v| v.speed(1.5) },
	"home"
		-> { |v| v.speed(1).grind(0.5).over(1).vari(1).win(\punch) }
];

// ---------------------------------------------------------------------------
// the walk
// ---------------------------------------------------------------------------
q[\breakTour] = { |key, beats = 8|
	var voice;
	if(\Break.asClass.isNil) { "BreakTour: the Synesthesia quark is not loaded".warn };
	if(Break.size == 0) {
		"BreakTour: no breaks loaded — see Setup/samples/breaks/README.md, or run q[\\breakDemo]".warn;
	} {
		~brk.brk(key ?? { Break.keyAt(0) });
		~brk.play;
		voice = ~brk;
		("BreakTour: " ++ q[\breakRegions].size ++ " regions, " ++ beats
			++ " beats each, on \"" ++ Break.keyOf(~brk) ++ "\"").postln;
		Tdef(\breakTour, {
			q[\breakRegions].do { |pair, i|
				("  " ++ (i + 1) ++ "/" ++ q[\breakRegions].size ++ "  " ++ pair.key).postln;
				pair.value.value(voice);
				beats.wait;
			};
			"BreakTour: done — report dead zones and bad names".postln;
		}).play(p.clock, quant: 4);
	};
};

// The three stations, each heard twice: first in source order — where they should
// sound nearly IDENTICAL, because pieces in their original order reassemble the
// original loop at any resolution — and then scrambled, where the piece size finally
// becomes audible. Hearing the pair is the point: it teaches what grind actually is.
q[\breakStations] = { |key, beats = 16|
	var voice;
	~brk.brk(key ?? { Break.keyAt(0) });
	~brk.play;
	voice = ~brk;
	Tdef(\breakStations, {
		[
			"grind 0.0 — one grain per loop"   -> 0.0,
			"grind 0.5 — one grain per slice"  -> 0.5,
			"grind 1.0 — 64 grains per beat"   -> 1.0
		].do { |pair|
			("  " ++ pair.key ++ ", IN ORDER — expect: the loop, near-untouched").postln;
			voice.grind(pair.value).over(1).vari(1).win(\punch).jit(0).roll(1).ord;
			beats.wait;
			("  " ++ pair.key ++ ", SCRAMBLED — expect: the piece size, audible").postln;
			voice.scr(1);
			beats.wait;
			voice.scr(0);
		};
		"BreakStations: done — did the scrambled pass change character with grind?".postln;
	}).play(p.clock, quant: 4);
};

q[\breakHush] = {
	Tdef(\breakTour).stop;
	Tdef(\breakStations).stop;
	~brk.stop(2);
};

// ---------------------------------------------------------------------------
// DEMO: build a break with no library, from SuperCollider's own sound
// ---------------------------------------------------------------------------
q[\breakDemo] = {
	Buffer.read(Server.default,
		Platform.resourceDir +/+ "sounds/a11wlk01.wav",
		action: { |b|
			// not really a drum loop, but it is 2 beats long at 120 bpm
			var key = Break.capture(\demo, b, 2);
			("BreakTour: registered \\" ++ key ++ " ("
				++ b.duration.round(0.01) ++ "s). Try q[\\breakTour].value(\\"
				++ key ++ ")").postln;
		});
};

"BreakTour loaded — q[\\breakTour].value / q[\\breakStations].value / q[\\breakDemo].value / q[\\breakHush].value".postln;
