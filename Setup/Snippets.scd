
//Instrument Presets
DDWSnippets.put("ring1", "(~ring1 = Pbind(
	\\instrument, \\ring1,
	\\f, Pkey(\\freq),
	\\scale, Scale.major,
	\\root, 0,
	\\degree, Pseq([0], inf),
	\\octave, 3,
	\\dur, 1,
	\\a, 1,
	\\pan, 0,
	\\amp, 0.7
);)

~ring1.play");