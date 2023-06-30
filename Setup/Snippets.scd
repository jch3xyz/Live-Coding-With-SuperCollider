
//Instrument Presets
DDWSnippets.put("ring1", "(~ring1 = Pbind(
	\\instrument, \\ring1,
	\\f, Pkey(\\freq),
	\\scale, n.scale,
	\\root, 0,
	\\degree, Pseq([0], inf),
	\\octave, 3,
	\\dur, 1,
	\\a, 1,
	\\pan, 0,
	\\amp, 0.7
);)

~ring1.play;");

DDWSnippets.put("kick", "(~kick = Pbind(\\instrument, \\AnalogKick,
	\\freq, 50,
	\\amp, 2.5
	\\dur, ##1##,
);)

~kick.play;")