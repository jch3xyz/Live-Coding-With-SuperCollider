// BreakTour — a scripted walk through the regions of the \break engine, for
// calibrating by ear. Same idea as GamutTour.scd: play it, listen for dead zones,
// then rename words and retune curves based on what you actually hear.
//
// Requires: Setup.scd evaluated (server, ProxySpace p, tempo clock), and at least
// one break in Setup/samples/breaks*/. With no library at all, run the DEMO block
// at the bottom first — it builds a usable break from SuperCollider's own sound.
//
// Usage:  q[\tour].value;            // the full walk, posts what it is doing
//         q[\tour].value(\amen);     // on a particular break
//         q[\stations].value;        // just the three grind stations, held longer
//         q[\hush].value;            // stop
//
// Everything here is ordinary vocabulary — nothing in this file is private API.

q = q ? ();

// ---------------------------------------------------------------------------
// the named regions, as (label -> a function of the voice)
// ---------------------------------------------------------------------------
q[\regions] = [
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
q[\tour] = { |key, beats = 8|
	var voice;
	if(\Break.asClass.isNil) { "BreakTour: the Synesthesia quark is not loaded".warn };
	if(Break.size == 0) {
		"BreakTour: no breaks loaded — see Setup/samples/breaks/README.md, or run q[\\demo]".warn;
	} {
		~tour.brk(key ?? { Break.keyAt(0) });
		~tour.play;
		voice = ~tour;
		("BreakTour: " ++ q[\regions].size ++ " regions, " ++ beats
			++ " beats each, on \"" ++ Break.keyOf(~tour) ++ "\"").postln;
		Tdef(\breakTour, {
			q[\regions].do { |pair, i|
				("  " ++ (i + 1) ++ "/" ++ q[\regions].size ++ "  " ++ pair.key).postln;
				pair.value.value(voice);
				beats.wait;
			};
			"BreakTour: done — report dead zones and bad names".postln;
		}).play(p.clock, quant: 4);
	};
};

// just the three advertised stations, held long enough to judge
q[\stations] = { |key, beats = 16|
	var voice;
	~tour.brk(key ?? { Break.keyAt(0) });
	~tour.play;
	voice = ~tour;
	Tdef(\breakStations, {
		[
			"grind 0.0 — one grain per loop: should sound like the loop, intact"
				-> 0.0,
			"grind 0.5 — one grain per slice: should sound like clean chops on the grid"
				-> 0.5,
			"grind 1.0 — 64 grains per beat: should sound like dust"
				-> 1.0
		].do { |pair|
			pair.key.postln;
			voice.grind(pair.value).over(1).vari(1).win(\punch).jit(0).roll(1).ord;
			beats.wait;
		};
		"BreakStations: done".postln;
	}).play(p.clock, quant: 4);
};

q[\hush] = {
	Tdef(\breakTour).stop;
	Tdef(\breakStations).stop;
	~tour.stop(2);
};

// ---------------------------------------------------------------------------
// DEMO: build a break with no library, from SuperCollider's own sound
// ---------------------------------------------------------------------------
q[\demo] = {
	Buffer.read(Server.default,
		Platform.resourceDir +/+ "sounds/a11wlk01.wav",
		action: { |b|
			// not really a drum loop, but it is 2 beats long at 120 bpm
			var key = Break.capture(\demo, b, 2);
			("BreakTour: registered \\" ++ key ++ " ("
				++ b.duration.round(0.01) ++ "s). Try q[\\tour].value(\\"
				++ key ++ ")").postln;
		});
};

"BreakTour loaded — q[\\tour].value / q[\\stations].value / q[\\demo].value / q[\\hush].value".postln;
