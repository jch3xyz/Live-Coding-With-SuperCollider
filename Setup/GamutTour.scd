//GAMUT TOUR — hear each voice's whole color space. Run Setup first, evaluate one
//block at a time. Cmd-. stops a running tour. Coordinates post as they play.
//Axes: hue (wraps — 0 and 1 are the same place), sat (grey -> vivid -> neon),
//val (black -> full light). (q is a plain utility namespace — ~vars are proxies.)

(
q = q ? ();
//percussive tour: fire-and-forget synths, walks hue at a small sat/val grid
q[\tour] = { |inst, hold = 0.35, freq = 220, extra = #[]|
	Routine {
		[0.3, 0.8].do { |st|
			[0.35, 0.7].do { |v|
				("== " ++ inst ++ ": sat " ++ st ++ ", val " ++ v ++ ", hue 0 -> 1").postln;
				[0, 0.2, 0.4, 0.6, 0.8].do { |h|
					Synth(inst, [\freq, freq, \hue, h, \sat, st, \val, v, \amp, 0.4] ++ extra);
					hold.wait;
				};
				0.5.wait;
			};
		};
		("== " ++ inst ++ " tour done").postln;
	}.play;
};
//gated tour: hold then release each note
q[\tourGated] = { |inst, hold = 1.2, freq = 165, extra = #[]|
	Routine {
		[0.3, 0.8].do { |st|
			[0.35, 0.7].do { |v|
				("== " ++ inst ++ ": sat " ++ st ++ ", val " ++ v ++ ", hue 0 -> 1").postln;
				[0, 0.2, 0.4, 0.6, 0.8].do { |h|
					var x = Synth(inst, [\freq, freq, \hue, h, \sat, st, \val, v,
						\amp, 0.35, \atk, 0.05, \rel, 0.3] ++ extra);
					hold.wait;
					x.release;
					0.3.wait;
				};
				0.5.wait;
			};
		};
		("== " ++ inst ++ " tour done").postln;
	}.play;
};
//one long gated note whose coordinates glide — hear a PATH through the space
q[\colorWalk] = { |inst = \brush, secs = 24, freq = 130, from, to|
	Routine {
		var x = Synth(inst, [\freq, freq, \amp, 0.4, \atk, 1.5, \rel, 3,
			\hue, from[0], \sat, from[1], \val, from[2]]);
		("== " ++ inst ++ " walk " ++ from ++ " -> " ++ to).postln;
		40.do { |i|
			var t = (i + 1) / 40;
			x.set(\hue, from[0] + ((to[0] - from[0]) * t),
				\sat, from[1] + ((to[1] - from[1]) * t),
				\val, from[2] + ((to[2] - from[2]) * t));
			(secs / 40).wait;
		};
		1.5.wait;
		x.release;
		"== walk done".postln;
	}.play;
};
"Gamut tour loaded: q[\\tour], q[\\tourGated], q[\\colorWalk]".postln;
)

//---- BRUSH: the HSV instrument (rebuilt July 2026) ----
//full hue circle at natural sat/val — five stations, wrapping home:
q[\tourGated].(\brush, 1.6, 130);
//sat walk: vivid -> grey (hue becomes irrelevant as it fades):
q[\colorWalk].(\brush, 20, 130, [0.1, 1.0, 0.55], [0.1, 0.0, 0.55]);
//val walk: full light -> black (everything converges to the dark floor):
q[\colorWalk].(\brush, 20, 130, [0.1, 0.7, 1.0], [0.1, 0.7, 0.0]);
//corners: white (bright airy no-hue) / neon (vivid hot) / charcoal:
q[\colorWalk].(\brush, 16, 130, [0.4, 0.0, 1.0], [0.4, 1.0, 0.8]);
q[\colorWalk].(\brush, 16, 130, [0.7, 0.3, 0.15], [0.7, 0.9, 0.6]);
//hue circle at LOW sat — should barely change (the grey degeneracy):
q[\tourGated].(\brush, 1.0, 130, [\sat, 0.05]);

//---- percussive voices (axis semantics provisional until each is reworked) ----
q[\tour].(\mark, 0.4, 220);
q[\tour].(\kick, 0.5, 50);
q[\tour].(\snare, 0.45, 180);
q[\tour].(\hat, 0.25, 320);
q[\tour].(\tom, 0.45, 120);
q[\tour].(\metal, 1.2, 200);

//---- other gated voices (provisional) ----
q[\tourGated].(\spray, 1.4, 440, [\dens, 22, \size, 0.08]);
q[\tourGated].(\wash, 2.5, 110);
//sprayb needs a MONO buffer: rec(8) something first, then:
//q[\tourGated].(\sprayb, 2, 220, [\buf, d["live"][0], \dens, 16]);
